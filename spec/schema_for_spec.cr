require "./spec_helper"
require "uuid"
require "uuid/json"

enum SchemaForRole
  Admin
  SuperUser
end

class SchemaForAddress
  include JSON::Serializable
  property city : String
end

class SchemaForNode
  include JSON::Serializable
  property name : String
  property children : Array(SchemaForNode) = [] of SchemaForNode
end

class SchemaForUser
  include JSON::Serializable

  property id : Int64
  property age : Int32
  property score : Float64
  property active : Bool
  property nickname : String?
  property role : SchemaForRole
  property tags : Array(String)
  property scores : Hash(String, Int32)
  property address : SchemaForAddress
  property created_at : Time
  property external_id : UUID
  property metadata : JSON::Any
  property counter : UInt32 = 0_u32
  property value : String | Int32

  @[JSON::Field(key: "displayName")]
  property display_name : String

  @[JSON::Field(ignore: true)]
  property secret : String = ""
end

private def schema_json(schema : Kemal::OpenAPI::Schema) : JSON::Any
  JSON.parse(JSON.build { |b| schema.to_json(b) })
end

describe "Kemal::OpenAPI.schema_for" do
  json = schema_json(Kemal::OpenAPI.schema_for(SchemaForUser))
  props = json["properties"]

  it "maps scalar types" do
    props["id"].should eq(JSON.parse(%({"type": "integer", "format": "int64"})))
    props["age"].should eq(JSON.parse(%({"type": "integer", "format": "int32"})))
    props["score"].should eq(JSON.parse(%({"type": "number", "format": "double"})))
    props["active"]["type"].should eq("boolean")
    props["created_at"].should eq(JSON.parse(%({"type": "string", "format": "date-time"})))
    props["external_id"].should eq(JSON.parse(%({"type": "string", "format": "uuid"})))
    props["counter"]["minimum"].should eq(0)
  end

  it "marks nilable fields as nullable and optional" do
    props["nickname"]["type"].should eq(JSON.parse(%(["string", "null"])))
    json["required"].as_a.should_not contain("nickname")
  end

  it "treats fields with default values as optional" do
    json["required"].as_a.should_not contain("counter")
    json["required"].as_a.should contain("id")
  end

  it "maps enums to their serialized names" do
    props["role"]["enum"].should eq(JSON.parse(%(["admin", "super_user"])))
  end

  it "maps arrays and hashes with their element types" do
    props["tags"].should eq(JSON.parse(%({"type": "array", "items": {"type": "string"}})))
    props["scores"]["additionalProperties"]["type"].should eq("integer")
  end

  it "inlines nested serializable types" do
    props["address"]["properties"]["city"]["type"].should eq("string")
    props["address"]["required"].should eq(JSON.parse(%(["city"])))
  end

  it "maps unions to anyOf" do
    props["value"]["anyOf"].as_a.map(&.["type"].as_s).sort!.should eq(["integer", "string"])
    props["value"]["type"]?.should be_nil
  end

  it "accepts any value for JSON::Any" do
    props["metadata"]["type"].as_a.size.should eq(6)
  end

  it "honours JSON::Field key and ignore" do
    props["displayName"]["type"].should eq("string")
    props["display_name"]?.should be_nil
    props["secret"]?.should be_nil
  end

  it "stops expanding recursive types" do
    node = schema_json(Kemal::OpenAPI.schema_for(SchemaForNode))
    node["properties"]["children"]["items"]["properties"]["name"]["type"].should eq("string")
  end

  it "produces a schema that validates real payloads" do
    schema = Kemal::OpenAPI.schema_for(SchemaForAddress)
    Kemal::OpenAPI::Validator.errors_for(JSON.parse(%({"city": "Izmir"})), schema).should be_empty
    Kemal::OpenAPI::Validator.errors_for(JSON.parse(%({})), schema).map(&.to_s)
      .should eq(["Missing required field: city"])
  end
end

class RefTeam
  include JSON::Serializable
  property name : String
  property lead : RefMember
  property members : Array(RefMember)
  property parent : RefTeam?
end

class RefMember
  include JSON::Serializable
  property email : String
end

describe "Kemal::OpenAPI.register_schema_for" do
  it "registers nested types as components and references them" do
    registry = Kemal::OpenAPI::Registry.new
    ref = Kemal::OpenAPI.register_schema_for(RefTeam, registry: registry)
    ref.ref.should eq("#/components/schemas/RefTeam")

    schemas = JSON.parse(Kemal::OpenAPI::Builder.new(registry: registry).to_json)["components"]["schemas"]
    schemas.as_h.keys.sort!.should eq(["RefMember", "RefTeam"])

    team = schemas["RefTeam"]["properties"]
    team["lead"]["$ref"].should eq("#/components/schemas/RefMember")
    team["members"]["items"]["$ref"].should eq("#/components/schemas/RefMember")
    team["parent"]["anyOf"].should eq(JSON.parse(%([{"$ref": "#/components/schemas/RefTeam"}, {"type": "null"}])))
  end

  it "validates data through the registered references" do
    registry = Kemal::OpenAPI::Registry.new
    ref = Kemal::OpenAPI.register_schema_for(RefTeam, registry: registry)
    payload = JSON.parse(%({"name": "core", "lead": {"email": "a@b.c"}, "members": [{}], "parent": null}))
    Kemal::OpenAPI::Validator.errors_for(payload, ref, registry).map(&.to_s)
      .should eq(["/members/0: Missing required field: email"])
  end

  it "accepts a custom name" do
    registry = Kemal::OpenAPI::Registry.new
    Kemal::OpenAPI.register_schema_for(RefMember, "Member", registry).ref.should eq("#/components/schemas/Member")
  end
end
