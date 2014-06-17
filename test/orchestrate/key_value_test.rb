require "test_helper"

class KeyValueTest < MiniTest::Unit::TestCase

  def make_kv_item(collection, stubs, opts={})
    key = opts[:key] || 'hello'
    ref = opts[:ref] || "12345"
    body = opts[:body] || {"hello" => "world"}
    res_headers = response_headers({
      'Etag' => "\"#{ref}\"",
      'Content-Location' => "/v0/#{collection.name}/#{key}/refs/#{ref}"
    })
    stubs.get("/v0/items/#{key}") { [200, res_headers, body.to_json] }
    Orchestrate::KeyValue.load(collection, key)
  end

  def test_load_with_collection_and_key
    app, stubs = make_application
    items = app[:items]
    ref = "123456"
    body = {"hello" => "world"}
    res_headers = response_headers({
      'Etag' => "\"#{ref}\"",
      'Content-Location' => "/v0/items/hello/refs/#{ref}"
    })
    stubs.get('/v0/items/hello') {|env| [200, res_headers, body.to_json] }
    kv = Orchestrate::KeyValue.load(items, :hello)
    assert_equal "hello", kv.key
    assert_equal ref, kv.ref
    assert_equal "items/hello", kv.id
    assert_equal body, kv.value
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

end

