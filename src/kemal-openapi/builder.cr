require "json"

module Kemal::OpenAPI
  class Builder
    property info : Info
    property servers : Array(Server)
    property tags : Array(Tag)
    property operations : Array(Operation)
    property schemas : Hash(String, Schema)
    property security_schemes : Hash(String, SecurityScheme)
    property global_security : Array(Hash(String, Array(String)))?

    def initialize(
      @info = Info.new,
      @servers = [] of Server,
      @tags = [] of Tag,
      @operations = OPERATIONS,
      @schemas = SCHEMAS,
      @security_schemes = SECURITY_SCHEMES,
      @global_security = nil
    )
    end

    def to_json : String
      JSON.build do |json|
        json.object do
          json.field("openapi", "3.1.0")

          json.field("info") { @info.to_json(json) }

          unless @servers.empty?
            json.field("servers") do
              json.array { @servers.each { |s| s.to_json(json) } }
            end
          end

          unless @tags.empty?
            json.field("tags") do
              json.array { @tags.each { |t| t.to_json(json) } }
            end
          end

          # Group operations by path
          paths = Hash(String, Array(Operation)).new
          @operations.each do |op|
            openapi_path = kemal_to_openapi_path(op.path)
            paths[openapi_path] ||= [] of Operation
            paths[openapi_path] << op
          end

          json.field("paths") do
            json.object do
              paths.each do |path, ops|
                json.field(path) do
                  json.object do
                    ops.each do |op|
                      json.field(op.method.downcase) { op.to_json(json) }
                    end
                  end
                end
              end
            end
          end

          # Components
          has_schemas = !@schemas.empty?
          has_security = !@security_schemes.empty?

          if has_schemas || has_security
            json.field("components") do
              json.object do
                if has_schemas
                  json.field("schemas") do
                    json.object do
                      @schemas.each do |name, schema|
                        json.field(name) { schema.to_json(json) }
                      end
                    end
                  end
                end

                if has_security
                  json.field("securitySchemes") do
                    json.object do
                      @security_schemes.each do |name, scheme|
                        json.field(name) { scheme.to_json(json) }
                      end
                    end
                  end
                end
              end
            end
          end

          if gs = @global_security
            json.field("security") do
              json.array do
                gs.each do |item|
                  json.object do
                    item.each do |name, scopes|
                      json.field(name) do
                        json.array { scopes.each { |s| json.string(s) } }
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    # Convert Kemal path params (:id) to OpenAPI format ({id})
    private def kemal_to_openapi_path(path : String) : String
      path.gsub(/:(\w+)/) { |_, match| "{#{match[1]}}" }
    end
  end
end
