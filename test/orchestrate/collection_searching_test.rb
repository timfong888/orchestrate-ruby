require "test_helper"

class CollectionSearchingTest < MiniTest::Unit::TestCase
  def setup
    @app, @stubs = make_application
    @items = @app[:items]
  end

  def test_basic_search
    @stubs.get("/v0/items") do |env|
      assert_equal "foo", env.params['query']
      body = {
        "results" => 100.times.map {|i| make_kv_listing(:items, key: "item-#{i}", reftime: nil, score: 50-i/50.0) },
        "count" => 100, "total_count" => 100
      }
      [ 200, response_headers, body.to_json ]
    end
    @items.search("foo").each_with_index do |item, idx|
      assert_in_delta 50-idx/50.0, item[0], 0.01
      assert_equal "item-#{idx}", item[1].key
      assert_nil item[1].reftime
    end
  end
end
