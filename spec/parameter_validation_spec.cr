require "./spec_helper"

@[OpenAPI(
  summary: "Search",
  parameters: [
    Kemal::OpenAPI.param("page", type: "integer", required: true),
    Kemal::OpenAPI::Parameter.new(name: "limit", schema: Kemal::OpenAPI::Schema.new(type: "integer", minimum: 1.0, maximum: 50.0)),
    Kemal::OpenAPI::Parameter.new(name: "tags", schema: Kemal::OpenAPI::Schema.new(type: "array", items: Kemal::OpenAPI::Schema.new(type: "string", enum_values: ["a", "b"]))),
    Kemal::OpenAPI.param("active", type: "boolean"),
    Kemal::OpenAPI.param("X-Request-Id", location: "header", required: true),
    Kemal::OpenAPI.param("session", location: "cookie"),
  ]
)]
get "/__params/search" do |_|
  "ok"
end

@[OpenAPI(
  summary: "Item",
  parameters: [Kemal::OpenAPI.param("id", location: "path", type: "integer")]
)]
get "/__params/items/:id" do |env|
  "item #{env.params.url["id"]}"
end

private def search(query : String, headers = HTTP::Headers{"X-Request-Id" => "1"})
  get "/__params/search?#{query}", headers
  response
end

private def error_pointers(response) : Array(String)
  JSON.parse(response.body)["errors"].as_a.map { |e| "#{e["in"]}:#{e["pointer"]}" }
end

describe "parameter validation" do
  before_each do
    Kemal::OpenAPI.discover_operations(force: true)
  end

  it "accepts valid parameters" do
    search("page=2&limit=10&tags=a&tags=b&active=true").status_code.should eq(200)
  end

  it "accepts comma separated arrays" do
    search("page=1&tags=a,b").status_code.should eq(200)
  end

  it "rejects values that are not of the documented type" do
    res = search("page=abc")
    res.status_code.should eq(422)
    JSON.parse(res.body)["message"].should eq(%(query parameter 'page': Expected integer, got "abc"))
  end

  it "applies schema constraints after coercion" do
    res = search("page=1&limit=99&tags=c&active=yes")
    res.status_code.should eq(422)
    error_pointers(res).should eq(["query:limit", "query:tags", "query:active"])
  end

  it "requires required query and header parameters" do
    res = search("", HTTP::Headers.new)
    res.status_code.should eq(422)
    error_pointers(res).should eq(["query:page", "header:X-Request-Id"])
  end

  it "validates path parameters" do
    get "/__params/items/42", nil
    response.body.should eq("item 42")

    get "/__params/items/abc", nil
    response.status_code.should eq(422)
    error_pointers(response).should eq(["path:id"])
  end
end
