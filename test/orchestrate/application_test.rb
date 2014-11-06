require "test_helper"

class ApplicationTest < MiniTest::Unit::TestCase

  def test_instantianes_with_api_key
    stubs = Faraday::Adapter::Test::Stubs.new
    pinged = false
    stubs.head('/v0') do |env|
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

  def test_instantianes_with_api_key_and_host
    stubs = Faraday::Adapter::Test::Stubs.new
    pinged = false
    stubs.head('/v0') do |env|
      pinged = true
      [200, response_headers, '']
    end
    host = "https://example.com"
    app = Orchestrate::Application.new("api_key", host) do |conn|
      conn.adapter :test, stubs
    end

    assert_equal host, app.host
    assert_equal "api_key", app.api_key
    assert_kind_of Orchestrate::Client, app.client
    assert pinged, "API wasn't pinged"
  end

  def test_instantiates_with_client
    client, stubs = make_client_and_artifacts
    pinged = false
    stubs.head('/v0') do |env|
      pinged = true
      [ 200, response_headers, '' ]
    end

    app = Orchestrate::Application.new(client)
    assert_equal client.api_key, app.api_key
    assert_equal client, app.client
    assert pinged, "API wasn't pinged"
  end

  def test_instantiates_with_client_and_host
    client, stubs = make_client_and_artifacts
    pinged = false
    stubs.head('/v0') do |env|
      pinged = true
      [ 200, response_headers, '' ]
    end
    host = 'https://example.com'
    app = Orchestrate::Application.new(client, host)
    assert_equal client.host, app.host
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

  def dup_generates_new_client
    client, stubs = make_client_and_artifacts
    app = Orchestrate::Application.new(client)
    duped_app = app.dup
    assert_equal app.api_key, duped_app.api_key
    assert_equal client.faraday_configuration, duped_app.client.faraday_configuration
    refute_equal client.object_id, duped_app.client.object_id
    refute_equal client.http.object_id, duped_app.client.http.object_id
  end

end
