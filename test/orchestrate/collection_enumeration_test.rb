require "test_helper"

class CollectionEnumerationTest < MiniTest::Unit::TestCase

  def test_enumerates_over_all
    app, stubs = make_application
    stubs.get("/v0/items") do |env|
      assert_equal "100", env.params['limit']
      body = case env.params['afterKey']
      when nil
        { "results" => 100.times.map {|x| make_kv_listing(:items, key: "key-#{x}") },
          "next" => "/v0/items?afterKey=key-99&limit=100", "count" => 100 }
      when 'key-99'
        { "results" => 4.times.map {|x| make_kv_listing(:items, key: "key-#{100+x}")},
          "count" => 4 }
      else
        raise ArgumentError.new("unexpected afterKey: #{env.params['afterKey']}")
      end
      [ 200, response_headers, body.to_json ]
    end
    items = app[:items].map {|item| item }
    assert_equal 104, items.length
    items.each_with_index do |item, index|
      assert_equal "key-#{index}", item.key
      assert item.ref
      assert item.reftime
      assert item.value
      assert_equal "key-#{index}", item[:key]
      assert_in_delta Time.now.to_f, item.last_request_time.to_f, 1
    end
  end

  def test_enumerator_in_parallel
    app, stubs = make_application({parallel:true})
    stubs.get("/v0/items") do |env|
      body = case env.params['afterKey']
      when nil
        { "results" => 10.times.map {|x| make_kv_listing(:items, key: "key-#{x}") },
          "next" => "/v0/items?afterKey=key-9", "count" => 10 }
      when 'key-9'
        { "results" => 4.times.map {|x| make_kv_listing(:items, key: "key-#{10+x}")},
          "count" => 4 }
      else
        raise ArgumentError.new("unexpected afterKey: #{env.params['afterKey']}")
      end
      [ 200, response_headers, body.to_json ]
    end
    items=nil
    assert_raises Orchestrate::ResultsNotReady do
      app.in_parallel { app[:items].take(5) }
    end
    if app[:items].respond_to?(:lazy)
      app.in_parallel do
        items = app[:items].lazy.map {|item| item }
      end
      items = items.force
      assert_equal 14, items.length
      items.each_with_index do |item, index|
        assert_equal "key-#{index}", item.key
        assert item.ref
        assert item.reftime
        assert item.value
        assert_equal "key-#{index}", item[:key]
        assert_in_delta Time.now.to_f, item.last_request_time.to_f, 1
      end
    end
  end

  def test_enumerates_as_needed
    app, stubs = make_application
    stubs.get("/v0/items") do |env|
      if env.params['afterKey'] != nil
        raise ArgumentError.new("unexpected afterKey: #{env.params['afterKey']}")
      else
        body = { "results" => 10.times.map {|x| make_kv_listing(:items, key: "key-#{x}")},
                 "next" => "/v0/items?afterKey=key-9", "count" => 10 }
        [ 200, response_headers, body.to_json ]
      end
    end
    items = app[:items].take(5).map {|item| item }
    assert_equal 5, items.length
  end

  def test_enumerates_with_range_start_and_end
    keys = %w[bar bat bee cat dog ear foo]
    app, stubs = make_application
    stubs.get("/v0/items") do |env|
      assert_equal "bar", env.params['startKey']
      assert_equal "foo", env.params['endKey']
      body = { "results" => keys.map {|k| make_kv_listing(:items, key: k)},
               "count" => keys.length }
      [ 200, response_headers, body.to_json ]
    end
    items = app[:items].start(:bar).end(:foo).take(5).map {|item| item.key }
    assert_equal 5, items.length
    assert_equal %w[bar bat bee cat dog], items
  end

  def test_enumerates_with_range_after_and_before
    keys = %w[bar bat bee cat dog ear foo]
    app, stubs = make_application
    stubs.get("/v0/items") do |env|
      assert_equal "bar", env.params['afterKey']
      assert_equal "goo", env.params['beforeKey']
      body = { "results" => keys.drop(1).map {|k| make_kv_listing(:items, key: k)},
               "count" => keys.length }
      [ 200, response_headers, body.to_json ]
    end
    items = app[:items].after(:bar).before(:goo).take(5).map {|item| item.key }
    assert_equal 5, items.length
    assert_equal %w[bat bee cat dog ear], items
  end

end

