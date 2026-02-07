module Kemal::OpenAPI
  class Operation
    property method : String
    property path : String
    property summary : String?
    property description : String?
    property operation_id : String?
    property tags : Array(String)?
    property parameters : Array(Parameter)?
    property request_body : RequestBody?
    property responses : Hash(String, Response)
    property deprecated : Bool?
    property security : Array(Hash(String, Array(String)))?

    def initialize(
      @method,
      @path,
      @summary = nil,
      @description = nil,
      @operation_id = nil,
      @tags = nil,
      @parameters = nil,
      @request_body = nil,
      @responses = Hash(String, Response).new,
      @deprecated = nil,
      @security = nil
    )
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        if tags = @tags
          builder.field("tags") do
            builder.array { tags.each { |t| builder.string(t) } }
          end
        end

        builder.field("summary", @summary) if @summary
        builder.field("description", @description) if @description
        builder.field("operationId", @operation_id) if @operation_id
        builder.field("deprecated", @deprecated) if @deprecated

        if params = @parameters
          builder.field("parameters") do
            builder.array { params.each { |p| p.to_json(builder) } }
          end
        end

        if rb = @request_body
          builder.field("requestBody") { rb.to_json(builder) }
        end

        builder.field("responses") do
          builder.object do
            @responses.each do |code, response|
              builder.field(code) { response.to_json(builder) }
            end
          end
        end

        if sec = @security
          builder.field("security") do
            builder.array do
              sec.each do |item|
                builder.object do
                  item.each do |name, scopes|
                    builder.field(name) do
                      builder.array { scopes.each { |s| builder.string(s) } }
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

  class RequestBody
    property description : String?
    property content_type : String
    property schema : Schema?
    property required : Bool

    def initialize(
      @content_type = "application/json",
      @schema = nil,
      @description = nil,
      @required = true
    )
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        builder.field("description", @description) if @description
        builder.field("required", @required)
        builder.field("content") do
          builder.object do
            builder.field(@content_type) do
              builder.object do
                if s = @schema
                  builder.field("schema") { s.to_json(builder) }
                end
              end
            end
          end
        end
      end
    end
  end
end
