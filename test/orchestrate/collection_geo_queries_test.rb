require "test_helper"

class CollectionGeoQueriesTest < MiniTest::Unit::TestCase
  def setup
    @app, @stubs = make_application({parallel:true})
    @items = @app[:items]

    @near_query = "(location:NEAR:{lat:12 lon:56 dist:1km})"
    @in_query = "(location:IN:{north:12 east:57 south:12 west:56})"
    @total = 110

    @make_listing = lambda{|i| make_kv_listing(:items, key: "item-#{i}", reftime: nil, score: @total-i/@total*5.0) }
    @handle_geo = lambda do |query|
      case query
      when "(location:NEAR:{lat:12 lon:56 dist:1km})"
        { "results" => 10.times.map{|i| @make_listing.call(i)}, "count" => 10, "total_count" => 10 }
      when "(location:IN:{north:12 east:57 south:12 west:56})"
        { "results" => 12.times.map{|i| @make_listing.call(i)}, "count" => 12, "total_count" => 12 }
      when "(location:NEAR:{lat:12 lon:56 dist:1km}&sort=location:distance:asc)"
        { "results" => 10.times.map{|i| @make_listing.call(i)}, "count" => 10, "total_count" => 10 }
      else
        raise ArgumentError.new("unexpected query: #{query}")
      end
    end

    @called = false
    @stubs.get("/v0/items") do |env|
      @called = true
      assert_equal @query, env.params['query']
      body = @handle_geo.call(env.params['query'])
      [ 200, response_headers, body.to_json ]
    end
  end

  def test_near_search_without_units
    @query = @near_query
    results = @items.near("location", 12, 56, 1).find.each.map{|i| i }
    assert_equal 10, results.length
    results.each_with_index do |item, idx|
      assert_in_delta (@total-idx/@total * 5.0), item[0], 0.005
      assert_equal "item-#{idx}", item[1].key
      assert_nil item[1].reftime
    end
  end

  def test_near_search_with_units
    @query = @near_query
    results = @items.near("location", 12, 56, 1, 'km').find.each.map{|i| i }
    assert_equal 10, results.length
    results.each_with_index do |item, idx|
      assert_in_delta (@total-idx/@total * 5.0), item[0], 0.005
      assert_equal "item-#{idx}", item[1].key
      assert_nil item[1].reftime
    end
  end

  def test_near_search_with_sort
    @query = @near_query
    results = @items.near("location", 12, 56, 1, 'km').order(:location).find.each.map{|i| i }
    assert_equal 10, results.length
    results.each_with_index do |item, idx|
      assert_in_delta (@total-idx/@total * 5.0), item[0], 0.005
      assert_equal "item-#{idx}", item[1].key
      assert_nil item[1].reftime
    end
  end

  def test_in_bounding_box
    @query = @in_query
    results = @items.in("location", {north:12, east:57, south:12, west:56}).find.each.map{|i| i }
    assert_equal 12, results.length
    results.each_with_index do |item, idx|
      assert_in_delta (@total-idx/@total * 5.0), item[0], 0.005
      assert_equal "item-#{idx}", item[1].key
      assert_nil item[1].reftime
    end
  end

  def test_in_bounding_box_with_sort
    @query = @in_query
    results = @items.in("location", {north:12, east:57, south:12, west:56}).order(:location).find.each.map{|i| i }
    assert_equal 12, results.length
    results.each_with_index do |item, idx|
      assert_in_delta (@total-idx/@total * 5.0), item[0], 0.005
      assert_equal "item-#{idx}", item[1].key
      assert_nil item[1].reftime
    end
  end
end
