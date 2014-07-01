require "test_helper"

class CollectionSearchingTest < MiniTest::Unit::TestCase
  def setup
    @app, @stubs = make_application
    @items = @app[:items]
  end

  def test_basic_search
    total = 110
    @stubs.get("/v0/items") do |env|
      assert_equal "foo", env.params['query']
      assert_equal "100", env.params['limit']
      make_listing = lambda{|i| make_kv_listing(:items, key: "item-#{i}", reftime: nil, score: total-i/total*5.0) }
      body = case env.params['offset']
      when nil
        { "results" => 100.times.map(&make_listing), "count" => 100, "total_count" => total,
          "next" => "/v0/items?query=foo&offset=100&limit=100"}
      when "100"
        { "results" => 10.times.map{|i| make_listing.call(i+100)}, "count" => 10, "total_count" => total }
      end
      [ 200, response_headers, body.to_json ]
    end
    results = @items.search("foo").map{|i| i }
    assert_equal 110, results.length
    results.each_with_index do |item, idx|
      assert_in_delta (total-idx/total * 5.0), item[0], 0.005
      assert_equal "item-#{idx}", item[1].key
      assert_nil item[1].reftime
    end
  end

  def test_basic_as_needed
    total=50
    @stubs.get("/v0/items") do |env|
      assert_equal "foo", env.params['query']
      assert_equal "50", env.params['limit']
      make_listing = lambda{|i| make_kv_listing(:items, key: "item-#{i}", reftime: nil, score: total-i/total*5.0) }
      body = case env.params['offset']
      when nil
        { "results" => 50.times.map(&make_listing), "count" => 100, "total_count" => total,
          "next" => "/v0/items?query=foo&offset=50&limit=50"}
      else
        raise ArgumentError.new("unexpected offset: #{env.params['offset']}")
      end
      [ 200, response_headers, body.to_json ]
    end
    results = @items.search("foo").take(50)
    assert_equal 50, results.length
    results.each_with_index do |item, idx|
      assert_in_delta (total-idx/total * 5.0), item[0], 0.005
      assert_equal "item-#{idx}", item[1].key
      assert_nil item[1].reftime
    end
  end
end
