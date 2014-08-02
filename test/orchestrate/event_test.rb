require "test_helper"

class EventTest < MiniTest::Unit::TestCase

  def setup
    @app, @stubs = make_application
    @kv = make_kv_item(@app[:items], @stubs)
    @body = {"place" => 'Home'}
    @time = Time.now
    @timestamp = (@time.to_f * 1000).to_i
    @ord = 6
    @type = 'checkins'
    @ref = nil
  end

  def make_event
    @stubs.get("/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}") do
      @ref = make_ref
      body = {value: @body, timestamp: @timestamp, ordinal: @ord}
      [200, response_headers({"Etag" => %|"#{@ref}"|}), body.to_json]
    end
    @kv.events[@type][@timestamp][@ord]
  end

  def assert_event_data(event)
    assert_kind_of Orchestrate::Event, event
    assert_equal @kv.key, event.key_name
    assert_equal @kv, event.key
    assert_equal @type, event.type_name
    assert_equal @kv.events[:checkins], event.type
    assert_equal @ref, event.ref
    assert_kind_of Time, event.time
    assert_in_delta @time.to_f, event.time.to_f, 1.1
    assert_equal @timestamp, event.timestamp
    assert_equal @ord, event.ordinal
    assert_equal "/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}", event.path
    assert_equal @body, event.value
    @body.each do |key, value|
      assert_equal value, event[key]
    end
    assert_in_delta Time.now.to_f, event.last_request_time.to_f, 1.1
  end

  def test_creates_event_without_timestamp
    @stubs.post("/v0/items/#{@kv.key}/events/#{@type}") do |env|
      assert_equal @body, JSON.parse(env.body)
      loc = "/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}"
      @ref = make_ref
      [201, response_headers({"Location" => loc, "Etag" => %|"#{@ref}"|}), '']
    end
    event = @kv.events[:checkins] << @body
    @stubs.verify_stubbed_calls
    assert_event_data(event)
  end

  def test_creates_event_with_time
    @stubs.post("/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}") do |env|
      assert_equal @body, JSON.parse(env.body)
      loc = "/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}"
      @ref = make_ref
      [201, response_headers({"Location" => loc, "Etag" => %|"#{@ref}"|}), '']
    end
    event = @kv.events[:checkins][@time].push(@body)
    @stubs.verify_stubbed_calls
    assert_event_data(event)
  end

  def test_retrieves_single_event
    @stubs.get("/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}") do |env|
      @ref = make_ref
      body = {value: @body, timestamp: @timestamp, ordinal: @ord}
      [200, response_headers({"Etag" => %|"#{@ref}-gzip"|}), body.to_json]
    end
    event = @kv.events[:checkins][@time][@ord]
    assert_event_data(event)
  end

  def test_retrieves_single_event_returns_nil_on_not_found
    @stubs.get("/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}") do |env|
      [404, response_headers, response_not_found('')]
    end
    assert_nil @kv.events[@type][@time][@ord]
  end

  # def test_save_on_success_returns_true_and_updates
  #   fail
  # end

  # def test_save_on_error_returns_false
  #   fail
  # end

  def test_save_bang_on_success_returns_true_and_updates
    event = make_event
    new_body = @body.merge({'foo' => 'bar'})
    event[:foo] = "bar"
    assert_equal new_body, event.value
    @stubs.put("/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}") do |env|
      assert_equal new_body, JSON.parse(env.body)
      assert_header 'If-Match', %|"#{event.ref}"|, env
      @ref = make_ref
      [ 204, response_headers({"Etag" => %|"#{@ref}"|}), '' ]
    end
    assert_equal true, event.save!
    assert_equal @ref, event.ref
  end

  def test_save_bang_on_error_raises
    @stubs.put("/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}") do
      error_response(:version_mismatch)
    end
    event = make_event
    assert_raises Orchestrate::API::VersionMismatch do
      event.save!
    end
  end

  # def test_update_modifies_values_and_saves
  #   fail
  # end

  # def test_update_bang_modifies_values_and_raises
  #   fail
  # end
end
