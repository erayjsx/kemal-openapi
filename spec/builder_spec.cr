require "./spec_helper"

describe Kemal::OpenAPI::Builder do
  before_each do
    Kemal::OpenAPI::OPERATIONS.clear
    Kemal::OpenAPI::SCHEMAS.clear
    Kemal::OpenAPI::SECURITY_SCHEMES.clear
  end

  it "generates minimal valid OpenAPI spec" do
    builder = Kemal::OpenAPI::Builder.new
    builder.info = Kemal::OpenAPI::Info.new(title: "Test", version: "1.0.0")

    json = JSON.parse(builder.to_json)
    json["openapi"].as_s.should eq("3.0.3")
    json["info"]["title"].as_s.should eq("Test")
    json["info"]["version"].as_s.should eq("1.0.0")
    json["paths"].as_h.should be_empty
  end

  it "generates spec with operations" do
    Kemal::OpenAPI.register(
      Kemal::OpenAPI::Operation.new(
        method: "get",
        path: "/api/users",
        summary: "List users",
        tags: ["Users"],
        responses: {
          "200" => Kemal::OpenAPI::Response.new(status_code: 200, description: "OK"),
        }
      )
    )

    Kemal::OpenAPI.register(
      Kemal::OpenAPI::Operation.new(
        method: "post",
        path: "/api/users",
        summary: "Create user",
        tags: ["Users"],
        responses: {
          "201" => Kemal::OpenAPI::Response.new(status_code: 201, description: "Created"),
        }
      )
    )

    builder = Kemal::OpenAPI::Builder.new
    json = JSON.parse(builder.to_json)

    json["paths"]["/api/users"]["get"]["summary"].as_s.should eq("List users")
    json["paths"]["/api/users"]["post"]["summary"].as_s.should eq("Create user")
  end

  it "converts kemal path params to openapi format" do
    Kemal::OpenAPI.register(
      Kemal::OpenAPI::Operation.new(
        method: "get",
        path: "/api/users/:id",
        summary: "Get user",
        responses: {
          "200" => Kemal::OpenAPI::Response.new(status_code: 200, description: "OK"),
        }
      )
    )

    builder = Kemal::OpenAPI::Builder.new
    json = JSON.parse(builder.to_json)
    json["paths"].as_h.has_key?("/api/users/{id}").should be_true
  end

  it "includes component schemas" do
    Kemal::OpenAPI.register_schema("User", Kemal::OpenAPI::Schema.new(
      type: "object",
      properties: {
        "id"   => Kemal::OpenAPI::Schema.new(type: "integer"),
        "name" => Kemal::OpenAPI::Schema.new(type: "string"),
      }
    ))

    builder = Kemal::OpenAPI::Builder.new
    json = JSON.parse(builder.to_json)
    json["components"]["schemas"]["User"]["type"].as_s.should eq("object")
    json["components"]["schemas"]["User"]["properties"]["id"]["type"].as_s.should eq("integer")
  end

  it "includes security schemes" do
    Kemal::OpenAPI.register_security_scheme("bearerAuth",
      Kemal::OpenAPI::SecurityScheme.new(
        type: "http",
        scheme: "bearer",
        bearer_format: "JWT"
      )
    )

    builder = Kemal::OpenAPI::Builder.new
    json = JSON.parse(builder.to_json)
    json["components"]["securitySchemes"]["bearerAuth"]["type"].as_s.should eq("http")
    json["components"]["securitySchemes"]["bearerAuth"]["scheme"].as_s.should eq("bearer")
  end

  it "includes servers" do
    builder = Kemal::OpenAPI::Builder.new
    builder.servers = [
      Kemal::OpenAPI::Server.new(url: "https://api.example.com", description: "Production"),
      Kemal::OpenAPI::Server.new(url: "http://localhost:3000", description: "Development"),
    ]

    json = JSON.parse(builder.to_json)
    json["servers"].as_a.size.should eq(2)
    json["servers"][0]["url"].as_s.should eq("https://api.example.com")
  end

  it "includes tags" do
    builder = Kemal::OpenAPI::Builder.new
    builder.tags = [
      Kemal::OpenAPI::Tag.new(name: "Users", description: "User management"),
      Kemal::OpenAPI::Tag.new(name: "Auth", description: "Authentication"),
    ]

    json = JSON.parse(builder.to_json)
    json["tags"].as_a.size.should eq(2)
    json["tags"][0]["name"].as_s.should eq("Users")
  end

  it "includes global security" do
    builder = Kemal::OpenAPI::Builder.new
    builder.global_security = [{"bearerAuth" => [] of String}]

    json = JSON.parse(builder.to_json)
    json["security"].as_a.size.should eq(1)
    json["security"][0]["bearerAuth"].as_a.should be_empty
  end
end
