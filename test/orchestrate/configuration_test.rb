require "test_helper"

describe Orchestrate::Configuration do

  before do
    @config = Orchestrate::Configuration.new
  end

  it "should initialize" do
    config = Orchestrate::Configuration.new
    config.must_be_kind_of Orchestrate::Configuration
  end

  it "should initialize with arguments" do
    config = Orchestrate::Configuration.new \
      api_key: "test-key",
      base_url: "test-url"
    config.must_be_kind_of Orchestrate::Configuration
    config.api_key.must_equal "test-key"
    config.base_url.must_equal "test-url"
  end

  describe "#api_key" do

    it "should not have a default value" do
      @config.api_key.must_be_nil
    end

    it "should be settable and gettable" do
      @config.api_key = "test-key"
      @config.api_key.must_equal "test-key"
    end

  end

  describe "#base_url" do

    it "should default to 'https://api.orchestrate.io'" do
      @config.base_url.must_equal "https://api.orchestrate.io"
    end

    it "should be settable and gettable" do
      @config.base_url = "test-url"
      @config.base_url.must_equal "test-url"
    end

  end

end
