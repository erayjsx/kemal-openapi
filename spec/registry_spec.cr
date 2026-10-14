require "./spec_helper"

private def op(method, path, **args)
  Kemal::OpenAPI::Operation.new(**args, method: method, path: path)
end

describe Kemal::OpenAPI::Registry do
  it "replaces operations with the same method and path" do
    registry = Kemal::OpenAPI::Registry.new
    registry.register(op("get", "/a", summary: "first"))
    registry.register(op("GET", "/a", summary: "second"))

    registry.operations.size.should eq(1)
    registry.operation("get", "/a").not_nil!.summary.should eq("second")
  end

  it "bumps its version on every change" do
    registry = Kemal::OpenAPI::Registry.new
    before = registry.version
    registry.register_schema("A", Kemal::OpenAPI::Schema.new)
    registry.version.should be > before
  end

  it "keeps separate registries independent" do
    admin = Kemal::OpenAPI::Registry.new
    admin.register(op("get", "/admin/stats"))
    admin.register_schema("Stats", Kemal::OpenAPI::Schema.new(type: "object"))

    spec = JSON.parse(Kemal::OpenAPI::Builder.new(registry: admin).to_json)
    spec["paths"].as_h.keys.should eq(["/admin/stats"])
    spec["components"]["schemas"].as_h.keys.should eq(["Stats"])
    Kemal::OpenAPI.registry.operation("get", "/admin/stats").should be_nil
  end

  it "validates against a custom registry" do
    admin = Kemal::OpenAPI::Registry.new
    admin.register(op("post", "/admin/x", request_body: Kemal::OpenAPI::RequestBody.new(schema: Kemal::OpenAPI::Schema.new(type: "object"))))

    request = HTTP::Request.new("POST", "/admin/x", body: "[]")
    context = HTTP::Server::Context.new(request, HTTP::Server::Response.new(IO::Memory.new))
    Kemal::OpenAPI::Validator.validate(context, "POST", "/admin/x", registry: admin).should be_false
  end

  it "keeps the legacy constants pointing at the default registry" do
    Kemal::OpenAPI::OPERATIONS.should be(Kemal::OpenAPI.registry.operations)
    Kemal::OpenAPI::SCHEMAS.should be(Kemal::OpenAPI.registry.schemas)
  end

  it "rebuilds the cached spec when the registry changes" do
    registry = Kemal::OpenAPI::Registry.new
    handler = Kemal::OpenAPI::Handler.new(builder: Kemal::OpenAPI::Builder.new(registry: registry))

    handler.spec_json.should_not contain("/later")
    registry.register(op("get", "/later"))
    handler.spec_json.should contain("/later")
  end
end

describe Kemal::OpenAPI::Builder do
  it "generates unique operationIds" do
    registry = Kemal::OpenAPI::Registry.new
    registry.register(op("get", "/users/:id/posts"))
    registry.register(op("post", "/users", operation_id: "getUsersByIdPosts"))
    registry.register(op("delete", "/files/*path"))

    paths = JSON.parse(Kemal::OpenAPI::Builder.new(registry: registry).to_json)["paths"]
    paths["/users/{id}/posts"]["get"]["operationId"].should eq("getUsersByIdPosts2")
    paths["/users"]["post"]["operationId"].should eq("getUsersByIdPosts")
    paths["/files/{path}"]["delete"]["operationId"].should eq("deleteFilesByPath")
  end

  it "can turn off generated operationIds" do
    registry = Kemal::OpenAPI::Registry.new
    registry.register(op("get", "/a"))
    builder = Kemal::OpenAPI::Builder.new(registry: registry, auto_operation_ids: false)
    JSON.parse(builder.to_json)["paths"]["/a"]["get"]["operationId"]?.should be_nil
  end

  it "derives operationIds from kebab and snake case paths" do
    Kemal::OpenAPI::Builder.operation_id_for("GET", "/user-groups/:group_id").should eq("getUserGroupsByGroupId")
    Kemal::OpenAPI::Builder.operation_id_for("get", "/").should eq("get")
  end

  it "writes the spec to a file" do
    registry = Kemal::OpenAPI::Registry.new
    registry.register(op("get", "/written"))
    path = File.tempname("openapi", ".json")
    begin
      Kemal::OpenAPI::Builder.new(registry: registry).write(path)
      JSON.parse(File.read(path))["paths"]["/written"]?.should_not be_nil
    ensure
      File.delete?(path)
    end
  end
end
