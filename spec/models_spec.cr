require "./spec_helper"

describe Kemal::OpenAPI::Schema do
  it "generates basic type schema" do
    schema = Kemal::OpenAPI::Schema.new(type: "string")
    json = JSON.parse(JSON.build { |b| schema.to_json(b) })
    json["type"].as_s.should eq("string")
  end

  it "generates object schema with properties" do
    schema = Kemal::OpenAPI::Schema.new(
      type: "object",
      properties: {
        "name"  => Kemal::OpenAPI::Schema.new(type: "string"),
        "email" => Kemal::OpenAPI::Schema.new(type: "string", format: "email"),
        "age"   => Kemal::OpenAPI::Schema.new(type: "integer", format: "int32"),
      },
      required: ["name", "email"]
    )
    json = JSON.parse(JSON.build { |b| schema.to_json(b) })
    json["type"].as_s.should eq("object")
    json["properties"]["name"]["type"].as_s.should eq("string")
    json["properties"]["email"]["format"].as_s.should eq("email")
    json["required"].as_a.map(&.as_s).should eq(["name", "email"])
  end

  it "generates array schema" do
    schema = Kemal::OpenAPI::Schema.new(
      type: "array",
      items: Kemal::OpenAPI::Schema.new(type: "string")
    )
    json = JSON.parse(JSON.build { |b| schema.to_json(b) })
    json["type"].as_s.should eq("array")
    json["items"]["type"].as_s.should eq("string")
  end

  it "generates $ref schema" do
    schema = Kemal::OpenAPI::Schema.new(ref: "#/components/schemas/User")
    json = JSON.parse(JSON.build { |b| schema.to_json(b) })
    json["$ref"].as_s.should eq("#/components/schemas/User")
  end

  it "generates enum schema" do
    schema = Kemal::OpenAPI::Schema.new(
      type: "string",
      enum_values: ["active", "inactive", "banned"]
    )
    json = JSON.parse(JSON.build { |b| schema.to_json(b) })
    json["enum"].as_a.map(&.as_s).should eq(["active", "inactive", "banned"])
  end

  it "generates nullable schema" do
    schema = Kemal::OpenAPI::Schema.new(type: "string", nullable: true)
    json = JSON.parse(JSON.build { |b| schema.to_json(b) })
    json["nullable"].as_bool.should be_true
  end
end

describe Kemal::OpenAPI::Info do
  it "generates info object" do
    info = Kemal::OpenAPI::Info.new(
      title: "Test API",
      version: "2.0.0",
      description: "A test API"
    )
    json = JSON.parse(JSON.build { |b| info.to_json(b) })
    json["title"].as_s.should eq("Test API")
    json["version"].as_s.should eq("2.0.0")
    json["description"].as_s.should eq("A test API")
  end

  it "generates info with contact and license" do
    info = Kemal::OpenAPI::Info.new(
      title: "API",
      version: "1.0.0",
      contact: Kemal::OpenAPI::Contact.new(
        name: "Dev Team",
        email: "dev@example.com"
      ),
      license: Kemal::OpenAPI::License.new(
        name: "MIT",
        url: "https://opensource.org/licenses/MIT"
      )
    )
    json = JSON.parse(JSON.build { |b| info.to_json(b) })
    json["contact"]["name"].as_s.should eq("Dev Team")
    json["license"]["name"].as_s.should eq("MIT")
  end
end

describe Kemal::OpenAPI::Parameter do
  it "generates query parameter" do
    param = Kemal::OpenAPI::Parameter.new(
      name: "page",
      location: "query",
      description: "Page number",
      schema: Kemal::OpenAPI::Schema.new(type: "integer", format: "int32")
    )
    json = JSON.parse(JSON.build { |b| param.to_json(b) })
    json["name"].as_s.should eq("page")
    json["in"].as_s.should eq("query")
    json["required"].as_bool.should be_false
    json["schema"]["type"].as_s.should eq("integer")
  end

  it "auto-requires path parameters" do
    param = Kemal::OpenAPI::Parameter.new(
      name: "id",
      location: "path",
      schema: Kemal::OpenAPI::Schema.new(type: "integer")
    )
    param.required.should be_true
  end
end

describe Kemal::OpenAPI::Response do
  it "generates simple response" do
    resp = Kemal::OpenAPI::Response.new(
      status_code: 200,
      description: "Success"
    )
    json = JSON.parse(JSON.build { |b| resp.to_json(b) })
    json["description"].as_s.should eq("Success")
  end

  it "generates response with schema" do
    resp = Kemal::OpenAPI::Response.new(
      status_code: 200,
      description: "User list",
      schema: Kemal::OpenAPI::Schema.new(
        type: "array",
        items: Kemal::OpenAPI::Schema.new(ref: "#/components/schemas/User")
      )
    )
    json = JSON.parse(JSON.build { |b| resp.to_json(b) })
    json["content"]["application/json"]["schema"]["type"].as_s.should eq("array")
  end
end

describe Kemal::OpenAPI::Operation do
  it "generates full operation" do
    op = Kemal::OpenAPI::Operation.new(
      method: "get",
      path: "/api/users",
      summary: "List users",
      tags: ["Users"],
      parameters: [
        Kemal::OpenAPI::Parameter.new(
          name: "page",
          location: "query",
          schema: Kemal::OpenAPI::Schema.new(type: "integer")
        ),
      ],
      responses: {
        "200" => Kemal::OpenAPI::Response.new(status_code: 200, description: "OK"),
        "401" => Kemal::OpenAPI::Response.new(status_code: 401, description: "Unauthorized"),
      }
    )
    json = JSON.parse(JSON.build { |b| op.to_json(b) })
    json["summary"].as_s.should eq("List users")
    json["tags"].as_a.first.as_s.should eq("Users")
    json["parameters"].as_a.size.should eq(1)
    json["responses"]["200"]["description"].as_s.should eq("OK")
  end

  it "generates operation with request body" do
    op = Kemal::OpenAPI::Operation.new(
      method: "post",
      path: "/api/users",
      summary: "Create user",
      request_body: Kemal::OpenAPI::RequestBody.new(
        description: "User data",
        schema: Kemal::OpenAPI::Schema.new(
          type: "object",
          properties: {
            "name"  => Kemal::OpenAPI::Schema.new(type: "string"),
            "email" => Kemal::OpenAPI::Schema.new(type: "string"),
          }
        )
      ),
      responses: {
        "201" => Kemal::OpenAPI::Response.new(status_code: 201, description: "Created"),
      }
    )
    json = JSON.parse(JSON.build { |b| op.to_json(b) })
    json["requestBody"]["required"].as_bool.should be_true
    json["requestBody"]["content"]["application/json"]["schema"]["type"].as_s.should eq("object")
  end
end

describe Kemal::OpenAPI::SecurityScheme do
  it "generates bearer auth scheme" do
    scheme = Kemal::OpenAPI::SecurityScheme.new(
      type: "http",
      scheme: "bearer",
      bearer_format: "JWT"
    )
    json = JSON.parse(JSON.build { |b| scheme.to_json(b) })
    json["type"].as_s.should eq("http")
    json["scheme"].as_s.should eq("bearer")
    json["bearerFormat"].as_s.should eq("JWT")
  end

  it "generates API key scheme" do
    scheme = Kemal::OpenAPI::SecurityScheme.new(
      type: "apiKey",
      name: "X-API-Key",
      location: "header"
    )
    json = JSON.parse(JSON.build { |b| scheme.to_json(b) })
    json["type"].as_s.should eq("apiKey")
    json["name"].as_s.should eq("X-API-Key")
    json["in"].as_s.should eq("header")
  end
end

describe Kemal::OpenAPI::Tag do
  it "generates tag" do
    tag = Kemal::OpenAPI::Tag.new(name: "Users", description: "User operations")
    json = JSON.parse(JSON.build { |b| tag.to_json(b) })
    json["name"].as_s.should eq("Users")
    json["description"].as_s.should eq("User operations")
  end
end

describe Kemal::OpenAPI::Server do
  it "generates server" do
    server = Kemal::OpenAPI::Server.new(
      url: "https://api.example.com",
      description: "Production"
    )
    json = JSON.parse(JSON.build { |b| server.to_json(b) })
    json["url"].as_s.should eq("https://api.example.com")
    json["description"].as_s.should eq("Production")
  end
end
