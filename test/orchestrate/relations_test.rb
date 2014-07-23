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

  def test_prevents_parallel_enumeration
    app, stubs = make_application({parallel: true})
    one = make_kv_item(app[:items], stubs, {key: 'one'})
    stubs.get("/v0/items/one/relations/siblings") do |env|
      [200, response_headers, {results: make_results([app[:items]], 10), count:10}.to_json]
    end
    assert_raises Orchestrate::ResultsNotReady do
      app.in_parallel { one.relations[:siblings].to_a }
    end
  end

  def test_parallel_get_performs_call
    called = false
    siblings = nil
    app, stubs = make_application({parallel: true})
    one = make_kv_item(app[:items], stubs, {key: 'one'})
    stubs.get("/v0/items/one/relations/siblings") do |env|
      called = true
      [200, response_headers, {results: make_results([app[:items]], 10), count:10}.to_json]
    end
    app.in_parallel do
      siblings = one.relations[:siblings].each
    end
    assert called, "parallel block finished, API call not made yet for enumerable"
    siblings = siblings.to_a
    assert_equal 10, siblings.size
  end

  def test_lazy_does_not_perform_call
    return unless [].respond_to?(:lazy)
    called = false
    app, stubs = make_application
    one = make_kv_item(app[:items], stubs, {key:'one'})
    stubs.get("/v0/items/one/relations/siblings") do |env|
      called = true
      [200, response_headers, {results: make_results([app[:items]], 10), count:10}.to_json]
    end
    siblings = one.relations[:siblings].lazy
    refute called, "lazy enumerator not evauluated, but request called"
    siblings = siblings.to_a
    assert called, "lazy enumerator forced, but request not called"
    assert_equal 10, siblings.size
  end

end

