require_relative '../../test_helper'

class EventTest < MiniTest::Unit::TestCase

  def setup
    @collection = 'tests'
    @key = 'instance'
    @api_key = 'foo-bar-bee-baz'
    @basic_auth = "Basic #{Base64.encode64("#{@api_key}:").sub(/\n$/,'')}"
    @stubs = Faraday::Adapter::Test::Stubs.new
    Orchestrate.configure do |config|
      config.faraday_adapter = [:test, @stubs]
      config.api_key = @api_key
    end
    @client = Orchestrate::Client.new
  end

  def test_get_events
    event_type = "test_event"
    @stubs.get("/#{@collection}/#{@key}/events/#{event_type}") do |env|
      assert_equal @basic_auth, env.request_headers['Authorization']
      [200, {}, 'egg']
    end

    response = @client.get_events({collection: @collection, key: @key, event_type: event_type})
    assert_equal 200, response.status
  end

end
