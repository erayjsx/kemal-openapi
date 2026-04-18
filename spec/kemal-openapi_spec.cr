require "./spec_helper"

describe Kemal::OpenAPI do
  it "has a version" do
    Kemal::OpenAPI::VERSION.should eq("0.4.0")
  end
end
