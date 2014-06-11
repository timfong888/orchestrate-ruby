require "test_helper"

describe Orchestrate::Client do

  it "should initialize" do
    client = Orchestrate::Client.new('8c3')
    client.must_be_kind_of Orchestrate::Client
  end

  it "handles parallel requests" do
    client, stubs = make_client_and_artifacts
    stubs.get("/v0/foo") do |env|
      [ 200, response_headers, {}.to_json ]
    end
    stubs.get("/v0/users/mattly") do |env|
      [ 200, response_headers, {}.to_json ]
    end
    responses = nil
    capture_warnings do
      responses = client.in_parallel do |r|
        r[:list] = client.list(:foo)
        r[:user] = client.get(:users, "mattly")
      end
    end
    assert responses[:list]
    assert_equal 200, responses[:list].status
    assert responses[:user]
    assert_equal 200, responses[:user].status
  end

  it "handles ping request" do
    client, stubs = make_client_and_artifacts
    stubs.get("/v0") do |env|
      [ 200, response_headers, '' ]
    end
    client.ping
  end

end
