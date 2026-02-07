module Kemal::OpenAPI
  class Parameter
    property name : String
    property location : String  # "query", "header", "path", "cookie"
    property description : String?
    property required : Bool
    property schema : Schema?
    property deprecated : Bool?
    property allow_empty_value : Bool?
    property example : JSON::Any?

    def initialize(
      @name,
      @location = "query",
      @description = nil,
      @required = false,
      @schema = nil,
      @deprecated = nil,
      @allow_empty_value = nil,
      @example = nil
    )
      # Path parameters are always required per OpenAPI spec
      @required = true if @location == "path"
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        builder.field("name", @name)
        builder.field("in", @location)
        builder.field("description", @description) if @description
        builder.field("required", @required)
        builder.field("deprecated", @deprecated) if @deprecated
        builder.field("allowEmptyValue", @allow_empty_value) if @allow_empty_value

        if s = @schema
          builder.field("schema") { s.to_json(builder) }
        end

        if ex = @example
          builder.field("example") { ex.to_json(builder) }
        end
      end
    end
  end
end
