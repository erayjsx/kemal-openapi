require "json"

module Kemal::OpenAPI
  # Raised while validating when the schema itself cannot be used, for example
  # because a `$ref` points at a schema that was never registered.
  class SchemaError < Exception
  end

  # A single validation failure.
  #
  # For the request body (`location` is `"body"`), `pointer` is a JSON Pointer
  # (RFC 6901) to the offending value. For parameters, `location` is
  # `"query"`, `"path"`, `"header"` or `"cookie"` and `pointer` is the
  # parameter name.
  record ValidationError, pointer : String, message : String, location : String = "body" do
    def to_s(io : IO) : Nil
      if location != "body"
        io << location << " parameter '" << pointer << "': " << message
      elsif pointer.empty?
        io << message
      else
        io << pointer << ": " << message
      end
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field("in", location)
        json.field("pointer", pointer)
        json.field("message", message)
      end
    end
  end

  # Validates incoming requests against the documented operation: its
  # parameters (query, path, header and cookie) and its request body.
  #
  # Only JSON request bodies (`application/json` and `*+json`) are validated
  # against their schema. Other media types (`multipart/form-data`,
  # `application/x-www-form-urlencoded`, ...) are passed through untouched so
  # Kemal can parse them as usual.
  class Validator
    Log = ::Log.for("kemal.openapi")

    @@pattern_cache = Hash(String, Regex).new

    # Validates the request in *env* against the operation registered for
    # *method* and *path*. Writes an error response and returns `false` when
    # the request is invalid.
    def self.validate(
      env : HTTP::Server::Context,
      method : String,
      path : String,
      registry : Registry = Kemal::OpenAPI.registry,
    ) : Bool
      new(registry).validate(env, method, path)
    end

    # Validates *json* against *schema* and returns every failure found.
    # Raises `SchemaError` if the schema cannot be resolved.
    def self.errors_for(json : JSON::Any, schema : Schema, registry : Registry = Kemal::OpenAPI.registry) : Array(ValidationError)
      new(registry).errors_for(json, schema)
    end

    # Validates a route's return value against the documented response schema
    # for the current status code and logs a warning for every mismatch.
    # Used when `Kemal::OpenAPI.validate_responses` is enabled.
    def self.check_response(
      env : HTTP::Server::Context,
      method : String,
      path : String,
      body,
      registry : Registry = Kemal::OpenAPI.registry,
    ) : Array(ValidationError)
      new(registry).check_response(env, method, path, body)
    end

    def self.json_media_type?(content_type : String?) : Bool
      return false unless content_type
      media_type = content_type.split(';', 2).first.strip.downcase
      media_type == "application/json" || media_type.ends_with?("+json")
    end

    def initialize(@registry : Registry = Kemal::OpenAPI.registry)
    end

    def validate(env : HTTP::Server::Context, method : String, path : String) : Bool
      Kemal::OpenAPI.discover_operations if @registry.same?(Kemal::OpenAPI.registry)

      operation = @registry.operation(method, path)
      return true unless operation

      errors = parameter_errors(env, operation)
      return error(env, 422, errors.first.to_s, errors) unless errors.empty?

      if body_spec = operation.request_body
        return validate_body(env, body_spec)
      end

      true
    end

    def errors_for(json : JSON::Any, schema : Schema) : Array(ValidationError)
      errors = [] of ValidationError
      validate_schema(json, schema, "", errors)
      errors
    end

    def check_response(env : HTTP::Server::Context, method : String, path : String, body) : Array(ValidationError)
      errors = [] of ValidationError
      return errors unless body.is_a?(String)
      return errors unless operation = @registry.operation(method, path)

      status = env.response.status_code
      responses = operation.responses
      response = responses[status.to_s]? || responses["#{status // 100}XX"]? || responses["default"]?
      return errors unless response && (schema = response.schema)
      return errors unless Validator.json_media_type?(response.content_type || "application/json")

      json = begin
        JSON.parse(body)
      rescue JSON::ParseException
        errors << ValidationError.new("", "Response body is not valid JSON")
        log_response_errors(method, path, status, errors)
        return errors
      end

      errors = errors_for(json, schema)
      log_response_errors(method, path, status, errors)
      errors
    rescue ex : SchemaError
      Log.warn { "#{method.upcase} #{path}: #{ex.message}" }
      [] of ValidationError
    end

    private def log_response_errors(method : String, path : String, status : Int32, errors : Array(ValidationError)) : Nil
      errors.each do |e|
        Log.warn { "Response for #{method.upcase} #{path} (#{status}) does not match its schema: #{e}" }
      end
    end

    # Validates query, path, header and cookie parameters. Values arrive as
    # strings and are coerced to the parameter schema's type first.
    private def parameter_errors(env : HTTP::Server::Context, operation : Operation) : Array(ValidationError)
      errors = [] of ValidationError
      params = operation.parameters
      return errors unless params

      params.each do |param|
        values = raw_parameter_values(env, param)

        if values.empty?
          if param.required
            errors << ValidationError.new(param.name, "Missing required parameter", param.location)
          end
          next
        end

        next unless schema = param.schema
        value = coerce_parameter(values, resolve(schema))
        if value.nil?
          errors << ValidationError.new(param.name, "Expected #{type_description(resolve(schema))}, got #{values.first.inspect}", param.location)
          next
        end

        errors_for(value, schema).each do |e|
          errors << ValidationError.new(param.name, e.pointer.empty? ? e.message : "#{e.pointer}: #{e.message}", param.location)
        end
      end

      errors
    rescue ex : SchemaError
      [ValidationError.new("", ex.message || "Invalid schema")]
    end

    private def raw_parameter_values(env : HTTP::Server::Context, param : Parameter) : Array(String)
      case param.location
      when "query"
        env.request.query_params.fetch_all(param.name)
      when "path"
        env.route_lookup.params[param.name]?.try { |v| [URI.decode(v)] } || [] of String
      when "header"
        env.request.headers.get?(param.name) || [] of String
      when "cookie"
        env.request.cookies[param.name]?.try { |c| [c.value] } || [] of String
      else
        [] of String
      end
    end

    # Converts raw parameter strings into JSON according to *schema*.
    # Returns `nil` when a value cannot be converted to the expected type.
    private def coerce_parameter(values : Array(String), schema : Schema) : JSON::Any?
      types = schema.type_list || ["string"]

      if types.includes?("array")
        items = values.size == 1 ? values.first.split(',') : values
        item_schema = schema.items.try { |i| resolve(i) } || Schema.new(type: "string")
        coerced = [] of JSON::Any
        items.each do |item|
          value = coerce_scalar(item, item_schema.type_list || ["string"])
          return unless value
          coerced << value
        end
        return JSON::Any.new(coerced)
      end

      coerce_scalar(values.first, types)
    end

    private def coerce_scalar(value : String, types : Array(String)) : JSON::Any?
      types.each do |type|
        case type
        when "integer"
          if int = value.to_i64?
            return JSON::Any.new(int)
          end
        when "number"
          if float = value.to_f64?
            return JSON::Any.new(float)
          end
        when "boolean"
          return JSON::Any.new(true) if value == "true"
          return JSON::Any.new(false) if value == "false"
        when "null"
          return JSON::Any.new(nil) if value.empty? || value == "null"
        when "string"
          return JSON::Any.new(value)
        when "object"
          parsed = JSON.parse(value) rescue nil
          return parsed if parsed && parsed.raw.is_a?(Hash)
        end
      end
      nil
    end

    private def type_description(schema : Schema) : String
      schema.type_list.try(&.join(" or ")) || "a valid value"
    end

    private def validate_body(env : HTTP::Server::Context, body_spec : RequestBody) : Bool
      return true unless Validator.json_media_type?(body_spec.content_type)

      request_type = env.request.headers["Content-Type"]?
      if request_type && !Validator.json_media_type?(request_type)
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
    private def read_body(env : HTTP::Server::Context) : String?
      io = env.request.body
      return "" unless io

      limit = Kemal.config.max_request_body_size
      if (length = env.request.content_length) && length > limit
        error(env, 413, "Request body too large")
        return
      end

      buffer = IO::Memory.new
      copied = IO.copy(io, buffer, limit + 1)
      if copied > limit
        error(env, 413, "Request body too large")
        return
      end
      buffer.to_s
    end

    private def error(
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

    private def resolve(schema : Schema) : Schema
      seen = 0
      while ref = schema.ref
        name = ref.lchop("#/components/schemas/")
        schema = @registry.schemas[name]? || raise SchemaError.new("Schema reference not found: #{ref}")
        seen += 1
        raise SchemaError.new("Circular schema reference: #{ref}") if seen > 32
      end
      schema
    end

    private def validate_schema(json : JSON::Any, schema : Schema, pointer : String, errors : Array(ValidationError)) : Nil
      return if json.raw.nil? && schema.nullable
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

    private def errors_for_sub(json : JSON::Any, schema : Schema, pointer : String) : Array(ValidationError)
      errors = [] of ValidationError
      validate_schema(json, schema, pointer, errors)
      errors
    end

    private def type_matches?(json : JSON::Any, type : String) : Bool
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

    private def json_type(json : JSON::Any) : String
      case json.raw
      when Nil     then "null"
      when Bool    then "boolean"
      when Int64   then "integer"
      when Float64 then "number"
      when String  then "string"
      when Array   then "array"
      else              "object"
      end
    end

    private def validate_string(value : String, schema : Schema, pointer : String, errors : Array(ValidationError)) : Nil
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

    private def validate_number(value : Float64, schema : Schema, pointer : String, errors : Array(ValidationError)) : Nil
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

    private def validate_array(json : JSON::Any, schema : Schema, pointer : String, errors : Array(ValidationError)) : Nil
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

    private def validate_object(json : JSON::Any, schema : Schema, pointer : String, errors : Array(ValidationError)) : Nil
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

    private def compile_pattern(pattern : String) : Regex
      @@pattern_cache[pattern] ||= begin
        Regex.new(pattern)
      rescue ex : ArgumentError
        raise SchemaError.new("Invalid pattern #{pattern.inspect}: #{ex.message}")
      end
    end

    private def escape_pointer(key : String) : String
      key.gsub('~', "~0").gsub('/', "~1")
    end

    private def format_number(value : Float64) : String
      value == value.round ? value.to_i64.to_s : value.to_s
    end
  end
end
