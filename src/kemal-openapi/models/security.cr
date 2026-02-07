module Kemal::OpenAPI
  class SecurityScheme
    property type : String          # "apiKey", "http", "oauth2", "openIdConnect"
    property description : String?
    property name : String?         # Required for apiKey
    property location : String?     # Required for apiKey: "query", "header", "cookie"
    property scheme : String?       # Required for http: "bearer", "basic"
    property bearer_format : String? # Optional for http bearer
    property flows : OAuthFlows?    # Required for oauth2

    def initialize(
      @type,
      @description = nil,
      @name = nil,
      @location = nil,
      @scheme = nil,
      @bearer_format = nil,
      @flows = nil
    )
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        builder.field("type", @type)
        builder.field("description", @description) if @description
        builder.field("name", @name) if @name
        builder.field("in", @location) if @location
        builder.field("scheme", @scheme) if @scheme
        builder.field("bearerFormat", @bearer_format) if @bearer_format
        if f = @flows
          builder.field("flows") { f.to_json(builder) }
        end
      end
    end
  end

  class OAuthFlows
    property implicit : OAuthFlow?
    property password : OAuthFlow?
    property client_credentials : OAuthFlow?
    property authorization_code : OAuthFlow?

    def initialize(
      @implicit = nil,
      @password = nil,
      @client_credentials = nil,
      @authorization_code = nil
    )
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        if f = @implicit
          builder.field("implicit") { f.to_json(builder) }
        end
        if f = @password
          builder.field("password") { f.to_json(builder) }
        end
        if f = @client_credentials
          builder.field("clientCredentials") { f.to_json(builder) }
        end
        if f = @authorization_code
          builder.field("authorizationCode") { f.to_json(builder) }
        end
      end
    end
  end

  class OAuthFlow
    property authorization_url : String?
    property token_url : String?
    property refresh_url : String?
    property scopes : Hash(String, String)

    def initialize(
      @scopes = Hash(String, String).new,
      @authorization_url = nil,
      @token_url = nil,
      @refresh_url = nil
    )
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        builder.field("authorizationUrl", @authorization_url) if @authorization_url
        builder.field("tokenUrl", @token_url) if @token_url
        builder.field("refreshUrl", @refresh_url) if @refresh_url
        builder.field("scopes") do
          builder.object do
            @scopes.each { |k, v| builder.field(k, v) }
          end
        end
      end
    end
  end

  class Tag
    property name : String
    property description : String?

    def initialize(@name, @description = nil)
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        builder.field("name", @name)
        builder.field("description", @description) if @description
      end
    end
  end

  class Server
    property url : String
    property description : String?

    def initialize(@url, @description = nil)
    end

    def to_json(builder : JSON::Builder) : Nil
      builder.object do
        builder.field("url", @url)
        builder.field("description", @description) if @description
      end
    end
  end
end
