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

  def test_instantiates_with_client
    client, stubs = make_client_and_artifacts
    pinged = false
    stubs.get('/v0') do |env|
      pinged = true
      [ 200, response_headers, '' ]
    end

    app = Orchestrate::Application.new(client)
    assert_equal client.api_key, app.api_key
    assert_equal client, app.client
    assert pinged, "API wasn't pinged"
  end

  def test_collection_accessor
    app, stubs = make_application
    users = app[:users]
    assert_kind_of Orchestrate::Collection, users
    assert_equal app, users.app
    assert_equal 'users', users.name
  end

end
