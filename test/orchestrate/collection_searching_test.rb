require "test_helper"

class CollectionSearchingTest < MiniTest::Unit::TestCase
  def setup
    @app, @stubs = make_application({parallel:true})
    @items = @app[:items]

    @query = "foo"
    @limit = 100
    @total = 110

    @make_listing = lambda{|i| make_kv_listing(:items, key: "item-#{i}", reftime: nil, score: @total-i/@total*5.0) }
    @handle_offset = lambda do |offset|
      case offset
      when nil
        { "results" => 100.times.map{|i| @make_listing.call(i)}, "count" => 100, "total_count" => @total,
          "next" => "/v0/items?query=foo&offset=100&limit=100"}
      when "100"
        { "results" => 10.times.map{|i| @make_listing.call(i+100)}, "count" => 10, "total_count" => @total }
      else
        raise ArgumentError.new("unexpected offset: #{env.params['offset']}")
      end
    end

    @called = false
    @stubs.get("/v0/items") do |env|
      @called = true
      assert_equal @query, env.params['query']
      assert_equal @limit, env.params['limit'].to_i
      body = @handle_offset.call(env.params['offset'])
      [ 200, response_headers, body.to_json ]
    end
  end

  def test_basic_search
    results = @items.search("foo").execute.each.map{|i| i }
    assert_equal 110, results.length
    results.each_with_index do |item, idx|
      assert_in_delta (@total-idx/@total * 5.0), item[0], 0.005
      assert_equal "item-#{idx}", item[1].key
      assert_nil item[1].reftime
    end
  end

  def test_basic_as_needed
    @limit = 50
    offset = 10
    @handle_offset = lambda do |o|
      case o
      when "10"
        { "results" => 50.times.map{|i| @make_listing.call(i+offset) }, "count" => @limit, "total_count" => @total }
      else
        raise ArgumentError.new("unexpected offset: #{o}")
      end
    end
    results = @items.search("foo").offset(offset).limit(@limit).execute
    assert_equal 10, results.options[:offset]
    results.each_with_index do |item, idx|
      assert_in_delta (@total-(idx+10)/@total * 5.0), item[0], 0.005
      assert_equal "item-#{idx+10}", item[1].key
      assert_nil item[1].reftime
    end
  end

  def test_in_parallel_prefetches_enums
    items = nil
    @app.in_parallel { items = @app[:items].search("foo").execute.each }
    assert @called, "enum wasn't prefetched inside in_parallel"
    assert_equal @total, items.to_a.size
  end

  def test_in_parallel_prefetches_lazy_enums
    return unless [].respond_to?(:lazy)
    items = nil
    @app.in_parallel { items = @app[:items].search("foo").execute.lazy.map{|d| d } }
    assert @called, "lazy wasn't prefetched from in_parallel"
    assert_equal @total, items.force.size
  end

  def test_in_parallel_raises_if_forced
    assert_raises Orchestrate::ResultsNotReady do
      @app.in_parallel { @app[:items].search("foo").execute.each.to_a }
    end
  end

  def test_enums_prefetch
    items = nil
    @app.in_parallel { items = @app[:items].search("foo").execute.each }
    assert @called, "enum wasn't prefetched"
    assert_equal @total, items.to_a.size
  end

  def test_lazy_enums_dont_prefetch
    return unless [].respond_to?(:lazy)
    items = @app[:items].search("foo").lazy.map{|d| d }
    refute @called, "lazy was prefetched outside in_parallel"
    assert_equal @total, items.force.size
  end

end
