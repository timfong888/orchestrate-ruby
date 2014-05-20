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
    logger = Logger.new(STDOUT)
    config = Orchestrate::Configuration.new \
      api_key: "test-key",
      base_url: "test-url",
      logger: logger
    config.must_be_kind_of Orchestrate::Configuration
    config.api_key.must_equal "test-key"
    config.base_url.must_equal "test-url"
    config.logger.must_equal logger
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

  describe "#logger" do

    it "should default to a Logger instance that outputs to STDOUT" do
      @config.logger.must_be_kind_of Logger
      @config.logger.instance_variable_get("@logdev").dev.must_equal STDOUT
    end

    it "should be settable and gettable" do
      logger = Logger.new("/tmp/orchestrate-configuration-logger-test-#{rand}.log")
      @config.logger = logger
      @config.logger.must_equal logger
    end

  end

end
