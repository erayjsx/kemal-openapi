require "./spec_helper"

@[OpenAPI(
  summary: "Get item",
  tags: ["Items"],
  parameters: [Kemal::OpenAPI.param("expand", type: "boolean")],
  security: ["bearerAuth"],
  responses: {
          200 => {description: "Item", schema: {type: "object"}},
    "default" => "Unexpected error",
  }
)]
get "/__macro/items/:id" do |env|
  env.params.url["id"]
end

@[OpenAPI(
  summary: "Create items",
  request_body: {
    schema: Kemal::OpenAPI.array_of(Kemal::OpenAPI::Schema.new(type: "string", min_length: 2)),
  },
  responses: {201 => "Created"}
)]
post "/__macro/items" do |ctx|
  ctx.response.status_code = 201
  "created"
end

@[OpenAPI(
  summary: "Upload",
  request_body: {content_type: "multipart/form-data", required: false},
  security: [{"oauth" => ["write"]}]
)]
put "/__macro/files/*path" do
  "uploaded"
end

private def spec_json : JSON::Any
  Kemal::OpenAPI.discover_operations(force: true)
  JSON.parse(Kemal::OpenAPI::Builder.new.to_json)
end

describe "@[OpenAPI] annotation" do
  before_each do
    Kemal::OpenAPI::OPERATIONS.clear
    Kemal::OpenAPI::OPERATIONS_MAP.clear
    Kemal::OpenAPI::SCHEMAS.clear
  end

  it "documents parameters, security and implicit path parameters" do
    op = spec_json["paths"]["/__macro/items/{id}"]["get"]

    params = op["parameters"].as_a
    params.map { |p| {p["name"].as_s, p["in"].as_s, p["required"].as_bool} }.should eq([
      {"expand", "query", false},
      {"id", "path", true},
    ])
    op["security"].should eq(JSON.parse(%([{"bearerAuth": []}])))
  end

  it "supports the default response and inline named tuple schemas" do
    responses = spec_json["paths"]["/__macro/items/{id}"]["get"]["responses"]
    responses["default"]["description"].should eq("Unexpected error")
    responses["200"]["content"]["application/json"]["schema"]["type"].should eq("object")
  end

  it "accepts schema expressions in request_body" do
    body = spec_json["paths"]["/__macro/items"]["post"]["requestBody"]
    body["required"].should eq(true)
    body["content"]["application/json"]["schema"]["items"]["minLength"].should eq(2)
  end

  it "converts glob routes and keeps custom content types" do
    op = spec_json["paths"]["/__macro/files/{path}"]["put"]
    op["requestBody"]["content"]["multipart/form-data"]?.should_not be_nil
    op["security"].should eq(JSON.parse(%([{"oauth": ["write"]}])))
    op["parameters"][0]["name"].should eq("path")
  end

  it "validates requests before running the route block" do
    Kemal::OpenAPI.discover_operations(force: true)
    headers = HTTP::Headers{"Content-Type" => "application/json"}

    post "/__macro/items", headers, %(["ok", "x"])
    response.status_code.should eq(422)
    JSON.parse(response.body)["errors"][0]["pointer"].should eq("/1")

    post "/__macro/items", headers, %(["ok", "fine"])
    response.status_code.should eq(201)
    response.body.should eq("created")
  end

  it "passes route params through to blocks with any argument name" do
    get "/__macro/items/42", nil
    response.body.should eq("42")

    put "/__macro/files/a/b.txt", HTTP::Headers{"Content-Type" => "multipart/form-data; boundary=x"}, "--x--"
    response.body.should eq("uploaded")
  end
end
