require "test_helper"

describe Orchestrate::Client do

  it "should initialize" do
    client = Orchestrate::Client.new
    client.must_be_kind_of Orchestrate::Client

    client.config.must_equal Orchestrate.config
  end

  it "should initialize with config" do
    config = Orchestrate::Configuration.new(api_key: "test-api-key")
    client = Orchestrate::Client.new(config)
    client.must_be_kind_of Orchestrate::Client
    client.config.must_equal config
  end

  it "handles parallel requests" do
    @client, @stubs = make_client_and_artifacts
    @stubs.get("/v0/foo") do |env|
      [ 200, response_headers, {}.to_json ]
    end
    @stubs.get("/v0/users/mattly") do |env|
      [ 200, response_headers, {}.to_json ]
    end
    responses = nil
    capture_warnings do
      responses = @client.in_parallel do |r|
        r[:list] = @client.list(:foo)
        r[:user] = @client.get(:users, "mattly")
      end
    end
    assert responses[:list]
    assert_equal 200, responses[:list].status
    assert responses[:user]
    assert_equal 200, responses[:user].status
  end

end
