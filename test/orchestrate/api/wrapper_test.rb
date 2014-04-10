require "test_helper"

describe Orchestrate::API::Wrapper do

  before do
    @client = Orchestrate::API::Wrapper.new
  end

  it "should initialize" do
    client = Orchestrate::API::Wrapper.new
    client.must_be_kind_of Orchestrate::API::Wrapper
  end

  it "should initialize with config" do
    config = Orchestrate::Configuration.new \
      api_key: "test-api-key"
    client = Orchestrate::API::Wrapper.new(config)
    client.must_be_kind_of Orchestrate::API::Wrapper
    client.config.must_equal config
  end

end
