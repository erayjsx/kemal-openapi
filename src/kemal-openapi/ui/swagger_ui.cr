module Kemal::OpenAPI
  module SwaggerUI
    SWAGGER_UI_VERSION = "5.18.2"

    def self.html(spec_url : String = "/openapi.json", title : String = "API Documentation") : String
      <<-HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{HTML.escape(title)}</title>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@#{SWAGGER_UI_VERSION}/swagger-ui.css">
        <style>
          html { box-sizing: border-box; overflow-y: scroll; }
          *, *:before, *:after { box-sizing: inherit; }
          body { margin: 0; background: #fafafa; }
          .topbar { display: none; }
        </style>
      </head>
      <body>
        <div id="swagger-ui"></div>
        <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@#{SWAGGER_UI_VERSION}/swagger-ui-bundle.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@#{SWAGGER_UI_VERSION}/swagger-ui-standalone-preset.js"></script>
        <script>
          window.onload = function() {
            SwaggerUIBundle({
              url: "#{spec_url}",
              dom_id: '#swagger-ui',
              deepLinking: true,
              presets: [
                SwaggerUIBundle.presets.apis,
                SwaggerUIStandalonePreset
              ],
              plugins: [
                SwaggerUIBundle.plugins.DownloadUrl
              ],
              layout: "StandaloneLayout",
              defaultModelsExpandDepth: 1,
              defaultModelExpandDepth: 1,
              docExpansion: "list",
              filter: true,
              showExtensions: true,
              showCommonExtensions: true,
              tryItOutEnabled: true
            });
          };
        </script>
      </body>
      </html>
      HTML
    end

    def self.redoc_html(spec_url : String = "/openapi.json", title : String = "API Documentation") : String
      <<-HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{HTML.escape(title)}</title>
        <link href="https://fonts.googleapis.com/css?family=Montserrat:300,400,700|Roboto:300,400,700" rel="stylesheet">
        <style>
          body { margin: 0; padding: 0; }
        </style>
      </head>
      <body>
        <redoc spec-url='#{spec_url}'></redoc>
        <script src="https://cdn.redoc.ly/redoc/latest/bundles/redoc.standalone.js"></script>
      </body>
      </html>
      HTML
    end
  end
end
