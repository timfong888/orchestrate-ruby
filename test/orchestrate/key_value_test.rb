require "test_helper"

class KeyValueTest < MiniTest::Unit::TestCase

  def test_load_with_collection_and_key
    app, stubs = make_application
    items = app[:items]
    ref = "123456"
    body = {"hello" => "world"}
    kv = make_kv_item(items, stubs, { key: "hello", ref: ref, body: body })
    assert_equal "hello", kv.key
    assert_equal ref, kv.ref
    assert_equal "items/hello", kv.id
    assert_equal body, kv.value
    assert kv.loaded?
    refute kv.archival?
    refute kv.tombstone?
    assert_in_delta Time.now.to_f, kv.last_request_time.to_f, 1.1
  end

  def test_value_accessors
    app, stubs = make_application
    items = app[:items]
    body = {"hello" => "world", "one" => "two"}
    kv = make_kv_item(items, stubs, {body: body})
    assert_equal body["hello"], kv["hello"]
    assert_equal body["hello"], kv[:hello]
    assert_equal body["one"], kv["one"]
    assert_equal body["one"], kv[:one]

    kv[:one] = 1
    assert_equal 1, kv["one"]
    kv[:two] = "Two"
    assert_equal "Two", kv[:two]
    kv["three"] = "Tres"
    assert_equal "Tres", kv[:three]
    kv["four"] = "IV"
    assert_equal "IV", kv["four"]
  end

  def test_instantiates_from_parallel_request
    app, stubs = make_application({parallel: true})
    items = app[:items]
    body = {"hello" => "foo"}
    ref = make_ref
    stubs.get("/v0/items/foo") { [200, response_headers(ref_headers(:items, :foo, ref)), body.to_json] }
    stubs.put("/v0/items/bar") { [201, response_headers(ref_headers(:items, :bar, make_ref)), ''] }
    results = app.in_parallel do |r|
      r[:foo] = items[:foo]
      r[:bar] = items.create(:bar, {})
    end
    assert_equal 'foo', results[:foo].key
    assert_equal ref, results[:foo].ref
    assert_equal body, results[:foo].value
    assert_equal 'bar', results[:bar].key
  end

  def test_instantiates_without_loading
    app, stubs = make_application
    items = app[:items]
    kv = Orchestrate::KeyValue.new(items, 'keyname')
    assert_equal 'keyname', kv.key
    assert_equal items, kv.collection
    assert_equal Hash.new, kv.value
    assert_equal false, kv.ref
    assert ! kv.loaded?
  end

  def test_equality
    app, stubs = make_application
    app2, stubs = make_application
    items = app[:items]

    foo = Orchestrate::KeyValue.new(items, :foo)

    assert_equal foo, Orchestrate::KeyValue.new(items, :foo)
    refute_equal foo, Orchestrate::KeyValue.new(items, :bar)
    refute_equal foo, Orchestrate::KeyValue.new(app[:users], :foo)
    refute_equal foo, Orchestrate::KeyValue.new(app2[:items], :foo)
    refute_equal foo, :foo

    assert foo.eql?(Orchestrate::KeyValue.new(items, :foo))
    refute foo.eql?(Orchestrate::KeyValue.new(items, :bar))
    refute foo.eql?(Orchestrate::KeyValue.new(app[:users], :foo))
    refute foo.eql?(Orchestrate::KeyValue.new(app2[:items], :foo))
    refute foo.eql?(:foo)

    # equal? is for Object equality
    assert foo.equal?(foo)
    refute foo.equal?(Orchestrate::KeyValue.new(items, :foo))
  end

  def test_sorting
    app, stubs = make_application
    app2, stubs = make_application

    foo = Orchestrate::KeyValue.new(app[:items], :foo)

    assert_equal(-1, foo <=> Orchestrate::KeyValue.new(app[:items], :bar))
    assert_equal  0, foo <=> Orchestrate::KeyValue.new(app[:items], :foo)
    assert_equal  1, foo <=> Orchestrate::KeyValue.new(app[:items], :zoo)
    assert_nil foo <=> Orchestrate::KeyValue.new(app[:users], :foo)
    assert_nil foo <=> Orchestrate::KeyValue.new(app2[:items], :foo)
    assert_nil foo <=> :foo
  end

end

