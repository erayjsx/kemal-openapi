require "json"

module Kemal::OpenAPI
  # Raised while validating when the schema itself cannot be used, for example
  # because a `$ref` points at a schema that was never registered.
  class SchemaError < Exception
  end

  # A single validation failure, located with a JSON Pointer
  # (RFC 6901) into the request body.
  record ValidationError, pointer : String, message : String do
    def to_s(io : IO) : Nil
      if pointer.empty?
        io << message
      else
        io << pointer << ": " << message
      end
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field("pointer", pointer)
        json.field("message", message)
      end
    end
  end

  # Validates incoming request bodies against the documented `RequestBody`
  # schema of the matching operation.
  #
  # Only JSON request bodies (`application/json` and `*+json`) are validated
  # against their schema. Other media types (`multipart/form-data`,
  # `application/x-www-form-urlencoded`, ...) are passed through untouched so
  # Kemal can parse them as usual.
  class Validator
    @@pattern_cache = Hash(String, Regex).new

    def self.validate(env : HTTP::Server::Context, method : String, path : String) : Bool
      Kemal::OpenAPI.discover_operations

      operation = OPERATIONS_MAP["#{method.upcase} #{path}"]?
      return true unless operation

      if body_spec = operation.request_body
        return validate_body(env, body_spec)
      end

      true
    end

    # Validates *json* against *schema* and returns every failure found.
    # Raises `SchemaError` if the schema cannot be resolved.
    def self.errors_for(json : JSON::Any, schema : Schema) : Array(ValidationError)
      errors = [] of ValidationError
      validate_schema(json, schema, "", errors)
      errors
    end

    def self.json_media_type?(content_type : String?) : Bool
      return false unless content_type
      media_type = content_type.split(';', 2).first.strip.downcase
      media_type == "application/json" || media_type.ends_with?("+json")
    end

    private def self.validate_body(env : HTTP::Server::Context, body_spec : RequestBody) : Bool
      return true unless json_media_type?(body_spec.content_type)

      request_type = env.request.headers["Content-Type"]?
      if request_type && !json_media_type?(request_type)
        return error(env, 415, "Unsupported Media Type: expected #{body_spec.content_type}")
      end

      body = read_body(env)
      return false if body.nil? # 413 already written

      if body.empty?
        return body_spec.required ? error(env, 400, "Request body is required") : true
      end

      # Hand the body back to the route handler.
      env.request.body = IO::Memory.new(body)

      json = begin
        JSON.parse(body)
      rescue JSON::ParseException
        return error(env, 400, "Invalid JSON body")
      end

      return true unless schema = body_spec.schema

      errors = begin
        errors_for(json, schema)
      rescue ex : SchemaError
        return error(env, 422, ex.message || "Invalid schema")
      end

      return true if errors.empty?
      error(env, 422, errors.first.to_s, errors)
    end

    # Reads the request body, honouring `Kemal.config.max_request_body_size`.
    # Returns `nil` (after writing a 413 response) when the limit is exceeded.
    private def self.read_body(env : HTTP::Server::Context) : String?
      io = env.request.body
      return "" unless io

      limit = Kemal.config.max_request_body_size
      if (length = env.request.content_length) && length > limit
        error(env, 413, "Request body too large")
        return nil
      end

      buffer = IO::Memory.new
      copied = IO.copy(io, buffer, limit + 1)
      if copied > limit
        error(env, 413, "Request body too large")
        return nil
      end
      buffer.to_s
    end

    private def self.error(
      env : HTTP::Server::Context,
      status : Int32,
      message : String,
      details : Array(ValidationError)? = nil,
    ) : Bool
      env.response.status_code = status
      env.response.content_type = "application/json"
      env.response.print(
        JSON.build do |json|
          json.object do
            json.field("error", "validation_error")
            json.field("message", message)
            json.field("errors", details) if details
          end
        end
      )
      false
    end

    private def self.resolve(schema : Schema) : Schema
      seen = 0
      while ref = schema.ref
        name = ref.lchop("#/components/schemas/")
        schema = SCHEMAS[name]? || raise SchemaError.new("Schema reference not found: #{ref}")
        seen += 1
        raise SchemaError.new("Circular schema reference: #{ref}") if seen > 32
      end
      schema
    end

    private def self.validate_schema(json : JSON::Any, schema : Schema, pointer : String, errors : Array(ValidationError)) : Nil
      schema = resolve(schema)

      if all = schema.all_of
        all.each { |sub| validate_schema(json, sub, pointer, errors) }
      end

      if any = schema.any_of
        unless any.any? { |sub| errors_for_sub(json, sub, pointer).empty? }
          errors << ValidationError.new(pointer, "Value does not match any of the allowed schemas (anyOf)")
        end
      end

      if one = schema.one_of
        matches = one.count { |sub| errors_for_sub(json, sub, pointer).empty? }
        unless matches == 1
          detail = matches == 0 ? "none" : "#{matches}"
          errors << ValidationError.new(pointer, "Value must match exactly one schema (oneOf), matched #{detail}")
        end
      end

      if types = schema.type_list
        types = types + ["null"] if schema.nullable
        if json.raw.nil? && types.includes?("null")
          return
        end

        matched = types.find { |type| type_matches?(json, type) }
        unless matched
          errors << ValidationError.new(pointer, "Expected #{types.join(" or ")}, got #{json_type(json)}")
          return
        end
      elsif json.raw.nil? && schema.nullable
        return
      end

      if values = schema.enum_values
        unless (str = json.as_s?) && values.includes?(str)
          errors << ValidationError.new(pointer, "Value must be one of: #{values.join(", ")}")
        end
      end

      case raw = json.raw
      when String
        validate_string(raw, schema, pointer, errors)
      when Int64, Float64
        validate_number(raw.to_f64, schema, pointer, errors)
      when Array
        validate_array(json, schema, pointer, errors)
      when Hash
        validate_object(json, schema, pointer, errors)
      end
    end

    private def self.errors_for_sub(json : JSON::Any, schema : Schema, pointer : String) : Array(ValidationError)
      errors = [] of ValidationError
      validate_schema(json, schema, pointer, errors)
      errors
    end

    private def self.type_matches?(json : JSON::Any, type : String) : Bool
      case type
      when "object"  then json.raw.is_a?(Hash)
      when "array"   then json.raw.is_a?(Array)
      when "string"  then json.raw.is_a?(String)
      when "integer" then json.raw.is_a?(Int64) || ((f = json.raw).is_a?(Float64) && f.finite? && f == f.round)
      when "number"  then json.raw.is_a?(Int64) || json.raw.is_a?(Float64)
      when "boolean" then json.raw.is_a?(Bool)
      when "null"    then json.raw.nil?
      else                false
      end
    end

    private def self.json_type(json : JSON::Any) : String
      case raw = json.raw
      when Nil     then "null"
      when Bool    then "boolean"
      when Int64   then "integer"
      when Float64 then "number"
      when String  then "string"
      when Array   then "array"
      else              "object"
      end
    end

    private def self.validate_string(value : String, schema : Schema, pointer : String, errors : Array(ValidationError)) : Nil
      length = value.size
      if (min = schema.min_length) && length < min
        errors << ValidationError.new(pointer, "Must be at least #{min} characters long")
      end
      if (max = schema.max_length) && length > max
        errors << ValidationError.new(pointer, "Must be at most #{max} characters long")
      end
      if pattern = schema.pattern
        unless compile_pattern(pattern).matches?(value)
          errors << ValidationError.new(pointer, "Must match pattern #{pattern}")
        end
      end
    end

    private def self.validate_number(value : Float64, schema : Schema, pointer : String, errors : Array(ValidationError)) : Nil
      if (min = schema.minimum) && value < min
        errors << ValidationError.new(pointer, "Must be greater than or equal to #{format_number(min)}")
      end
      if (max = schema.maximum) && value > max
        errors << ValidationError.new(pointer, "Must be less than or equal to #{format_number(max)}")
      end
      if (min = schema.exclusive_minimum) && value <= min
        errors << ValidationError.new(pointer, "Must be greater than #{format_number(min)}")
      end
      if (max = schema.exclusive_maximum) && value >= max
        errors << ValidationError.new(pointer, "Must be less than #{format_number(max)}")
      end
      if (step = schema.multiple_of) && step > 0
        quotient = value / step
        unless (quotient - quotient.round).abs < 1e-9
          errors << ValidationError.new(pointer, "Must be a multiple of #{format_number(step)}")
        end
      end
    end

    private def self.validate_array(json : JSON::Any, schema : Schema, pointer : String, errors : Array(ValidationError)) : Nil
      items = json.as_a
      if (min = schema.min_items) && items.size < min
        errors << ValidationError.new(pointer, "Must contain at least #{min} items")
      end
      if (max = schema.max_items) && items.size > max
        errors << ValidationError.new(pointer, "Must contain at most #{max} items")
      end
      if schema.unique_items && items.uniq.size != items.size
        errors << ValidationError.new(pointer, "Items must be unique")
      end
      if item_schema = schema.items
        items.each_with_index do |item, index|
          validate_schema(item, item_schema, "#{pointer}/#{index}", errors)
        end
      end
    end

    private def self.validate_object(json : JSON::Any, schema : Schema, pointer : String, errors : Array(ValidationError)) : Nil
      object = json.as_h
      props = schema.properties

      schema.required.try &.each do |field|
        next if object.has_key?(field)
        # readOnly properties are only sent by the server, never by clients.
        next if props && (prop = props[field]?) && resolve(prop).read_only
        errors << ValidationError.new(pointer, "Missing required field: #{field}")
      end

      object.each do |key, value|
        child = "#{pointer}/#{escape_pointer(key)}"
        if props && (prop_schema = props[key]?)
          validate_schema(value, prop_schema, child, errors)
        else
          case extra = schema.additional_properties
          when false
            errors << ValidationError.new(child, "Unknown field: #{key}")
          when Schema
            validate_schema(value, extra, child, errors)
          end
        end
      end
    end

    private def self.compile_pattern(pattern : String) : Regex
      @@pattern_cache[pattern] ||= begin
        Regex.new(pattern)
      rescue ex : ArgumentError
        raise SchemaError.new("Invalid pattern #{pattern.inspect}: #{ex.message}")
      end
    end

    private def self.escape_pointer(key : String) : String
      key.gsub('~', "~0").gsub('/', "~1")
    end

    private def self.format_number(value : Float64) : String
      value == value.round ? value.to_i64.to_s : value.to_s
    end
  end
end
