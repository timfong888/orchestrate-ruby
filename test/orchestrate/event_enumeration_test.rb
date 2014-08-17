require "test_helper"

class EventEnumerationTest < MiniTest::Unit::TestCase
  def setup
    @app, @stubs = make_application({parallel: true})
    @kv = make_kv_item(@app[:items], @stubs)
    @type = :events
    @limit = "100"
    @called = false
    @stubs.get("/v0/items/#{@kv.key}/events/#{@type}") do |env|
      @called = true
      assert_equal @limit, env.params['limit']
      body = case env.params['beforeEvent']
      when nil
        events = 100.times.map{|i| make_event({ts: @start_time - i}) }
        next_event = events.last.values_at("timestamp", "ordinal").join('/')
        { "results" => events, "count" => 100,
          "next" => "/v0/items/#{@kv.key}/events/#{@type}?beforeEvent=#{next_event}&limit=100" }
      when "#{@start_time - 99}/1"
        events = 10.times.map{|i| make_event({ts: @start_time - 100 - i})}
        { "results" => events, "count" => 10 }
      else
        raise ArgumentError.new("unexpected beforeEvent: #{env.params['beforeEvent']}")
      end
      [200, response_headers, body.to_json]
    end
    @start_time = (Time.now.to_f * 1000).to_i
  end

  def make_event(opts={})
    timestamp = opts[:ts] || @start_time
    ordinal = opts[:ord] || 1
    ref = opts[:ref] || make_ref
    value = opts[:val] || { "msg" => "hello world" }
    { "path" => { "collection" => @kv.collection_name, "key" => @kv.key, "type" => @type.to_s,
                  "timestamp" => timestamp, "ordinal" => ordinal, "ref" => ref },
      "value" => value,
      "timestamp" => timestamp, "ordinal" => ordinal }
  end

  def test_enumerates_all_from_event_type
    events = @kv.events[@type].to_a
    assert_equal 110, events.length
    events.each_with_index do |event, index|
      assert_equal @kv, event.key
      assert_equal @type.to_s, event.type_name
      assert_equal @start_time - index, event.timestamp
      assert_equal 1, event.ordinal
      assert event.ref
      assert event.value
      assert_in_delta Time.now.to_f, event.last_request_time.to_f, 1.1
    end
  end

  def test_enumerates_over_range_from_start_end
    app, stubs = make_application
    kv = make_kv_item(app[:items], stubs)
    start_event = Orchestrate::Event.new(kv.events[@type])
    start_event.instance_variable_set(:@timestamp, @start_time - 1000)
    start_event.instance_variable_set(:@ordinal, 5)
    end_event = @start_time
    stubs.get("/v0/items/#{@kv.key}/events/#{@type}") do |env|
      assert_equal "#{start_event.timestamp}/#{start_event.ordinal}", env.params['startEvent']
      assert_equal "#{end_event}", env.params['endEvent']
      [200, response_headers, {"count" => 0, "results" => []}.to_json]
    end
    response = kv.events[@type].start(start_event).end(end_event).to_a
    assert_equal [], response
  end

  def test_enumerates_over_range_from_after_before
    app, stubs = make_application
    kv = make_kv_item(app[:items], stubs)
    after_event = Orchestrate::Event.new(kv.events[@type])
    after_event.instance_variable_set(:@timestamp, @start_time - 1000)
    after_event.instance_variable_set(:@ordinal, 5)
    before_event = Time.at(@start_time)
    stubs.get("/v0/items/#{@kv.key}/events/#{@type}") do |env|
      assert_equal "#{after_event.timestamp}/#{after_event.ordinal}", env.params['afterEvent']
      assert_equal "#{(before_event.to_f * 1000).to_i}", env.params['beforeEvent']
      [200, response_headers, {"count" => 0, "results" => []}.to_json]
    end
    response = kv.events[@type].before(before_event).after(after_event).to_a
    assert_equal [], response
  end

  def test_enumerator_sets_limit_from_limit
    @limit = "5"
    events = @kv.events[@type].take(5)
    assert_equal 5, events.length
  end

  def test_enumerator_in_parallel_raises_not_ready_if_forced
    assert_raises Orchestrate::ResultsNotReady do
      @app.in_parallel { @kv.events[@type].to_a }
    end
  end

  def test_enumerator_in_parallel_prefetches_lazy_enums
    return unless [].respond_to?(:lazy)
    events = nil
    @app.in_parallel { events = @kv.events[@type].lazy.map{|e| e } }
    assert @called, "lazy enumerator wasn't prefetched inside of parallel"
    events = events.force
    assert_equal 110, events.to_a.size
    events.each_with_index do |event, index|
      assert_equal @kv, event.key
      assert_equal @type.to_s, event.type_name
      assert_equal @start_time - index, event.timestamp
      assert_equal 1, event.ordinal
      assert event.ref
      assert event.value
      assert_in_delta Time.now.to_f, event.last_request_time.to_f, 1.1
    end
  end

  def test_enumerator_in_parallel_prefetches_enums
    events = nil
    @app.in_parallel { events = @kv.events[@type].each }
    assert @called, "enumerator wasn't prefetched inside of parallel"
    assert_equal 110, events.to_a.size
    events.each_with_index do |event, index|
      assert_equal @kv, event.key
      assert_equal @type.to_s, event.type_name
      assert_equal @start_time - index, event.timestamp
      assert_equal 1, event.ordinal
      assert event.ref
      assert event.value
      assert_in_delta Time.now.to_f, event.last_request_time.to_f, 1.1
    end
  end

  def test_enumerator_doesnt_prefetch_lazy_enums
    return unless [].respond_to?(:lazy)
    events = @kv.events[@type].lazy.map{|e| e }
    refute @called, "lazy enumerator was prefetched"
    events = events.force
    assert_equal 110, events.to_a.size
    events.each_with_index do |event, index|
      assert_equal @kv, event.key
      assert_equal @type.to_s, event.type_name
      assert_equal @start_time - index, event.timestamp
      assert_equal 1, event.ordinal
      assert event.ref
      assert event.value
      assert_in_delta Time.now.to_f, event.last_request_time.to_f, 1.1
    end
  end

  def test_enumerator_prefetches_enums
    events = @kv.events[@type].each
    assert @called, "enumerator wasn't prefetched"
    assert_equal 110, events.to_a.size
    events.each_with_index do |event, index|
      assert_equal @kv, event.key
      assert_equal @type.to_s, event.type_name
      assert_equal @start_time - index, event.timestamp
      assert_equal 1, event.ordinal
      assert event.ref
      assert event.value
      assert_in_delta Time.now.to_f, event.last_request_time.to_f, 1.1
    end
  end

end
