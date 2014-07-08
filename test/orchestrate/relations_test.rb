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

  def make_results(colls, count)
    count.times.map do |i|
      type = colls[i % colls.length]
      make_kv_listing(type, {reftime:nil, key: "#{type.name}-#{i}", body: {index: i}})
    end
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
    colls = [@items, @app[:things], @app[:stuff]]
    @stubs.get("/v0/#{@kv.collection_name}/#{@kv.key}/relations/#{@relation_type}") do |env|
      [200, response_headers, {results: make_results(colls, 100), count: 100}.to_json]
    end
    related_stuff = @kv.relations[@relation_type].to_a
    assert_equal 100, related_stuff.size
    related_stuff.each do |item|
      assert_kind_of Orchestrate::KeyValue, item
      match = item.key.match(/(\w+)-(\d+)/)
      assert_equal item[:index], match[2].to_i
      assert_equal item.collection.name, match[1]
      assert_equal item.collection, colls[match[2].to_i % colls.length]
    end
  end

  def test_enumerates_over_subrelation
    colls = [@items, @app[:things], @app[:stuff]]
    @stubs.get("/v0/items/#{@kv.key}/relations/siblings/children/siblings") do |env|
      [200, response_headers, {results: make_results(colls, 100), count:100}.to_json]
    end
    related_stuff = @kv.relations[:siblings][:children][:siblings].to_a
    assert_equal 100, related_stuff.size
    related_stuff.each do |item|
      assert_kind_of Orchestrate::KeyValue, item
      match = item.key.match(/(\w+)-(\d+)/)
      assert_equal item[:index], match[2].to_i
      assert_equal item.collection.name, match[1]
      assert_equal item.collection, colls[match[2].to_i % colls.length]
    end
  end

end

