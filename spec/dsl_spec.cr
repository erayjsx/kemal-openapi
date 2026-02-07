require "./spec_helper"

describe "Kemal::OpenAPI DSL helpers" do
  before_each do
    Kemal::OpenAPI::OPERATIONS.clear
    Kemal::OpenAPI::SCHEMAS.clear
    Kemal::OpenAPI::SECURITY_SCHEMES.clear
  end

  describe ".ref" do
    it "creates a $ref schema" do
      schema = Kemal::OpenAPI.ref("User")
      json = JSON.parse(JSON.build { |b| schema.to_json(b) })
      json["$ref"].as_s.should eq("#/components/schemas/User")
    end
  end

  describe ".array_of" do
    it "creates array schema from schema" do
      item = Kemal::OpenAPI::Schema.new(type: "string")
      schema = Kemal::OpenAPI.array_of(item)
      json = JSON.parse(JSON.build { |b| schema.to_json(b) })
      json["type"].as_s.should eq("array")
      json["items"]["type"].as_s.should eq("string")
    end

    it "creates array schema from ref name" do
      schema = Kemal::OpenAPI.array_of("User")
      json = JSON.parse(JSON.build { |b| schema.to_json(b) })
      json["type"].as_s.should eq("array")
      json["items"]["$ref"].as_s.should eq("#/components/schemas/User")
    end
  end

  describe ".param" do
    it "creates a query parameter" do
      param = Kemal::OpenAPI.param("page", type: "integer", description: "Page number")
      json = JSON.parse(JSON.build { |b| param.to_json(b) })
      json["name"].as_s.should eq("page")
      json["in"].as_s.should eq("query")
      json["required"].as_bool.should be_false
      json["schema"]["type"].as_s.should eq("integer")
    end

    it "auto-requires path parameters" do
      param = Kemal::OpenAPI.param("id", location: "path", type: "integer")
      param.required.should be_true
    end
  end

  describe ".responses" do
    it "builds responses from hash" do
      resps = Kemal::OpenAPI.responses({200 => "OK", 404 => "Not Found"})
      resps.size.should eq(2)
      resps["200"].description.should eq("OK")
      resps["404"].description.should eq("Not Found")
    end
  end

  describe ".bearer_auth" do
    it "creates bearer security scheme" do
      scheme = Kemal::OpenAPI.bearer_auth
      json = JSON.parse(JSON.build { |b| scheme.to_json(b) })
      json["type"].as_s.should eq("http")
      json["scheme"].as_s.should eq("bearer")
      json["bearerFormat"].as_s.should eq("JWT")
    end
  end

  describe ".api_key_auth" do
    it "creates API key security scheme" do
      scheme = Kemal::OpenAPI.api_key_auth(name: "X-Token", location: "header")
      json = JSON.parse(JSON.build { |b| scheme.to_json(b) })
      json["type"].as_s.should eq("apiKey")
      json["name"].as_s.should eq("X-Token")
      json["in"].as_s.should eq("header")
    end
  end
end
