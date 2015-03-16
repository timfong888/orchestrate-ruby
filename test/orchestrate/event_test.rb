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

  def test_save_on_success_returns_true_and_updates
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
    assert_equal true, event.save
    assert_equal @ref, event.ref
  end

  def test_save_on_error_returns_false
    @stubs.put("/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}") do
      error_response(:version_mismatch)
    end
    event = make_event
    assert_equal false, event.save
  end

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

  def test_update_modifies_values_and_saves
    event = make_event
    update = {'foo' => 'bar'}
    @stubs.put("/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}") do |env|
      assert_equal @body.update(update), JSON.parse(env.body)
      assert_header 'If-Match', %|"#{event.ref}"|, env
      @ref = make_ref
      [ 204, response_headers({"Etag" => %|"#{@ref}"|}), '' ]
    end
    assert_equal true, event.update(update)
    assert_equal @body.update(update), event.value
    assert_equal @ref, event.ref
  end

  def test_update_modifies_values_and_returns_false_on_error
    event = make_event
    update = {'foo' => 'bar'}
    @stubs.put("/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}") do |env|
      assert_equal @body.update(update), JSON.parse(env.body)
      assert_header 'If-Match', %|"#{event.ref}"|, env
      error_response(:version_mismatch)
    end
    assert_equal false, event.update(update)
    assert_equal @body.update(update), event.value
  end

  def test_update_bang_modifies_values_and_saves
    event = make_event
    update = {'foo' => 'bar'}
    @stubs.put("/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}") do |env|
      assert_equal @body.update(update), JSON.parse(env.body)
      assert_header 'If-Match', %|"#{event.ref}"|, env
      @ref = make_ref
      [ 204, response_headers({"Etag" => %|"#{@ref}"|}), '' ]
    end
    assert_equal true, event.update!(update)
    assert_equal @body.update(update), event.value
    assert_equal @ref, event.ref
  end

  def test_update_bang_modifies_value_and_raises_on_error
    event = make_event
    update = {'foo' => 'bar'}
    @stubs.put("/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}") do |env|
      assert_equal @body.update(update), JSON.parse(env.body)
      assert_header 'If-Match', %|"#{event.ref}"|, env
      error_response(:version_mismatch)
    end
    assert_raises Orchestrate::API::VersionMismatch do
      event.update!(update)
    end
    assert_equal @body.update(update), event.value
  end

  def test_purge_performs_delete_if_match_returns_true_on_success
    event = make_event
    @stubs.delete("/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}") do |env|
      assert_header 'If-Match', %|"#{event.ref}"|, env
      [204, response_headers, '']
    end
    assert_equal true, event.purge
    assert_nil event.ref
  end

  def test_purge_performs_delete_if_match_returns_false_on_error
    event = make_event
    @stubs.delete("/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}") do |env|
      assert_header 'If-Match', %|"#{event.ref}"|, env
      error_response(:version_mismatch)
    end
    assert_equal false, event.purge
    assert_equal @ref, event.ref
  end

  def test_purge_bang_performs_delete_if_match_raises_on_error
    event = make_event
    @stubs.delete("/v0/items/#{@kv.key}/events/#{@type}/#{@timestamp}/#{@ord}") do |env|
      assert_header 'If-Match', %|"#{event.ref}"|, env
      error_response(:version_mismatch)
    end
    assert_raises Orchestrate::API::VersionMismatch do
      event.purge!
    end
    assert_equal @ref, event.ref
  end

  def test_equality_and_comparison
    app, stubs = make_application
    items = app[:items]

    foo = Orchestrate::KeyValue.new(items, :foo)
    bar = Orchestrate::KeyValue.new(items, :bar)
    assert_equal foo.events, Orchestrate::KeyValue.new(items, :foo).events
    assert foo.events.eql?(Orchestrate::KeyValue.new(items, :foo).events)
    refute_equal foo.events, bar.events
    refute foo.events.eql?(bar.events)

    tweets = foo.events[:tweets]
    assert_equal tweets, Orchestrate::KeyValue.new(items, :foo).events['tweets']
    assert tweets.eql?(Orchestrate::KeyValue.new(items, :foo).events['tweets'])
    refute_equal tweets, foo.events[:checkins]
    refute tweets.eql?(foo.events[:checkins])
    assert_equal(1, foo.events[:checkins] <=> tweets)
    assert_equal(0, tweets <=> foo.events[:tweets])
    assert_equal(-1, tweets <=> foo.events[:checkins])
    refute_equal tweets, bar.events['tweets']
    refute tweets.eql?(bar.events['tweets'])
    assert_nil tweets <=> bar.events['tweets']

    ts = (Time.now.to_f * 1000).floor
    make_tweet_1 = lambda { Orchestrate::Event.from_listing(tweets, {"path" => {"ref" => make_ref, "timestamp" => ts, "ordinal" => 10}}) }
    tweet1 = make_tweet_1.call
    assert_equal tweet1, make_tweet_1.call
    assert tweet1.eql?(make_tweet_1.call)
    assert_equal 0, tweet1 <=> make_tweet_1.call

    tweet2 = Orchestrate::Event.from_listing(tweets, {"path" => {"ref" => make_ref, "timestamp" => ts, "ordinal" => 11}})
    refute_equal tweet1, tweet2
    refute tweet1.eql?(tweet2)
    assert_equal 1, tweet1 <=> tweet2
    assert_equal(-1, tweet2 <=> tweet1)

    tweet3 = Orchestrate::Event.from_listing(tweets, {"path" => {"ref" => make_ref, "timestamp" => ts - 1, "ordinal" => 2}})
    assert_equal(1, tweet1 <=> tweet3)
    assert_equal(-1, tweet3 <=> tweet1)
    assert_equal(1, tweet2 <=> tweet3)
    assert_equal(-1, tweet3 <=> tweet2)

    checkin = Orchestrate::Event.from_listing(foo.events[:checkins], {"path" => {"ref" => make_ref, "timestamp" => ts, "ordinal" => 40}})
    refute_equal tweet1, checkin
    refute tweet1.eql?(checkin)
    assert_nil tweet1 <=> checkin
  end
end
