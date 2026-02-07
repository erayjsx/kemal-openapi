module Kemal::OpenAPI
  class Schema
    property type : String
    property format : String?
    property items : Schema?
    property properties : Hash(String, Schema)?
    property required : Array(String)?
    property description : String?
    property enum_values : Array(String)?
    property nullable : Bool?
    property example : JSON::Any?
    property default_value : JSON::Any?
    property ref : String?
    property one_of : Array(Schema)?
    property any_of : Array(Schema)?
    property all_of : Array(Schema)?
    property additional_properties : Schema | Bool | Nil
    property minimum : Float64?
    property maximum : Float64?
    property min_length : Int32?
    property max_length : Int32?
    property pattern : String?

    def initialize(
      @type = "object",
      @format = nil,
      @items = nil,
      @properties = nil,
      @required = nil,
      @description = nil,
      @enum_values = nil,
      @nullable = nil,
      @example = nil,
      @default_value = nil,
      @ref = nil,
      @one_of = nil,
      @any_of = nil,
      @all_of = nil,
      @additional_properties = nil,
      @minimum = nil,
      @maximum = nil,
      @min_length = nil,
      @max_length = nil,
      @pattern = nil
    )
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        if r = @ref
          builder.field("$ref", r)
        else
          builder.field("type", @type)
          builder.field("format", @format) if @format
          builder.field("description", @description) if @description
          builder.field("nullable", @nullable) if @nullable

          if items = @items
            builder.field("items") { items.to_json(builder) }
          end

          if props = @properties
            builder.field("properties") do
              builder.object do
                props.each do |name, schema|
                  builder.field(name) { schema.to_json(builder) }
                end
              end
            end
          end

          if req = @required
            builder.field("required") do
              builder.array do
                req.each { |r| builder.string(r) }
              end
            end
          end

          if ev = @enum_values
            builder.field("enum") do
              builder.array do
                ev.each { |v| builder.string(v) }
              end
            end
          end

          if ex = @example
            builder.field("example") { ex.to_json(builder) }
          end

          if dv = @default_value
            builder.field("default") { dv.to_json(builder) }
          end

          if one = @one_of
            builder.field("oneOf") do
              builder.array { one.each { |s| s.to_json(builder) } }
            end
          end

          if any = @any_of
            builder.field("anyOf") do
              builder.array { any.each { |s| s.to_json(builder) } }
            end
          end

          if all = @all_of
            builder.field("allOf") do
              builder.array { all.each { |s| s.to_json(builder) } }
            end
          end

          case ap = @additional_properties
          when Schema
            builder.field("additionalProperties") { ap.to_json(builder) }
          when Bool
            builder.field("additionalProperties", ap)
          end

          builder.field("minimum", @minimum) if @minimum
          builder.field("maximum", @maximum) if @maximum
          builder.field("minLength", @min_length) if @min_length
          builder.field("maxLength", @max_length) if @max_length
          builder.field("pattern", @pattern) if @pattern
        end
      end
    end
  end
end
