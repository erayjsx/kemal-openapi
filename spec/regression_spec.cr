require "./spec_helper"

@[OpenAPI(
  summary: "Macro string response regression",
  responses: {
    200 => "OK"
  }
)]
get "/__openapi_spec_macro_string_response" do |env|
  "ok"
end

describe "Kemal::OpenAPI regressions" do
  before_each do
    Kemal::OpenAPI::OPERATIONS.clear
    Kemal::OpenAPI::OPERATIONS_MAP.clear
    Kemal::OpenAPI::SCHEMAS.clear
    Kemal::OpenAPI::SECURITY_SCHEMES.clear
  end

  it "keeps operation registry unique by method and path" do
    key_path = "/__openapi_registry_dedupe"

    Kemal::OpenAPI.register(
      Kemal::OpenAPI::Operation.new(
        method: "get",
        path: key_path,
        summary: "first",
        responses: {
          "200" => Kemal::OpenAPI::Response.new(status_code: 200, description: "ok"),
        }
      )
    )

    Kemal::OpenAPI.register(
      Kemal::OpenAPI::Operation.new(
        method: "get",
        path: key_path,
        summary: "second",
        responses: {
          "200" => Kemal::OpenAPI::Response.new(status_code: 200, description: "ok"),
        }
      )
    )

    Kemal::OpenAPI::OPERATIONS.size.should eq(1)
    Kemal::OpenAPI::OPERATIONS_MAP["GET #{key_path}"].summary.should eq("second")
  end

  it "does not duplicate discovered operations on repeated setup" do
    Kemal::OpenAPI.setup(title: "A", version: "1.0.0")
    Kemal::OpenAPI::OPERATIONS.size.should eq(1)

    Kemal::OpenAPI.setup(title: "B", version: "2.0.0")
    Kemal::OpenAPI::OPERATIONS.size.should eq(1)
  end

  it "does not force schema ref for string response shorthand" do
    handler = Kemal::OpenAPI.setup(title: "A", version: "1.0.0")
    spec = JSON.parse(handler.builder.to_json)
    response = spec["paths"]["/__openapi_spec_macro_string_response"]["get"]["responses"]["200"]

    response["description"].as_s.should eq("OK")
    response["content"]?.should be_nil
  end

  it "fails validation when schema reference is missing" do
    Kemal::OpenAPI.register(
      Kemal::OpenAPI::Operation.new(
        method: "post",
        path: "/__openapi_missing_ref",
        request_body: Kemal::OpenAPI::RequestBody.new(
          schema: Kemal::OpenAPI.ref("MissingSchema")
        ),
        responses: {
          "200" => Kemal::OpenAPI::Response.new(status_code: 200, description: "OK"),
        }
      )
    )

    request = HTTP::Request.new("POST", "/__openapi_missing_ref", body: %({"name":"john"}))
    io = IO::Memory.new
    server_response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, server_response)

    valid = Kemal::OpenAPI::Validator.validate(context, "POST", "/__openapi_missing_ref")

    server_response.close
    io.rewind
    client_response = HTTP::Client::Response.from_io(io, decompress: false)
    body = JSON.parse(client_response.body)

    valid.should be_false
    client_response.status_code.should eq(422)
    body["message"].as_s.should contain("Schema reference not found")
  end
end
