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
    kv = make_kv_item(items, stubs, { key: "hello", ref: ref, body: body })
    assert_equal "hello", kv.key
    assert_equal ref, kv.ref
    assert_equal "items/hello", kv.id
    assert_equal body, kv.value
    assert kv.loaded?
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

  def test_save_performs_put_if_match_and_returns_boolean
    app, stubs = make_application
    items = app[:items]
    kv = make_kv_item(items, stubs)
    kv[:foo] = "bar"
    new_ref = nil
    stubs.put("/v0/items/#{kv.key}") do |env|
      assert_equal kv.value, JSON.parse(env.body)
      assert_header 'If-Match', "\"#{kv.ref}\"", env
      new_ref = make_ref
      [ 201, response_headers({'Etag' => new_ref, "Location" => "/v0/items/#{kv.key}/refs/#{new_ref}"}), '' ]
    end
    assert_equal true, kv.save
    assert_equal new_ref, kv.ref

    stubs.put("/v0/items/#{kv.key}") do |env|
      [ 412, response_headers, {
        message: "The version of the item does not match.",
        code: "item_version_mismatch"
      }.to_json ]
    end
    assert_equal false, kv.save

    stubs.put("/v0/items/#{kv.key}") do |env|
      new_ref = make_ref
      [ 409, response_headers({"Location" => "/v0/items/#{kv.key}/refs/#{new_ref}"}), {
        message: "The item has been stored but conflicts were detected when indexing. Conflicting fields have not been indexed.",
        details: {
          conflicts: { name: { type: "string", expected: "long" } },
          conflicts_uri: "/v0/test/one/refs/f8a86a25029a907b/conflicts"
        },
        code: "indexing_conflict"
      }.to_json ]
    end
    assert_equal true, kv.save
    assert_equal new_ref, kv.ref

    stubs.put("/v0/items/#{kv.key}") do |env|
      [400, response_headers, { message: message, code: "api_bad_request" }.to_json ]
    end
    assert_equal false, kv.save

    stubs.put("/v0/items/#{kv.key}") do |env|
      [500, response_headers, '{}']
    end
    assert_equal false, kv.save
  end

  def test_save_bang_performs_put_if_match_and_raises_on_failure
  end

end

