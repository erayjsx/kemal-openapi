
module Kemal::OpenAPI
  class Validator
    def self.validate(env : HTTP::Server::Context, method : String, path : String) : Bool
      key = "#{method.upcase} #{path}"
      operation = OPERATIONS_MAP[key]?
      return true unless operation

      if body_spec = operation.request_body
        return validate_body(env, body_spec)
      end
      
      true
    end

    private def self.validate_body(env : HTTP::Server::Context, body_spec : RequestBody) : Bool
      return true unless body_spec.required || env.request.body

      # Read body
      body = env.request.body.try(&.gets_to_end)
      if body.nil? || body.empty?
        if body_spec.required
          return error(env, 400, "Request body is required")
        else
          return true
        end
      end

      # Reset body for the handler
      env.request.body = IO::Memory.new(body)

      # Parse JSON
      begin
        json = JSON.parse(body)
      rescue JSON::ParseException
        return error(env, 400, "Invalid JSON body")
      end

      if schema = body_spec.schema
        begin
          validate_schema(json, schema)
        rescue ex : Exception
          return error(env, 422, ex.message || "Validation failed")
        end
      end
      
      true
    end

    private def self.error(env : HTTP::Server::Context, status : Int32, message : String) : Bool
      env.response.status_code = status
      env.response.content_type = "application/json"
      env.response.print({error: "validation_error", message: message}.to_json)
      false
    end

    private def self.validate_schema(json : JSON::Any, schema : Schema)
      # Resolve ref if needed
      if ref = schema.ref
        # ref is like "#/components/schemas/User"
        name = ref.split("/").last
        resolved = SCHEMAS[name]?
        if resolved
          validate_schema(json, resolved)
          return
        else
          # Schema not found, skip validation
          return 
        end
      end

      # Get types
      types = schema.type.is_a?(Array) ? schema.type.as(Array(String)) : [schema.type.as(String)]

      # If types includes "null" and value is null, it's valid
      if types.includes?("null") && json.raw.nil?
        return
      end

      # Check if any type matches
      matched_type = types.find { |t| check_type(json, t) }

      unless matched_type
        raise "Expected #{types.join(" or ")}, got #{json.raw.class}"
      end

      # Validate constraints for the matched type
      case matched_type
      when "object"
        validate_object(json, schema)
      when "array"
        if items = schema.items
          json.as_a.each do |item|
            validate_schema(item, items)
          end
        end
      end
    end

    private def self.check_type(json : JSON::Any, type : String) : Bool
      case type
      when "object"  then !json.as_h?.nil?
      when "array"   then !json.as_a?.nil?
      when "string"  then !json.as_s?.nil?
      when "integer" then !json.as_i?.nil? || !json.as_i64?.nil?
      when "number"  then !json.as_f?.nil? || !json.as_i?.nil? || !json.as_i64?.nil?
      when "boolean" then !json.as_bool?.nil?
      when "null"    then json.raw.nil?
      else false
      end
    end

    private def self.validate_object(json : JSON::Any, schema : Schema)
      props = schema.properties || Hash(String, Schema).new
      
      # Check required
      if required = schema.required
        required.each do |field|
          unless json[field]?
            raise "Missing required field: #{field}"
          end
        end
      end

      # Check properties
      json.as_h.each do |key, value|
        if prop_schema = props[key]?
          validate_schema(value, prop_schema)
        end
      end
    end
  end
end
