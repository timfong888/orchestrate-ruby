require 'test_helper'
require 'cgi'

class CollectionSortingTest < MiniTest::Unit::TestCase
  def setup
    @app, @stubs = make_application({parallel:true})
    @items = @app[:items]

    @query = '(foo)'
    @limit = 100
    @total = 110

    @make_listing = lambda{|i| make_kv_listing(:items, key: "item-#{i}", reftime: nil, score: @total-i/@total*5.0, rank: @total-i/@total*2.0 )}
    @handle_offset = lambda do |offset|
      case offset
      when nil
        { "results" => 100.times.map{|i| @make_listing.call(i)}, "count" => 100, "total_count" => @total,
          "next" => "/v0/items?query=#{CGI.escape(@query)}&offset=100&limit=100"}
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

  def test_basic_sort_ascending
    results = @items.search("foo").order(:score, :asc).find.each.map{|i| i }
    assert_equal 110, results.length
    results.each_with_index do |item, idx|
      assert_in_delta (@total-idx/@total * 5.0), item[0], 0.005
      assert_equal "item-#{idx}", item[1].key
      assert_equal @total-idx/@total*5.0, item["score".to_i]
      assert_nil item[1].reftime
    end
  end

  def test_basic_sort_descending
    results = @items.search("foo").order(:score, :desc).find.each.map{|i| i }
    assert_equal 110, results.length
    results.each_with_index do |item, idx|
      assert_in_delta (@total-idx/@total * 5.0), item[0], 0.005
      assert_equal "item-#{idx}", item[1].key
      assert_equal @total-idx/@total*5.0, item["score".to_i]
      assert_nil item[1].reftime
    end
  end

  def test_basic_multiple_fields_sort_ascending
    results = @items.search("foo").order(:score, :asc, :rank, :asc).find.each.map{|i| i }
    assert_equal 110, results.length
    results.each_with_index do |item, idx|
      assert_in_delta (@total-idx/@total * 5.0), item[0], 0.005
      assert_equal "item-#{idx}", item[1].key
      assert_equal @total-idx/@total*5.0, item["score".to_i]
      assert_equal @total-idx/@total*2.0, item["rank".to_i]
      assert_nil item[1].reftime
    end
  end

  def test_basic_multiple_fields_sort_descending
    results = @items.search("foo").order(:score, :asc, :rank, :desc).find.each.map{|i| i }
    assert_equal 110, results.length
    results.each_with_index do |item, idx|
      assert_in_delta (@total-idx/@total * 5.0), item[0], 0.005
      assert_equal "item-#{idx}", item[1].key
      assert_equal @total-idx/@total*5.0, item["score".to_i]
      assert_equal @total-idx/@total*2.0, item["rank".to_i]
      assert_nil item[1].reftime
    end
  end

end
