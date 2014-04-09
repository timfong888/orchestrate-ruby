require_relative "../../test_helper"

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
      base_url: "test-url",
      verbose: true
    config.must_be_kind_of Orchestrate::Configuration
    config.api_key.must_equal "test-key"
    config.base_url.must_equal "test-url"
    config.verbose.must_equal true
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

    it "should default to 'https://api.orchestrate.io/v0'" do
      @config.base_url.must_equal "https://api.orchestrate.io/v0"
    end

    it "should be settable and gettable" do
      @config.base_url = "test-url"
      @config.base_url.must_equal "test-url"
    end

  end

  describe "#verbose" do

    it "should default to false" do
      @config.verbose.must_equal false
    end

    it "should be settable and gettable" do
      @config.verbose = true
      @config.verbose.must_equal true
    end

  end

end
