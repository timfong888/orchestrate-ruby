require "test_helper"

class ApplicationTest < MiniTest::Unit::TestCase

  def test_instantianes_with_api_key
    stubs = Faraday::Adapter::Test::Stubs.new
    pinged = false
    stubs.get('/v0') do |env|
      pinged = true
      [200, response_headers, '']
    end

    app = Orchestrate::Application.new("api_key") do |conn|
      conn.adapter :test, stubs
    end

    assert_equal "api_key", app.api_key
    assert_kind_of Orchestrate::Client, app.client
    assert pinged, "API wasn't pinged"
  end

end
