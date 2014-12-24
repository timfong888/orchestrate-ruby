require "test_helper"

class CollectionSearchAggregates < MiniTest::Unit::TestCase
  def setup
    @app, @stubs = make_application({parallel:true})
    @items = @app[:items]

    @query = "foo"
    @stats = [{
      "aggregate_kind" => "stats",
      "field_name" => "value.bar",
      "value_count" => 100,
      "statistics" => {
        "min" => 2.99,
        "max" => 29.99,
        "mean" => 11.779370,
        "sum" => 1495.98,
        "sum_of_squares" => 32740.05,
        "variance" => 119.986850,
        "std_dev" => 10.953851
      }
    }]
    @range = [{
      "aggregate_kind" => "range",
      "field_name" => "value.bar",
      "value_count" => 100,
      "buckets" => [{
        "max" => 40,
        "count" => 42
      }]
    }]
    @distance = [{
      "aggregate_kind" => "distance",
      "field_name" => "value.bar",
      "value_count" => 100,
      "buckets" => [{
        "min" => 0,
        "max" => 1,
        "count" => 42
      }]
    }]
    @time_series = [{
      "aggregate_kind" => "time_series",
      "field_name" => "value.bar",
      "interval" => "day",
      "value_count" => 100,
      "buckets" => [{
        "bucket" => "2014-11-01",
        "count" => 17
      }]
    }]
    @limit = 100
    @total = 110

    @make_listing = lambda{|i| make_kv_listing(:items, key: "item-#{i}", reftime: nil, score: @total-i/@total*5.0) }
    @handle_aggregate = lambda do |aggregate|
      case aggregate
      when 'bar:stats'
        { "results" => 100.times.map{|i| @make_listing.call(i)}, "count" => 100, "total_count" => @total,
          "aggregates" => @stats }
      when 'bar:range:*~40:'
        { "results" => 100.times.map{|i| @make_listing.call(i)}, "count" => 100, "total_count" => @total,
          "aggregates" => @range }
      when 'bar:distance:0~1:'
        { "results" => 100.times.map{|i| @make_listing.call(i)}, "count" => 100, "total_count" => @total,
          "aggregates" => @distance }
      when 'bar:time_series:day'
        { "results" => 100.times.map{|i| @make_listing.call(i)}, "count" => 100, "total_count" => @total,
          "aggregates" => @time_series }
      else
        raise ArgumentError.new("unexpected aggregate: #{aggregate}")
      end
    end

    @called = false
    @stubs.get("/v0/items") do |env|
      @called = true
      assert_equal @query, env.params['query']
      assert_equal @limit, env.params['limit'].to_i
      body = @handle_aggregate.call(env.params['aggregate'])
      [ 200, response_headers, body.to_json ]
    end
  end

  def test_basic_stats_aggregate
    results = @items.search("foo").aggregate.stats("bar").find
    results.each_aggregate
    assert_equal @stats, results.aggregates
  end

  def test_basic_range_aggregate
    results = @items.search("foo").aggregate.range("bar").below(40).find
    results.each_aggregate
    assert_equal @range, results.aggregates
  end

  def test_basic_distance_aggregate
    results = @items.search("foo").aggregate.distance("bar").between(0,1).find
    results.each_aggregate
    assert_equal @distance, results.aggregates
  end

  def test_basic_time_series_aggregate
    results = @items.search("foo").aggregate.time_series("bar","day").find
    results.each_aggregate
    assert_equal @time_series, results.aggregates
  end
end
