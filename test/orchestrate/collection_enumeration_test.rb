require "test_helper"

class CollectionEnumerationTest < MiniTest::Unit::TestCase

  def test_enumerates_over_all
    app, stubs = make_application
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
    items = app[:items].map {|item| item }
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

end

