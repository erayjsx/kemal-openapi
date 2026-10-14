require "kemal"

module Kemal::OpenAPI
  # Turns the `schema:` value of an `@[OpenAPI]` annotation into a `Schema`:
  #
  # - `"User"` becomes a `$ref` to `#/components/schemas/User`
  # - a named tuple such as `{type: "string", min_length: 3}` is passed to `Schema.new`
  # - any other expression (e.g. `Kemal::OpenAPI.array_of("User")`) is used as is
  macro schema_from_annotation(value)
    {% if value.is_a?(StringLiteral) %}
      Kemal::OpenAPI.ref({{value}})
    {% elsif value.is_a?(NamedTupleLiteral) %}
      Kemal::OpenAPI::Schema.new(**{{value}})
    {% else %}
      ({{value}}).as(Kemal::OpenAPI::Schema)
    {% end %}
  end

  # Turns the `security:` value of an `@[OpenAPI]` annotation into a security
  # requirement list. Accepts the full form
  # (`[{"bearerAuth" => [] of String}]`) or a list of scheme names
  # (`["bearerAuth"]`).
  macro security_from_annotation(value)
    {% if value.is_a?(ArrayLiteral) && value.all? { |v| v.is_a?(StringLiteral) } %}
      [
        {% for name in value %}
          { {{name}} => [] of String },
        {% end %}
      ] of Hash(String, Array(String))
    {% else %}
      {{value}}
    {% end %}
  end
end

# Route macros that shadow Kemal's DSL methods. Each route records its method
# and path in a marker method so `macro finished` below can pair it with the
# `@[OpenAPI]` annotation placed on the same route, and runs request body
# validation before the route block.
{% for method in ["get", "post", "put", "delete", "patch", "options"] %}
  macro {{method.id}}(path, &block)
    \{% raise "#{{{method}}.id} #{path} requires a block" unless block %}
    \{% if path.is_a?(StringLiteral) %}
      \{% suffix = path.gsub(/\//, "_S_").gsub(/:/, "_C_").gsub(/-/, "_D_").gsub(/\./, "_P_").gsub(/\*/, "_G_").gsub(/[^a-zA-Z0-9_]/, "_") %}
      \{% env_arg = block.args.empty? ? "__kemal_openapi_env".id : block.args.first %}

      # The user's `@[OpenAPI]` annotation attaches to this method.
      def openapi_user_def_{{method.id}}_\{{suffix.id}}
      end

      @[Kemal::OpenAPI::Internal(path: \{{path}}, method: {{method}})]
      def openapi_internal_def_{{method.id}}_\{{suffix.id}}
      end

      raise Kemal::Exceptions::InvalidPathStartException.new({{method}}, \{{path}}) unless \{{path}}.starts_with?('/')

      Kemal::RouteHandler::INSTANCE.add_route({{method.upcase}}, \{{path}}) do |\{{env_arg}}|
        next unless Kemal::OpenAPI::Validator.validate(\{{env_arg}}, {{method.upcase}}, \{{path}})
        \{{block.body}}
      end
    \{% else %}
      # Dynamic paths cannot be documented at compile time; register the route as Kemal would.
      %path = \{{path}}
      raise Kemal::Exceptions::InvalidPathStartException.new({{method}}, %path) unless %path.starts_with?('/')
      Kemal::RouteHandler::INSTANCE.add_route({{method.upcase}}, %path) \{{block}}
    \{% end %}
  end
{% end %}

macro finished
  def Kemal::OpenAPI.register_discovered_operations
    {% begin %}
      {% ops = {} of String => Hash(String, String) %}

      # First pass: collect the method and path recorded by each route macro.
      {% for method in @type.methods %}
        {% if method.name.starts_with?("openapi_internal_def_") %}
          {% if ann = method.annotation(Kemal::OpenAPI::Internal) %}
            {% ops[method.name.gsub(/^openapi_internal_def_/, "")] = {path: ann[:path], method: ann[:method]} %}
          {% end %}
        {% end %}
      {% end %}

      # Second pass: pair each `@[OpenAPI]` annotation with its route.
      {% for method in @type.methods %}
        {% if method.name.starts_with?("openapi_user_def_") %}
          {% if ann = method.annotation(OpenAPI) %}
            {% internal_data = ops[method.name.gsub(/^openapi_user_def_/, "")] %}
            {% if internal_data %}
              Kemal::OpenAPI.register(
                Kemal::OpenAPI::Operation.new(
                  method: {{internal_data[:method]}},
                  path: {{internal_data[:path]}},
                  summary: {{ann[:summary] || nil}},
                  description: {{ann[:description] || nil}},
                  operation_id: {{ann[:operation_id] || nil}},
                  tags: {{ann[:tags] || nil}},
                  deprecated: {{ann[:deprecated] || nil}},
                  {% if ann[:parameters] %}
                    parameters: ({{ann[:parameters]}}).as(Array(Kemal::OpenAPI::Parameter)),
                  {% end %}
                  {% if ann[:security] %}
                    security: Kemal::OpenAPI.security_from_annotation({{ann[:security]}}),
                  {% end %}
                  {% if rb = ann[:request_body] %}
                    request_body: Kemal::OpenAPI::RequestBody.new(
                      {% if rb.is_a?(NamedTupleLiteral) %}
                        description: {{rb[:description] || nil}},
                        required: {{rb[:required].nil? ? true : rb[:required]}},
                        content_type: {{rb[:content_type] || "application/json"}},
                        schema: {% if rb[:schema] %}Kemal::OpenAPI.schema_from_annotation({{rb[:schema]}}){% else %}nil{% end %},
                      {% else %}
                        schema: Kemal::OpenAPI.schema_from_annotation({{rb}}),
                      {% end %}
                    ),
                  {% end %}
                  responses: {
                    {% if ann[:responses] %}
                      {% for code, value in ann[:responses] %}
                        {% if code.is_a?(NumberLiteral) %}
                          {% key = code.stringify %}
                          {% status = code %}
                        {% else %}
                          {% key = code.id.stringify %}
                          {% status = key =~ /^\d+$/ ? key.to_i : nil %}
                        {% end %}
                        {{key}} => Kemal::OpenAPI::Response.new(
                          status_code: {{status}},
                          {% if value.is_a?(NamedTupleLiteral) %}
                            description: {{value[:description] || "Response"}},
                            content_type: {{value[:content_type] || nil}},
                            schema: {% if value[:schema] %}Kemal::OpenAPI.schema_from_annotation({{value[:schema]}}){% else %}nil{% end %},
                          {% else %}
                            description: {{value}},
                          {% end %}
                        ),
                      {% end %}
                    {% end %}
                  } of String => Kemal::OpenAPI::Response
                )
              )
            {% end %}
          {% end %}
        {% end %}
      {% end %}
    {% end %}
  end
end
