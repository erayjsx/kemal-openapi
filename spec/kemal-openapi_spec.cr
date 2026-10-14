require "./spec_helper"
require "yaml"

describe Kemal::OpenAPI do
  it "keeps VERSION in sync with shard.yml" do
    shard = YAML.parse(File.read(File.join(__DIR__, "..", "shard.yml")))
    Kemal::OpenAPI::VERSION.should eq(shard["version"].as_s)
  end
end
