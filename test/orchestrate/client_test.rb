require "test_helper"

describe Orchestrate::Client do

  it "should initialize" do
    client = Orchestrate::Client.new
    client.must_be_kind_of Orchestrate::Client
  end

  it "should initialize with config" do
    config = Orchestrate::Configuration.new(api_key: "test-api-key")
    client = Orchestrate::Client.new(config)
    client.must_be_kind_of Orchestrate::Client
    client.config.must_equal config
  end

end
