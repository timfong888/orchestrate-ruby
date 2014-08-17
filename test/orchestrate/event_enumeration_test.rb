require "test_helper"

class EventEnumerationTest < MiniTest::Unit::TestCase
  def setup
    @app, @stubs = make_application
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
    # assert false
  end

  def test_enumerates_over_range_from_after_before
    # assert false
  end

  def test_enumerator_in_parallel_raises_not_ready_if_forced
    # assert false
  end

  def test_enumerator_in_parallel_prefetches_lazy_enums
    # assert false
  end

  def test_enumerator_in_parallel_prefetches_enums
    # assert false
  end

  def test_enumerator_doesnt_prefetch_lazy_enums
    # assert false
  end

  def test_enumerator_prefetches_enums
    # assert false
  end

  def test_enumerator_sets_limit_from_limit
    # assert false
  end
end