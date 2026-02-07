require "kemal"

module Kemal::OpenAPI
  class Handler < Kemal::Handler
    property builder : Builder
    property spec_path : String
    property docs_path : String
    property redoc_path : String?
    property ui_title : String

    @spec_cache : String? = nil

    def initialize(
      @builder = Builder.new,
      @spec_path = "/openapi.json",
      @docs_path = "/docs",
      @redoc_path = "/redoc",
      @ui_title = "API Documentation"
    )
    end

    def call(context : HTTP::Server::Context)
      path = context.request.path

      case path
      when @spec_path
        serve_spec(context)
      when @docs_path
        serve_swagger_ui(context)
      when @redoc_path
        serve_redoc(context) if @redoc_path
      else
        call_next(context)
      end
    end

    private def serve_spec(context : HTTP::Server::Context)
      context.response.content_type = "application/json"
      context.response.headers["Access-Control-Allow-Origin"] = "*"
      context.response.print(spec_json)
    end

    private def serve_swagger_ui(context : HTTP::Server::Context)
      context.response.content_type = "text/html"
      context.response.print(SwaggerUI.html(@spec_path, @ui_title))
    end

    private def serve_redoc(context : HTTP::Server::Context)
      context.response.content_type = "text/html"
      context.response.print(SwaggerUI.redoc_html(@spec_path, @ui_title))
    end

    private def spec_json : String
      @spec_cache ||= @builder.to_json
    end

    # Force regeneration of cached spec (useful for development)
    def invalidate_cache!
      @spec_cache = nil
    end
  end
end
