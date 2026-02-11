require "json"
require "kemal"

require "./kemal-openapi/models/schema"
require "./kemal-openapi/models/info"
require "./kemal-openapi/models/parameter"
require "./kemal-openapi/models/response"
require "./kemal-openapi/models/operation"
require "./kemal-openapi/models/security"
require "./kemal-openapi/registry"
require "./kemal-openapi/annotation"
require "./kemal-openapi/validator"
require "./kemal-openapi/builder"
require "./kemal-openapi/handler"
require "./kemal-openapi/ui/swagger_ui"
require "./kemal-openapi/dsl"
require "./kemal-openapi/macros"

module Kemal::OpenAPI
  VERSION = "0.2.0"

  @@handler : Handler? = nil

  # Main configuration method. Call this in your app to enable OpenAPI docs.
  #
  # ```
  # Kemal::OpenAPI.configure do |config|
  #   config.info.title = "My API"
  #   config.info.version = "1.0.0"
  #   config.info.description = "A sample API"
  # end
  # ```
  def self.configure(&) : Handler
    handler = Handler.new
    yield handler.builder
    register_discovered_operations
    setup_handler(handler)
    handler
  end

  # Simple one-liner setup.
  #
  # ```
  # Kemal::OpenAPI.setup(
  #   title: "My API",
  #   version: "1.0.0"
  # )
  # ```
  def self.setup(
    title : String = "API Documentation",
    version : String = "1.0.0",
    description : String? = nil,
    spec_path : String = "/openapi.json",
    docs_path : String = "/docs",
    redoc_path : String? = "/redoc",
    servers : Array(Server) = [] of Server,
    tags : Array(Tag) = [] of Tag,
    global_security : Array(Hash(String, Array(String)))? = nil
  ) : Handler
    handler = Handler.new(
      spec_path: spec_path,
      docs_path: docs_path,
      redoc_path: redoc_path
    )
    handler.builder.info = Info.new(
      title: title,
      version: version,
      description: description
    )
    handler.builder.servers = servers
    handler.builder.tags = tags
    handler.builder.global_security = global_security
    
    register_discovered_operations
    setup_handler(handler)
    handler
  end

  # Returns the current handler (if configured).
  def self.handler : Handler?
    @@handler
  end

  private def self.setup_handler(handler : Handler)
    @@handler = handler
    add_handler handler
  end
end
