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
    assert_in_delta Time.now.to_f, kv.last_request_time.to_f, 1
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

  def test_instantiates_without_loading
    app, stubs = make_application
    items = app[:items]
    kv = Orchestrate::KeyValue.new(items, 'keyname')
    assert_equal 'keyname', kv.key
    assert_equal items, kv.collection
    assert ! kv.loaded?
  end

  def test_instantiates_from_collection_and_listing
    app, stubs = make_application
    listing = make_kv_listing('items', {key: "foo"})
    kv = Orchestrate::KeyValue.new(app[:items], listing, Time.now)
    assert_equal 'items', kv.collection_name
    assert_equal "foo", kv.key
    assert_equal listing['path']['ref'], kv.ref
    assert_equal listing['value'], kv.value
    assert_in_delta Time.now.to_f, kv.last_request_time.to_f, 1
  end

end

