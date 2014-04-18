require_relative '../../test_helper'

class EventTest < MiniTest::Unit::TestCase

  def setup
    @collection = 'tests'
    @key = 'instance'
    @client, @stubs, @basic_auth = make_client_and_artifacts
  end

  def test_get_events
    event_type = "test_event"
    @stubs.get("/#{@collection}/#{@key}/events/#{event_type}") do |env|
      assert_equal @basic_auth, env.request_headers['Authorization']
      [200, response_headers, '{}']
    end

    response = @client.get_events({collection: @collection, key: @key, event_type: event_type})
    assert_equal 200, response.status
  end

end
