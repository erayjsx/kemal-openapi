
require "json"

module Kemal::OpenAPI
  class Schema
    # JSON Schema type(s). When left `nil`, `"object"` is assumed unless the
    # schema is a pure composition (`oneOf`/`anyOf`/`allOf`), a `$ref` or an
    # `enum`, in which case no `type` is emitted. See `#effective_type`.
    property type : String | Array(String) | Nil
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
    property exclusive_minimum : Float64?
    property exclusive_maximum : Float64?
    property multiple_of : Float64?
    property min_items : Int32?
    property max_items : Int32?
    property unique_items : Bool?
    property title : String?
    property read_only : Bool?
    property write_only : Bool?
    property deprecated : Bool?

    def initialize(
      @type = nil,
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
      @pattern = nil,
      @exclusive_minimum = nil,
      @exclusive_maximum = nil,
      @multiple_of = nil,
      @min_items = nil,
      @max_items = nil,
      @unique_items = nil,
      @title = nil,
      @read_only = nil,
      @write_only = nil,
      @deprecated = nil
    )
    end

    # The type this schema describes, with the implicit `"object"` default
    # applied. Returns `nil` when the schema places no constraint on the type.
    def effective_type : String | Array(String) | Nil
      return @type if @type
      return nil if @ref || @one_of || @any_of || @all_of || @enum_values
      "object"
    end

    # The effective type as a list, or `nil` when any type is allowed.
    def type_list : Array(String)?
      case t = effective_type
      when String then [t]
      when Array  then t
      end
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        if r = @ref
          builder.field("$ref", r)
        else
          # OpenAPI 3.1 replaces `nullable` with a `"null"` member in `type`.
          if types = type_list
            if @nullable && !types.includes?("null")
              builder.field("type", types + ["null"])
            else
              builder.field("type", effective_type)
            end
          end

          builder.field("title", @title) if @title
          builder.field("format", @format) if @format
          builder.field("description", @description) if @description
          builder.field("deprecated", @deprecated) if @deprecated
          builder.field("readOnly", @read_only) if @read_only
          builder.field("writeOnly", @write_only) if @write_only

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
          builder.field("exclusiveMinimum", @exclusive_minimum) if @exclusive_minimum
          builder.field("exclusiveMaximum", @exclusive_maximum) if @exclusive_maximum
          builder.field("multipleOf", @multiple_of) if @multiple_of
          builder.field("minLength", @min_length) if @min_length
          builder.field("maxLength", @max_length) if @max_length
          builder.field("pattern", @pattern) if @pattern
          builder.field("minItems", @min_items) if @min_items
          builder.field("maxItems", @max_items) if @max_items
          builder.field("uniqueItems", @unique_items) if @unique_items
        end
      end
    end
  end
end
