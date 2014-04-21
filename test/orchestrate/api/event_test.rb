require_relative '../../test_helper'

class EventTest < MiniTest::Unit::TestCase

  def setup
    @collection = 'tests'
    @key = 'instance'
    @client, @stubs, @basic_auth = make_client_and_artifacts
    @event_type = "commits"
  end

  def test_get_events_without_timestamp
    @stubs.get("/#{@collection}/#{@key}/events/#{@event_type}") do |env|
      assert_authorization @basic_auth, env
      [200, response_headers, '{}']
    end

    response = @client.get_events({collection: @collection, key: @key, event_type: @event_type})
    assert_equal 200, response.status
  end

  def test_get_events_with_timestamp
    end_time = Time.now
    start_time = end_time - (24 * 3600)
    @stubs.get("/#{@collection}/#{@key}/events/#{@event_type}") do |env|
      assert_authorization @basic_auth, env
      assert_equal start_time.to_i.to_s, env.params['start']
      assert_equal end_time.to_i.to_s, env.params['end']
      [200, response_headers, '{}']
    end
    response = @client.get_events({
      collection: @collection, key: @key, event_type: @event_type,
      timestamp: { start: start_time.to_i, end: end_time.to_i }
    })
    assert_equal 200, response.status
  end

end
