require "test_helper"

class RelationsTest < MiniTest::Unit::TestCase

  def setup
    @app, @stubs = make_application
    @items = @app[:items]
    @kv = make_kv_item(@items, @stubs)
    @other_kv = make_kv_item(@items, @stubs)
    @relation_type = :siblings
    @path = ['items', @kv.key, 'relation', @relation_type, :items, @other_kv.key]
  end

  def test_adds_relation_with_kv
    @stubs.put("/v0/#{@path.join('/')}") { [ 204, response_headers, '' ] }
    @kv.relations[@relation_type] << @other_kv
    @stubs.verify_stubbed_calls
  end

  def test_adds_from_collname_and_keyname
    @stubs.put("/v0/#{@path.join('/')}") { [ 204, response_headers, '' ] }
    @kv.relations[@relation_type].push(:items, @other_kv.key)
    @stubs.verify_stubbed_calls
  end

  def test_removes_relation_with_kv
    @stubs.delete("/v0/#{@path.join('/')}") do |env|
      assert_equal 'true', env.params['purge']
      [ 204, response_headers, '' ]
    end
    @kv.relations[@relation_type].delete(@other_kv)
    @stubs.verify_stubbed_calls
  end

  def test_removes_relation_with_collname_and_keyname
    @stubs.delete("/v0/#{@path.join('/')}") do |env|
      assert_equal 'true', env.params['purge']
      [ 204, response_headers, '' ]
    end
    @kv.relations[@relation_type].delete(:items, @other_kv.key)
    @stubs.verify_stubbed_calls
  end

  def test_enumerates_over_relation
    @stubs.get("/v0/#{@kv.collection_name}/#{@kv.key}/relations/#{@relation_type}") do |env|
      body = 100.times.map do |i|
        make_kv_listing(@items, {reftime:nil, key: "item-#{i}", body: {item: "item-#{i}"}})
      end
      [200, response_headers, {results: body, count: 100}.to_json]
    end
    related_stuff = @kv.relations[@relation_type].to_a
    assert_equal 100, related_stuff.size
    related_stuff.each do |item|
      assert_kind_of Orchestrate::KeyValue, item
      assert_equal item.key, item[:item]
    end
  end

end

