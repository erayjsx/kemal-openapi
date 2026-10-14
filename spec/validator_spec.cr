require "./spec_helper"

private def schema(**args)
  Kemal::OpenAPI::Schema.new(**args)
end

private def errors(json : String, s : Kemal::OpenAPI::Schema) : Array(String)
  Kemal::OpenAPI::Validator.errors_for(JSON.parse(json), s).map(&.to_s)
end

private def validate_request(path : String, body : String?, headers : HTTP::Headers? = nil) : {Bool, HTTP::Client::Response}
  request = HTTP::Request.new("POST", path, headers, body)
  io = IO::Memory.new
  server_response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, server_response)
  valid = Kemal::OpenAPI::Validator.validate(context, "POST", path)
  server_response.close
  io.rewind
  {valid, HTTP::Client::Response.from_io(io, decompress: false)}
end

private def register_body(path : String, body : Kemal::OpenAPI::RequestBody)
  Kemal::OpenAPI.register(
    Kemal::OpenAPI::Operation.new(method: "post", path: path, request_body: body)
  )
end

describe Kemal::OpenAPI::Validator do
  before_each do
    Kemal::OpenAPI::OPERATIONS.clear
    Kemal::OpenAPI::OPERATIONS_MAP.clear
    Kemal::OpenAPI::SCHEMAS.clear
  end

  describe ".errors_for" do
    it "checks types, including integers sent as whole floats" do
      errors(%("x"), schema(type: "integer")).should eq(["Expected integer, got string"])
      errors(%(3.0), schema(type: "integer")).should be_empty
      errors(%(3.5), schema(type: "integer")).should eq(["Expected integer, got number"])
      errors(%(3), schema(type: "number")).should be_empty
    end

    it "accepts null for nullable schemas" do
      errors(%(null), schema(type: "string", nullable: true)).should be_empty
      errors(%(null), schema(type: "string")).should eq(["Expected string, got null"])
    end

    it "validates enum values" do
      s = schema(type: "string", enum_values: ["admin", "user"])
      errors(%("admin"), s).should be_empty
      errors(%("root"), s).should eq(["Value must be one of: admin, user"])
    end

    it "validates string length and pattern" do
      s = schema(type: "string", min_length: 2, max_length: 4, pattern: "^[a-z]+$")
      errors(%("abc"), s).should be_empty
      errors(%("a"), s).should eq(["Must be at least 2 characters long"])
      errors(%("abcde"), s).should eq(["Must be at most 4 characters long"])
      errors(%("AB"), s).should eq(["Must match pattern ^[a-z]+$"])
    end

    it "counts characters, not bytes, for string length" do
      errors(%("çğü"), schema(type: "string", max_length: 3)).should be_empty
    end

    it "validates numeric bounds" do
      s = schema(type: "number", minimum: 1.0, maximum: 10.0, multiple_of: 0.5)
      errors(%(5.5), s).should be_empty
      errors(%(0), s).should eq(["Must be greater than or equal to 1"])
      errors(%(11), s).should eq(["Must be less than or equal to 10"])
      errors(%(5.2), s).should eq(["Must be a multiple of 0.5"])

      exclusive = schema(type: "integer", exclusive_minimum: 0.0, exclusive_maximum: 5.0)
      errors(%(0), exclusive).should eq(["Must be greater than 0"])
      errors(%(5), exclusive).should eq(["Must be less than 5"])
    end

    it "validates arrays and reports item pointers" do
      s = schema(type: "array", items: schema(type: "integer"), min_items: 1, max_items: 3, unique_items: true)
      errors(%([1, 2]), s).should be_empty
      errors(%([]), s).should eq(["Must contain at least 1 items"])
      errors(%([1, 2, 3, 4]), s).should eq(["Must contain at most 3 items"])
      errors(%([1, 1]), s).should eq(["Items must be unique"])
      errors(%([1, "x"]), s).should eq(["/1: Expected integer, got string"])
    end

    it "validates objects with nested pointers and collects every error" do
      s = schema(
        type: "object",
        required: ["name", "email"],
        properties: {
          "name"    => schema(type: "string"),
          "email"   => schema(type: "string"),
          "address" => schema(type: "object", properties: {"zip" => schema(type: "string")}),
        }
      )
      errors(%({"name": 1, "address": {"zip": 34000}}), s).should eq([
        "Missing required field: email",
        "/name: Expected string, got integer",
        "/address/zip: Expected string, got integer",
      ])
    end

    it "does not require readOnly properties" do
      s = schema(
        type: "object",
        required: ["id", "name"],
        properties: {
          "id"   => schema(type: "integer", read_only: true),
          "name" => schema(type: "string"),
        }
      )
      errors(%({"name": "Eray"}), s).should be_empty
    end

    it "enforces additionalProperties" do
      closed = schema(type: "object", properties: {"a" => schema(type: "string")}, additional_properties: false)
      errors(%({"a": "x", "b": 1}), closed).should eq(["/b: Unknown field: b"])

      typed = schema(type: "object", additional_properties: schema(type: "integer"))
      errors(%({"a": 1, "b": "x"}), typed).should eq(["/b: Expected integer, got string"])
    end

    it "supports oneOf without an explicit type" do
      s = schema(one_of: [schema(type: "string"), schema(type: "integer")])
      errors(%("text"), s).should be_empty
      errors(%(42), s).should be_empty
      errors(%(true), s).should eq(["Value must match exactly one schema (oneOf), matched none"])

      overlapping = schema(one_of: [schema(type: "number"), schema(type: "integer")])
      errors(%(1), overlapping).should eq(["Value must match exactly one schema (oneOf), matched 2"])
    end

    it "supports anyOf and allOf" do
      any = schema(any_of: [schema(type: "string"), schema(type: "boolean")])
      errors(%(true), any).should be_empty
      errors(%(1), any).should eq(["Value does not match any of the allowed schemas (anyOf)"])

      all = schema(all_of: [
        schema(type: "object", required: ["a"]),
        schema(type: "object", required: ["b"]),
      ])
      errors(%({"a": 1, "b": 2}), all).should be_empty
      errors(%({"a": 1}), all).should eq(["Missing required field: b"])
    end

    it "resolves $ref schemas" do
      Kemal::OpenAPI.register_schema("Name", schema(type: "string", min_length: 2))
      errors(%({"name": "x"}), schema(type: "object", properties: {"name" => Kemal::OpenAPI.ref("Name")}))
        .should eq(["/name: Must be at least 2 characters long"])
    end

    it "escapes JSON pointer segments" do
      s = schema(type: "object", properties: {"a/b" => schema(type: "string")})
      errors(%({"a/b": 1}), s).should eq(["/a~1b: Expected string, got integer"])
    end
  end

  describe ".validate" do
    it "returns all errors in the response body" do
      register_body("/__v_errors", Kemal::OpenAPI::RequestBody.new(
        schema: schema(
          type: "object",
          required: ["name"],
          properties: {"role" => schema(type: "string", enum_values: ["admin"])}
        )
      ))

      valid, response = validate_request("/__v_errors", %({"role": "root"}))
      valid.should be_false
      response.status_code.should eq(422)
      body = JSON.parse(response.body)
      body["error"].should eq("validation_error")
      body["message"].should eq("Missing required field: name")
      body["errors"].as_a.map(&.["pointer"].as_s).should eq(["", "/role"])
    end

    it "keeps the body readable for the route handler" do
      register_body("/__v_body", Kemal::OpenAPI::RequestBody.new(schema: schema(type: "object")))

      request = HTTP::Request.new("POST", "/__v_body", body: %({"a": 1}))
      context = HTTP::Server::Context.new(request, HTTP::Server::Response.new(IO::Memory.new))
      Kemal::OpenAPI::Validator.validate(context, "POST", "/__v_body").should be_true
      context.request.body.not_nil!.gets_to_end.should eq(%({"a": 1}))
    end

    it "rejects invalid JSON and missing required bodies with 400" do
      register_body("/__v_400", Kemal::OpenAPI::RequestBody.new(schema: schema(type: "object")))

      _, response = validate_request("/__v_400", "{oops")
      response.status_code.should eq(400)

      _, response = validate_request("/__v_400", nil)
      response.status_code.should eq(400)
      JSON.parse(response.body)["message"].should eq("Request body is required")
    end

    it "allows a missing optional body" do
      register_body("/__v_optional", Kemal::OpenAPI::RequestBody.new(schema: schema(type: "object"), required: false))
      valid, _ = validate_request("/__v_optional", nil)
      valid.should be_true
    end

    it "does not parse non-JSON request bodies" do
      register_body("/__v_form", Kemal::OpenAPI::RequestBody.new(content_type: "multipart/form-data"))
      valid, _ = validate_request("/__v_form", "--boundary\r\n")
      valid.should be_true
    end

    it "accepts +json media types" do
      register_body("/__v_vendor", Kemal::OpenAPI::RequestBody.new(
        content_type: "application/vnd.api+json",
        schema: schema(type: "object")
      ))
      headers = HTTP::Headers{"Content-Type" => "application/vnd.api+json; charset=utf-8"}
      valid, _ = validate_request("/__v_vendor", %({}), headers)
      valid.should be_true
    end

    it "rejects a non-JSON Content-Type with 415" do
      register_body("/__v_415", Kemal::OpenAPI::RequestBody.new(schema: schema(type: "object")))
      headers = HTTP::Headers{"Content-Type" => "text/plain"}
      valid, response = validate_request("/__v_415", %({}), headers)
      valid.should be_false
      response.status_code.should eq(415)
    end

    it "rejects bodies larger than Kemal's max_request_body_size with 413" do
      register_body("/__v_413", Kemal::OpenAPI::RequestBody.new(schema: schema(type: "string")))
      original = Kemal.config.max_request_body_size
      begin
        Kemal.config.max_request_body_size = 8
        valid, response = validate_request("/__v_413", %("0123456789"))
        valid.should be_false
        response.status_code.should eq(413)
      ensure
        Kemal.config.max_request_body_size = original
      end
    end
  end
end
