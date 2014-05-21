require_relative '../../test_helper'

class EventTest < MiniTest::Unit::TestCase

  def setup
    @collection = 'tests'
    @key = 'instance'
    @client, @stubs, @basic_auth = make_client_and_artifacts
    @event_type = "commits"
    @timestamp = (Time.now.to_f * 1000).to_i
    @ordinal = 5
  end

  def test_get_event
    body = { "path" => {}, "value" => {"msg" => "hello"}, "timestamp" => @timestamp, "ordinal" => @ordinal }
    @stubs.get("/v0/#{@collection}/#{@key}/events/#{@event_type}/#{@timestamp}/#{@ordinal}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      [200, response_headers, body.to_json]
    end

    response = @client.get_event(@collection, @key, @event_type, @timestamp, @ordinal)
    assert_equal 200, response.status
    assert_equal body, response.body
  end

  def test_post_event_without_timestamp
    event = {"msg" => "hello"}
    @stubs.post("/v0/#{@collection}/#{@key}/events/#{@event_type}") do |env|
      assert_authorization @basic_auth, env
      assert_equal event.to_json, env.body
      [204, response_headers, '']
    end

    response = @client.post_event(@collection, @key, @event_type, event)
    assert_equal 204, response.status
  end

  def test_post_event_with_timestamp
    event = {"msg" => "hello"}
    @stubs.post("/v0/#{@collection}/#{@key}/events/#{@event_type}/#{@timestamp}") do |env|
      assert_authorization @basic_auth, env
      assert_equal event.to_json, env.body
      [204, response_headers, '']
    end

    response = @client.post_event(@collection, @key, @event_type, event, @timestamp)
    assert_equal 204, response.status
  end

  def test_put_event_without_ref
    event = {"msg" => "hello"}
    @stubs.put("/v0/#{@collection}/#{@key}/events/#{@event_type}/#{@timestamp}/#{@ordinal}") do |env|
      assert_authorization @basic_auth, env
      assert_equal event.to_json, env.body
      [204, response_headers, '']
    end
    response = @client.put_event(@collection, @key, @event_type, @timestamp, @ordinal, event)
    assert_equal 204, response.status
  end

  def test_put_event_with_ref
    event = {"msg" => "hello"}
    ref = "12345"
    path = ['v0', @collection, @key, 'events', @event_type, @timestamp, @ordinal]
    @stubs.put(path.join("/")) do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-Match', "\"#{ref}\"", env
      assert_equal event.to_json, env.body
      [204, response_headers, '']
    end
    response = @client.put_event(@collection, @key, @event_type, @timestamp, @ordinal, event, ref)
    assert_equal 204, response.status
  end

  def test_purge_event_without_ref
    path = ['v0', @collection, @key, 'events', @event_type, @timestamp, @ordinal]
    @stubs.delete(path.join("/")) do |env|
      assert_authorization @basic_auth, env
      assert_equal 'true', env.params['purge']
      [204, response_headers, '']
    end
    response = @client.purge_event(@collection, @key, @event_type, @timestamp, @ordinal)
    assert_equal 204, response.status
  end

  def test_purge_event_with_ref
    path = ['v0', @collection, @key, 'events', @event_type, @timestamp, @ordinal]
    ref = "12345"
    @stubs.delete(path.join("/")) do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-Match', "\"#{ref}\"", env
      assert_equal 'true', env.params['purge']
      [204, response_headers, '']
    end
    response = @client.purge_event(@collection, @key, @event_type, @timestamp, @ordinal, ref)
    assert_equal 204, response.status
  end

  def test_list_events_without_timestamp
    body = { "results" => [], "count" => 0, "next" => "" }
    @stubs.get("/v0/#{@collection}/#{@key}/events/#{@event_type}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      [200, response_headers, body.to_json]
    end

    response = @client.list_events(@collection, @key, @event_type)
    assert_equal 200, response.status
    assert_equal body, response.body
  end

  def test_list_events_with_timestamp
    end_time = Time.now
    start_time = end_time - (24 * 3600)
    body = { "results" => [], "count" => 0, "next" => "" }

    @stubs.get("/v0/#{@collection}/#{@key}/events/#{@event_type}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      assert_equal start_time.to_i.to_s, env.params['startEvent']
      assert_equal end_time.to_i.to_s, env.params['endEvent']
      assert_equal ['startEvent', 'endEvent'].sort, env.params.keys.sort
      [200, response_headers, body.to_json]
    end
    response = @client.list_events(@collection, @key, @event_type,
      { start: start_time.to_i, end: end_time.to_i }
    )
    assert_equal 200, response.status
    assert_equal body, response.body
  end

end
