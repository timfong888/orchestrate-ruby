require_relative '../../test_helper'

class EventTest < MiniTest::Unit::TestCase

  def setup
    @collection = 'tests'
    @key = 'instance'
    @client, @stubs, @basic_auth = make_client_and_artifacts
    @event_type = "commits"
    @time = Time.now
    @timestamp = (@time.to_f * 1000).to_i
    @ordinal = 5
  end

  def test_get_event
    ref = "12345"
    value = {"msg" => "hello"}
    path = { "collection" => @collection, "key" => @key, "type" => @event_type,
             "ref" => "\"#{ref}\"", "timestamp" => @timestamp, "ordinal" => @ordinal }
    body = { "path" => path, "value" => value, "timestamp" => @timestamp, "ordinal" => @ordinal }
    location = ["/v0", @collection, @key, "events", @event_type, @timestamp, @ordinal].join('/')
    @stubs.get(location) do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      headers = { "Etag" => "\"#{ref}\"" }
      [200, response_headers(headers), body.to_json]
    end

    response = @client.get_event(@collection, @key, @event_type, @timestamp, @ordinal)
    assert_equal 200, response.status
    assert_equal body, response.body
    assert_equal ref, response.ref
    # assert_equal location, response.location
    assert_equal Time.parse(response.headers['Date']), response.request_time
    assert_equal response.headers['X-Orchestrate-Req-Id'], response.request_id
  end

  def test_get_event_with_time
    time = Time.now
    ts = (time.getutc.to_f * 1000).to_i
    @stubs.get("/v0/#{@collection}/#{@key}/events/#{@event_type}/#{ts}/#{@ordinal}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      [ 200, response_headers, {}.to_json ]
    end

    response = @client.get_event(@collection, @key, @event_type, time, @ordinal)
    assert_equal 200, response.status
  end

  def test_get_event_with_datetime
    time = DateTime.now
    ts = (time.to_time.getutc.to_f * 1000).to_i
    @stubs.get("/v0/#{@collection}/#{@key}/events/#{@event_type}/#{ts}/#{@ordinal}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      [ 200, response_headers, {}.to_json ]
    end
    response = @client.get_event(@collection, @key, @event_type, time, @ordinal)
    assert_equal 200, response.status
  end

  def test_post_event_without_timestamp
    event = {"msg" => "hello"}
    ref = "12345"
    location = ["/v0",@collection,@key,'events',@event_type,@timestamp,@ordinal].join('/')
    @stubs.post("/v0/#{@collection}/#{@key}/events/#{@event_type}") do |env|
      assert_authorization @basic_auth, env
      assert_equal event.to_json, env.body
      headers = { "Etag" => "\"#{ref}\"", "Location" => location }
      [204, response_headers(headers), '']
    end

    response = @client.post_event(@collection, @key, @event_type, event)
    assert_equal 204, response.status
    assert_equal location, response.location
    assert_equal ref, response.ref
  end

  def test_post_event_with_timestamp
    event = {"msg" => "hello"}
    ref = "12345"
    location = ["/v0",@collection,@key,'events',@event_type,@timestamp,@ordinal].join('/')
    @stubs.post("/v0/#{@collection}/#{@key}/events/#{@event_type}/#{@timestamp}") do |env|
      assert_authorization @basic_auth, env
      assert_equal event.to_json, env.body
      headers = { "Etag" => "\"#{ref}\"", "Location" => location }
      [204, response_headers(headers), '']
    end

    response = @client.post_event(@collection, @key, @event_type, event, @time)
    assert_equal 204, response.status
    assert_equal location, response.location
    assert_equal ref, response.ref
  end

  def test_put_event_without_ref
    event = {"msg" => "hello"}
    ref = "12345"
    location = ["/v0",@collection,@key,'events',@event_type,@timestamp,@ordinal].join('/')
    @stubs.put("/v0/#{@collection}/#{@key}/events/#{@event_type}/#{@timestamp}/#{@ordinal}") do |env|
      assert_authorization @basic_auth, env
      assert_equal event.to_json, env.body
      headers = { "Etag" => "\"#{ref}\"", "Location" => location }
      [204, response_headers(headers), '']
    end
    response = @client.put_event(@collection, @key, @event_type, @time, @ordinal, event)
    assert_equal 204, response.status
    assert_equal location, response.location
    assert_equal ref, response.ref
  end

  def test_put_event_with_ref
    event = {"msg" => "hello"}
    ref = "12345"
    new_ref = "abcde"
    path = ['/v0', @collection, @key, 'events', @event_type, @timestamp, @ordinal]
    @stubs.put(path.join("/")) do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-Match', "\"#{ref}\"", env
      assert_equal event.to_json, env.body
      headers = { "Etag" => "\"#{new_ref}\"", "Location" => path.join('/') }
      [204, response_headers(headers), '']
    end
    response = @client.put_event(@collection, @key, @event_type, @time, @ordinal, event, ref)
    assert_equal 204, response.status
    assert_equal new_ref, response.ref
    assert_equal path.join('/'), response.location
  end

  def test_purge_event_without_ref
    path = ['v0', @collection, @key, 'events', @event_type, @timestamp, @ordinal]
    @stubs.delete(path.join("/")) do |env|
      assert_authorization @basic_auth, env
      assert_equal 'true', env.params['purge']
      [204, response_headers, '']
    end
    response = @client.purge_event(@collection, @key, @event_type, @time, @ordinal)
    assert_equal 204, response.status
    assert_equal response.headers['X-Orchestrate-Req-Id'], response.request_id
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
    response = @client.purge_event(@collection, @key, @event_type, @time, @ordinal, ref)
    assert_equal 204, response.status
    assert_equal response.headers['X-Orchestrate-Req-Id'], response.request_id
  end

  def test_list_events_without_timestamp
    body = { "results" => [{"path"=>{}, "value"=>{}, "timestamp"=>"", "ordinal"=>0}],
             "count" => 0, "next" => "__NEXT__" }
    @stubs.get("/v0/#{@collection}/#{@key}/events/#{@event_type}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      [200, response_headers, body.to_json]
    end

    response = @client.list_events(@collection, @key, @event_type)
    assert_equal 200, response.status
    assert_equal body, response.body
    assert_equal body['count'], response.count
    assert_equal body['results'], response.results
    assert_equal body['next'], response.next_link
  end

  def test_list_events_with_timestamp
    end_time = Time.now
    start_time = end_time - (24 * 3600)
    body = { "results" => [{"path"=>{}, "value"=>{}, "timestamp"=>"", "ordinal"=>0}],
             "count" => 1, "next" => "__NEXT__" }

    @stubs.get("/v0/#{@collection}/#{@key}/events/#{@event_type}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      assert_equal (start_time.to_f * 1000).to_i.to_s, env.params['startEvent']
      assert_equal (end_time.to_f * 1000).to_i.to_s, env.params['endEvent']
      assert_equal ['startEvent', 'endEvent'].sort, env.params.keys.sort
      [200, response_headers, body.to_json]
    end
    response = @client.list_events(@collection, @key, @event_type,
                { start: start_time, end: end_time })
    assert_equal 200, response.status
    assert_equal body, response.body
    assert_equal body['results'], response.results
    assert_equal body['count'], response.count
    assert_equal body['next'], response.next_link
    assert_nil response.prev_link
  end

end
