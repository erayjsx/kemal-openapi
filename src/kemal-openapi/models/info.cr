module Kemal::OpenAPI
  class Info
    property title : String
    property version : String
    property description : String?
    property terms_of_service : String?
    property contact : Contact?
    property license : License?

    def initialize(
      @title = "API Documentation",
      @version = "1.0.0",
      @description = nil,
      @terms_of_service = nil,
      @contact = nil,
      @license = nil
    )
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        builder.field("title", @title)
        builder.field("version", @version)
        builder.field("description", @description) if @description
        builder.field("termsOfService", @terms_of_service) if @terms_of_service
        if c = @contact
          builder.field("contact") { c.to_json(builder) }
        end
        if l = @license
          builder.field("license") { l.to_json(builder) }
        end
      end
    end
  end

  class Contact
    property name : String?
    property url : String?
    property email : String?

    def initialize(@name = nil, @url = nil, @email = nil)
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        builder.field("name", @name) if @name
        builder.field("url", @url) if @url
        builder.field("email", @email) if @email
      end
    end
  end

  class License
    property name : String
    property url : String?

    def initialize(@name, @url = nil)
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        builder.field("name", @name)
        builder.field("url", @url) if @url
      end
    end
  end
end
