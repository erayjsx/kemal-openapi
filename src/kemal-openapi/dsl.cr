require "json"

module Kemal::OpenAPI
  # ============================================================
  # Top-level DSL helpers — designed to be used in application code.
  # ============================================================

  # Convenience method to build a Schema from a Crystal class/struct
  # that includes JSON::Serializable.
  #
  # Usage:
  #   schema = Kemal::OpenAPI.schema_for(User)
  #
  macro schema_for(klass)
    %schema = Kemal::OpenAPI::Schema.new(type: "object")
    %props = Hash(String, Kemal::OpenAPI::Schema).new
    %required = [] of String

    {% for ivar in klass.resolve.instance_vars %}
      {% ann = ivar.annotation(JSON::Field) %}
      {% key = ann && ann[:key] ? ann[:key] : ivar.name.stringify %}
      {% ignore = ann && ann[:ignore] ? true : false %}

      {% unless ignore %}
        {% type = ivar.type.union? ? ivar.type.union_types.reject { |t| t == Nil }.first : ivar.type %}

        {% if type == String %}
          %props[{{key}}] = Kemal::OpenAPI::Schema.new(type: "string")
        {% elsif type == Int32 || type == Int64 %}
          %props[{{key}}] = Kemal::OpenAPI::Schema.new(type: "integer", format: {{type == Int64 ? "int64" : "int32"}})
        {% elsif type == Float32 || type == Float64 %}
          %props[{{key}}] = Kemal::OpenAPI::Schema.new(type: "number", format: {{type == Float64 ? "double" : "float"}})
        {% elsif type == Bool %}
          %props[{{key}}] = Kemal::OpenAPI::Schema.new(type: "boolean")
        {% elsif type == Array %}
          %props[{{key}}] = Kemal::OpenAPI::Schema.new(type: "array", items: Kemal::OpenAPI::Schema.new(type: "string"))
        {% else %}
          %props[{{key}}] = Kemal::OpenAPI::Schema.new(type: "object")
        {% end %}

        {% is_nilable = ivar.type.union? && ivar.type.union_types.includes?(Nil) %}
        {% unless is_nilable %}
          %required << {{key}}
        {% end %}

        {% if is_nilable %}
          %props[{{key}}].nullable = true
        {% end %}
      {% end %}
    {% end %}

    %schema.properties = %props
    %schema.required = %required unless %required.empty?
    %schema
  end

  # Quick helper to create a Schema reference.
  def self.ref(name : String) : Schema
    Schema.new(ref: "#/components/schemas/#{name}")
  end

  # Quick helper to create an array schema.
  def self.array_of(schema : Schema) : Schema
    Schema.new(type: "array", items: schema)
  end

  # Quick helper to create an array schema from a ref name.
  def self.array_of(ref_name : String) : Schema
    Schema.new(type: "array", items: ref(ref_name))
  end

  # Builds a parameter quickly.
  def self.param(
    name : String,
    location : String = "query",
    type : String = "string",
    format : String? = nil,
    description : String? = nil,
    required : Bool? = nil
  ) : Parameter
    schema = Schema.new(type: type, format: format)
    req = required.nil? ? (location == "path") : required
    Parameter.new(
      name: name,
      location: location,
      description: description,
      required: req,
      schema: schema
    )
  end

  # Helper to build responses from a simple hash.
  def self.responses(map : Hash(Int32, String)) : Hash(String, Response)
    result = Hash(String, Response).new
    map.each do |code, desc|
      result[code.to_s] = Response.new(status_code: code, description: desc)
    end
    result
  end

  # Helper to build responses with schemas.
  def self.response(
    status : Int32,
    description : String,
    schema : Schema? = nil,
    content_type : String = "application/json"
  ) : Response
    Response.new(
      status_code: status,
      description: description,
      schema: schema,
      content_type: content_type
    )
  end

  # Helper to create a bearer token security scheme.
  def self.bearer_auth(description : String = "JWT Bearer token") : SecurityScheme
    SecurityScheme.new(
      type: "http",
      scheme: "bearer",
      bearer_format: "JWT",
      description: description
    )
  end

  # Helper to create an API key security scheme.
  def self.api_key_auth(
    name : String = "X-API-Key",
    location : String = "header",
    description : String = "API Key"
  ) : SecurityScheme
    SecurityScheme.new(
      type: "apiKey",
      name: name,
      location: location,
      description: description
    )
  end
end
