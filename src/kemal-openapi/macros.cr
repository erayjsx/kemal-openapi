
require "kemal"

{% for method in ["get", "post", "put", "delete", "patch", "options"] %}
  macro {{method.id}}(path, &block)
    # 1. User's annotation attaches to this method
    # We use a sanitized path to ensure uniqueness.
    # / -> _S_
    # : -> _C_
    # - -> _D_
    # . -> _P_
    # Others -> _
    def openapi_user_def_{{method.id}}_\{\{path.id.gsub(/\//, "_S_").gsub(/:/, "_C_").gsub(/-/, "_D_").gsub(/\./, "_P_").gsub(/[^a-zA-Z0-9_]/, "_")}}
    end

    # 2. Our internal annotation attaches to this method
    @[Kemal::OpenAPI::Internal(path: \{{path}}, method: {{method.id.stringify}})]
    def openapi_internal_def_{{method.id}}_\{\{path.id.gsub(/\//, "_S_").gsub(/:/, "_C_").gsub(/-/, "_D_").gsub(/\./, "_P_").gsub(/[^a-zA-Z0-9_]/, "_")}}
    end

    Kemal::RouteHandler::INSTANCE.add_route({{method.upcase}}, \{{path}}) do |env|
      unless Kemal::OpenAPI::Validator.validate(env, {{method.upcase}}, \{{path}})
        next
      end
      \{{yield}}
    end
  end
{% end %}

macro finished
  def Kemal::OpenAPI.register_discovered_operations
    {% begin %}
    {% 
      ops = {} of String => Hash(String, String) 
    %}

    # First pass: Collect internal info (path, method)
    {% for method in @type.methods %}
      {% if method.name.starts_with?("openapi_internal_def_") %}
        {% if ann = method.annotation(Kemal::OpenAPI::Internal) %}
           {% 
             suffix = method.name.gsub(/^openapi_internal_def_/, "")
             ops[suffix] = {
               path: ann[:path],
               method: ann[:method]
             }
           %}
        {% end %}
      {% end %}
    {% end %}

    # Second pass: Collect user info and generate registration code
    {% for method in @type.methods %}
      {% if method.name.starts_with?("openapi_user_def_") %}
        {% if ann = method.annotation(OpenAPI) %}
          {% 
            suffix = method.name.gsub(/^openapi_user_def_/, "")
            internal_data = ops[suffix]
          %}
          
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
                
                # Request Body Handling
                {% if ann[:request_body] %}
                  request_body: Kemal::OpenAPI::RequestBody.new(
                    {% if ann[:request_body].is_a?(StringLiteral) %}
                      schema: Kemal::OpenAPI.ref({{ann[:request_body]}})
                    {% elsif ann[:request_body].is_a?(NamedTupleLiteral) %}
                      description: {{ann[:request_body][:description] || nil}},
                      required: {{ann[:request_body][:required].nil? ? true : ann[:request_body][:required]}},
                      content_type: {{ann[:request_body][:content_type] || "application/json"}},
                      schema: {{ann[:request_body][:schema] ? (ann[:request_body][:schema].is_a?(StringLiteral) ? "Kemal::OpenAPI.ref(#{ann[:request_body][:schema]})".id : "Kemal::OpenAPI::Schema.new(#{ann[:request_body][:schema]})".id) : nil}}
                    {% end %}
                  ),
                {% end %}

                # Responses Handling
                responses: {
                  {% if ann[:responses] %}
                    {% for code, value in ann[:responses] %}
                      {{code.stringify}} => Kemal::OpenAPI::Response.new(
                        status_code: {{code.is_a?(NumberLiteral) ? code : 200}}, # Default or parse
                        {% if value.is_a?(StringLiteral) %}
                          description: {{value}},
                          schema: Kemal::OpenAPI.ref({{value}}) # Assume string is ref if looks like type? Or just description?
                        {% elsif value.is_a?(NamedTupleLiteral) %}
                          description: {{value[:description] || "Response"}},
                          schema: {{value[:schema] ? "Kemal::OpenAPI.ref(#{value[:schema]})".id : nil}}
                        {% end %}
                      ),
                    {% end %}
                  {% end %}
                }
              )
            )
          {% end %}
        {% end %}
      {% end %}
    {% end %}
    {% end %}
  end
end
