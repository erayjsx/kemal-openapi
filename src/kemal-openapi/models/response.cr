module Kemal::OpenAPI
  class Response
    property status_code : Int32
    property description : String
    property content_type : String?
    property schema : Schema?
    property headers : Hash(String, Header)?
    property examples : Hash(String, JSON::Any)?

    def initialize(
      @status_code,
      @description,
      @content_type = nil,
      @schema = nil,
      @headers = nil,
      @examples = nil
    )
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        builder.field("description", @description)

        if s = @schema
          ct = @content_type || "application/json"
          builder.field("content") do
            builder.object do
              builder.field(ct) do
                builder.object do
                  builder.field("schema") { s.to_json(builder) }

                  if exs = @examples
                    builder.field("examples") do
                      builder.object do
                        exs.each do |name, value|
                          builder.field(name) { value.to_json(builder) }
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end

        if hdrs = @headers
          builder.field("headers") do
            builder.object do
              hdrs.each do |name, header|
                builder.field(name) { header.to_json(builder) }
              end
            end
          end
        end
      end
    end
  end

  class Header
    property description : String?
    property schema : Schema?

    def initialize(@description = nil, @schema = nil)
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        builder.field("description", @description) if @description
        if s = @schema
          builder.field("schema") { s.to_json(builder) }
        end
      end
    end
  end
end
