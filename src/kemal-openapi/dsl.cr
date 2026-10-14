require "json"

module Kemal::OpenAPI
  # ============================================================
  # Top-level DSL helpers — designed to be used in application code.
  # ============================================================

  # Builds a `Schema` from a class or struct that includes `JSON::Serializable`.
  #
  # ```
  # schema = Kemal::OpenAPI.schema_for(User)
  # ```
  #
  # Property names follow `@[JSON::Field(key: ...)]`, fields marked
  # `ignore: true` are skipped, and a field is required unless it is
  # nilable or has a default value. Nested serializable types are inlined
  # (up to *max_depth* levels deep, so recursive types still compile);
  # register them with `register_schema` and use `ref` to share them instead.
  def self.schema_for(klass : T.class, depth : Int32 = 0, max_depth : Int32 = 4) : Schema forall T
    props = Hash(String, Schema).new
    required = [] of String

    {% for ivar in T.instance_vars %}
      {% ann = ivar.annotation(JSON::Field) %}
      {% key = ann && ann[:key] ? ann[:key] : ivar.name.stringify %}
      {% unless ann && ann[:ignore] %}
        props[{{key}}] = Kemal::OpenAPI.schema_for_type(::Union({{ivar.type.union? ? ivar.type.union_types.splat : ivar.type}}), depth, max_depth)
        {% unless ivar.type.nilable? || ivar.has_default_value? %}
          required << {{key}}
        {% end %}
      {% end %}
    {% end %}

    Schema.new(
      type: "object",
      properties: props,
      required: required.empty? ? nil : required
    )
  end

  # Builds a `Schema` for a single Crystal type. Used by `schema_for`.
  def self.schema_for_type(type : T.class, depth : Int32 = 0, max_depth : Int32 = 4) : Schema forall T
    {% begin %}
    {% t = T %}
    {% if t.union? %}
      {% members = t.union_types.reject { |m| m == Nil } %}
      {% if members.size == 1 %}
        schema = Kemal::OpenAPI.schema_for_type(::Union({{members[0]}}), depth, max_depth)
        schema.nullable = true if {{t.nilable?}}
        schema
      {% else %}
        Kemal::OpenAPI::Schema.new(
          type: nil,
          nullable: {{t.nilable? ? true : nil}},
          any_of: [
            {% for member in members %}
              Kemal::OpenAPI.schema_for_type(::Union({{member}}), depth, max_depth),
            {% end %}
          ] of Kemal::OpenAPI::Schema
        )
      {% end %}
    {% elsif t == String || t == Char %}
      Kemal::OpenAPI::Schema.new(type: "string")
    {% elsif t == Bool %}
      Kemal::OpenAPI::Schema.new(type: "boolean")
    {% elsif t <= Int %}
      Kemal::OpenAPI::Schema.new(
        type: "integer",
        format: {{[Int64, UInt32, UInt64].includes?(t) ? "int64" : ([Int8, Int16, Int32, UInt8, UInt16].includes?(t) ? "int32" : nil)}},
        minimum: {{t.name.starts_with?("UInt") ? 0.0 : nil}}
      )
    {% elsif t <= Float %}
      Kemal::OpenAPI::Schema.new(type: "number", format: {{t == Float32 ? "float" : "double"}})
    {% elsif t == Time %}
      Kemal::OpenAPI::Schema.new(type: "string", format: "date-time")
    {% elsif t.name == "UUID" %}
      Kemal::OpenAPI::Schema.new(type: "string", format: "uuid")
    {% elsif t == JSON::Any %}
      Kemal::OpenAPI::Schema.new(type: ["object", "array", "string", "number", "boolean", "null"])
    {% elsif t < Enum %}
      Kemal::OpenAPI::Schema.new(type: "string", enum_values: {{t.constants.map(&.stringify.underscore)}})
    {% elsif t <= Array || t <= Set || t <= Deque || t <= Slice %}
      Kemal::OpenAPI::Schema.new(
        type: "array",
        items: Kemal::OpenAPI.schema_for_type(::Union({{t.type_vars[0]}}), depth, max_depth),
        unique_items: {{t <= Set ? true : nil}}
      )
    {% elsif t <= Hash %}
      Kemal::OpenAPI::Schema.new(
        type: "object",
        additional_properties: Kemal::OpenAPI.schema_for_type(::Union({{t.type_vars[1]}}), depth, max_depth)
      )
    {% elsif t <= JSON::Serializable %}
      if depth < max_depth
        Kemal::OpenAPI.schema_for({{t}}, depth + 1, max_depth)
      else
        Kemal::OpenAPI::Schema.new(type: "object")
      end
    {% else %}
      Kemal::OpenAPI::Schema.new(type: "object")
    {% end %}
    {% end %}
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
    type : String | Array(String) = "string",
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
