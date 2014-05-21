require_relative '../../test_helper'

class ExceptionsTest < MiniTest::Unit::TestCase
  def setup
    @client, @stubs, @basic_auth = make_client_and_artifacts
  end

  def test_raises_on_unauthroized
    @stubs.get("/v0/foo") do |env|
      assert_authorization @basic_auth, env
      [ 401, response_headers, {
        "message" => "Valid credentials are required.",
        "code" => "security_unauthorized"
      }.to_json ]
    end
    assert_raises Orchestrate::Errors::Unauthorized do
      @client.list(:foo)
    end
  end
end

