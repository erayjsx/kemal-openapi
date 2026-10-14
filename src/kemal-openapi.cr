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
  VERSION = "0.6.0"

  @@handler : Handler? = nil

  # When enabled, the value returned by each annotated route is checked
  # against the documented response schema for its status code, and
  # mismatches are logged as warnings (`kemal.openapi` log source). Meant for
  # development and tests; responses are never modified.
  class_property? validate_responses : Bool = false

  # Environment variable that makes `setup`/`configure` write the spec to the
  # given path and exit, so it can be generated without starting the server:
  #
  # ```sh
  # KEMAL_OPENAPI_EXPORT=openapi.json crystal run src/app.cr
  # ```
  EXPORT_ENV = "KEMAL_OPENAPI_EXPORT"

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
    handler =
      if current = @@handler
        acquire_handler(
          current.spec_path,
          current.docs_path,
          current.redoc_path
        )
      else
        acquire_handler("/openapi.json", "/docs", "/redoc")
      end

    handler.builder = Builder.new
    yield handler.builder
    handler.ui_title = handler.builder.info.title
    discover_operations(force: true)
    handler.invalidate_cache!
    export_if_requested(handler)
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
    global_security : Array(Hash(String, Array(String)))? = nil,
    max_request_body_size : Int32? = nil,
    shutdown_timeout : Time::Span? = nil,
    max_multipart_form_field_size : Int32? = nil,
    websocket_allowed_origins : Array(String)? = nil,
    auto_operation_ids : Bool = true,
    validate_responses : Bool? = nil,
  ) : Handler
    handler = acquire_handler(
      spec_path: spec_path,
      docs_path: docs_path,
      redoc_path: redoc_path
    )
    handler.builder = Builder.new
    handler.builder.info = Info.new(
      title: title,
      version: version,
      description: description
    )
    handler.builder.servers = servers
    handler.builder.tags = tags
    handler.builder.global_security = global_security
    handler.builder.auto_operation_ids = auto_operation_ids
    handler.ui_title = title
    self.validate_responses = validate_responses unless validate_responses.nil?

    Kemal.config.max_request_body_size = max_request_body_size if max_request_body_size
    Kemal.config.shutdown_timeout = shutdown_timeout if shutdown_timeout
    Kemal.config.max_multipart_form_field_size = max_multipart_form_field_size if max_multipart_form_field_size
    Kemal.config.websocket_allowed_origins = websocket_allowed_origins if websocket_allowed_origins

    discover_operations(force: true)
    handler.invalidate_cache!
    export_if_requested(handler)
    handler
  end

  # The current spec as a JSON string, as served at the spec path.
  def self.spec_json : String
    (handler.try(&.builder) || Builder.new).to_json
  end

  # Writes the current spec to *path* as pretty-printed JSON.
  def self.write_spec(path : String | Path) : Nil
    discover_operations
    (handler.try(&.builder) || Builder.new).write(path)
  end

  private def self.export_if_requested(handler : Handler) : Nil
    return unless path = ENV[EXPORT_ENV]?.presence
    handler.builder.write(path)
    STDOUT.puts "OpenAPI spec written to #{path}"
    exit 0
  end

  # Returns the current handler (if configured).
  def self.handler : Handler?
    @@handler
  end

  private def self.acquire_handler(
    spec_path : String,
    docs_path : String,
    redoc_path : String?,
  ) : Handler
    if handler = @@handler
      handler.spec_path = spec_path
      handler.docs_path = docs_path
      handler.redoc_path = redoc_path
      ensure_handler_registered(handler)
      handler
    else
      handler = Handler.new(
        spec_path: spec_path,
        docs_path: docs_path,
        redoc_path: redoc_path
      )
      @@handler = handler
      ensure_handler_registered(handler)
      handler
    end
  end

  private def self.ensure_handler_registered(handler : Handler)
    unless Kemal::Config::CUSTOM_HANDLERS.any? { |_, existing| existing.same?(handler) }
      Kemal.config.add_handler(handler)
    end
  end
end
