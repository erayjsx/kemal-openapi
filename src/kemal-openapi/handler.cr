require "kemal"

module Kemal::OpenAPI
  class Handler < Kemal::Handler
    property builder : Builder
    property spec_path : String
    property docs_path : String
    property redoc_path : String?
    property ui_title : String

    @spec_cache : String? = nil
    @spec_cache_version : Int64 = -1

    def initialize(
      @builder = Builder.new,
      @spec_path = "/openapi.json",
      @docs_path = "/docs",
      @redoc_path = "/redoc",
      @ui_title = "API Documentation",
    )
    end

    def call(context : HTTP::Server::Context)
      return call_next(context) unless context.request.method.in?("GET", "HEAD")

      path = context.request.path
      if path == @spec_path
        serve_spec(context)
      elsif path == @docs_path
        serve_swagger_ui(context)
      elsif (redoc_path = @redoc_path) && path == redoc_path
        serve_redoc(context)
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

    # The spec served at `spec_path`. It is cached and rebuilt whenever the
    # builder's registry changes.
    def spec_json : String
      version = @builder.registry.version
      cache = @spec_cache
      if cache.nil? || version != @spec_cache_version
        cache = @spec_cache = @builder.to_json
        @spec_cache_version = version
      end
      cache
    end

    # Forces the spec to be rebuilt on the next request.
    def invalidate_cache!
      @spec_cache = nil
    end
  end
end
