require "./spec_helper"
require "log/spec"

@[OpenAPI(
  summary: "Profile",
  responses: {
      200 => {description: "OK", schema: {type: "object", required: ["name"]}},
    "4XX" => {description: "Client error", schema: {type: "object", required: ["error"]}},
  }
)]
get "/__responses/profile" do |env|
  case env.request.query_params["mode"]?
  when "bad"     then %({"nickname": "x"})
  when "missing" then env.response.status_code = 404; %({"msg": "nope"})
  else                %({"name": "Eray"})
  end
end

describe "response validation" do
  before_each do
    Kemal::OpenAPI.discover_operations(force: true)
  end

  after_each do
    Kemal::OpenAPI.validate_responses = false
  end

  it "is off by default" do
    Log.capture("kemal.openapi") do |logs|
      get "/__responses/profile?mode=bad", nil
      logs.empty
    end
    response.body.should eq(%({"nickname": "x"}))
  end

  it "logs responses that do not match their schema without changing them" do
    Kemal::OpenAPI.validate_responses = true
    Log.capture("kemal.openapi") do |logs|
      get "/__responses/profile?mode=bad", nil
      logs.check(:warn, /does not match its schema: Missing required field: name/)
    end
    response.status_code.should eq(200)
    response.body.should eq(%({"nickname": "x"}))
  end

  it "matches status code ranges" do
    Kemal::OpenAPI.validate_responses = true
    Log.capture("kemal.openapi") do |logs|
      get "/__responses/profile?mode=missing", nil
      logs.check(:warn, /\(404\) does not match its schema: Missing required field: error/)
    end
  end

  it "stays quiet for valid responses" do
    Kemal::OpenAPI.validate_responses = true
    Log.capture("kemal.openapi") do |logs|
      get "/__responses/profile", nil
      logs.empty
    end
  end
end
