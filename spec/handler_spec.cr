require "./spec_helper"

private def make_request(method : String, path : String, handler : Kemal::OpenAPI::Handler) : {Int32, HTTP::Headers, String}
  request = HTTP::Request.new(method, path)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler.call(context)
  response.close
  io.rewind
  client_response = HTTP::Client::Response.from_io(io, decompress: false)
  {client_response.status_code, client_response.headers, client_response.body}
end

describe Kemal::OpenAPI::Handler do
  before_each do
    Kemal::OpenAPI::OPERATIONS.clear
    Kemal::OpenAPI::SCHEMAS.clear
    Kemal::OpenAPI::SECURITY_SCHEMES.clear
  end

  it "serves OpenAPI JSON spec" do
    Kemal::OpenAPI.register(
      Kemal::OpenAPI::Operation.new(
        method: "get",
        path: "/api/health",
        summary: "Health check",
        responses: {
          "200" => Kemal::OpenAPI::Response.new(status_code: 200, description: "OK"),
        }
      )
    )

    handler = Kemal::OpenAPI::Handler.new
    handler.builder.info = Kemal::OpenAPI::Info.new(title: "Test", version: "1.0.0")

    status, headers, body = make_request("GET", "/openapi.json", handler)

    status.should eq(200)
    headers["Content-Type"].should eq("application/json")
    headers["Access-Control-Allow-Origin"].should eq("*")

    json = JSON.parse(body)
    json["openapi"].as_s.should eq("3.0.3")
    json["info"]["title"].as_s.should eq("Test")
    json["paths"]["/api/health"]["get"]["summary"].as_s.should eq("Health check")
  end

  it "serves Swagger UI HTML" do
    handler = Kemal::OpenAPI::Handler.new
    status, headers, body = make_request("GET", "/docs", handler)

    status.should eq(200)
    headers["Content-Type"].should eq("text/html")
    body.should contain("swagger-ui")
    body.should contain("/openapi.json")
  end

  it "serves ReDoc HTML" do
    handler = Kemal::OpenAPI::Handler.new
    status, headers, body = make_request("GET", "/redoc", handler)

    status.should eq(200)
    headers["Content-Type"].should eq("text/html")
    body.should contain("redoc")
  end

  it "uses custom spec and docs paths" do
    handler = Kemal::OpenAPI::Handler.new(
      spec_path: "/api/spec.json",
      docs_path: "/api/docs",
      redoc_path: "/api/redoc"
    )
    handler.builder.info = Kemal::OpenAPI::Info.new(title: "Custom", version: "2.0.0")

    status, headers, body = make_request("GET", "/api/spec.json", handler)
    headers["Content-Type"].should eq("application/json")

    json = JSON.parse(body)
    json["info"]["title"].as_s.should eq("Custom")
  end

  it "caches spec JSON" do
    handler = Kemal::OpenAPI::Handler.new

    _, _, body1 = make_request("GET", "/openapi.json", handler)
    _, _, body2 = make_request("GET", "/openapi.json", handler)

    body1.should eq(body2)
  end

  it "invalidates cache" do
    handler = Kemal::OpenAPI::Handler.new
    handler.builder.info = Kemal::OpenAPI::Info.new(title: "V1", version: "1.0.0")

    _, _, body1 = make_request("GET", "/openapi.json", handler)

    handler.builder.info = Kemal::OpenAPI::Info.new(title: "V2", version: "2.0.0")
    handler.invalidate_cache!

    _, _, body2 = make_request("GET", "/openapi.json", handler)

    body1.should_not eq(body2)
    JSON.parse(body2)["info"]["title"].as_s.should eq("V2")
  end
end
