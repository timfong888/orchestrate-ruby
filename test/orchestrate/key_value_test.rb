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

    stubs.put("/v0/items/#{kv.key}") { error_response(:version_mismatch) }
    assert_equal false, kv.save

    stubs.put("/v0/items/#{kv.key}") do |env|
      new_ref = make_ref
      error_response(:indexing_conflict, {
        headers: {"Location" => "/v0/items/#{kv.key}/refs/#{new_ref}"},
        conflicts_uri: "/v0/items/#{kv.key}/refs/#{new_ref}/conflicts"
      })
    end
    assert_equal true, kv.save
    assert_equal new_ref, kv.ref

    stubs.put("/v0/items/#{kv.key}") { error_response(:bad_request) }
    assert_equal false, kv.save

    stubs.put("/v0/items/#{kv.key}") { error_response(:service_error) }
    assert_equal false, kv.save
  end

  def test_save_bang_performs_put_if_match_and_raises_on_failure
    app, stubs = make_application
    items = app[:items]
    kv = make_kv_item(items, stubs)
    kv[:foo] = "bar"
    ref = kv.ref
    stubs.put("/v0/items/#{kv.key}") do |env|
      assert_equal kv.value, JSON.parse(env.body)
      ref = make_ref
      [201, response_headers({'Etag'=>%|"#{ref}"|, 'Loation'=>"/v0/items/#{kv.key}/refs/#{ref}"}), '']
    end
    kv.save!
    assert_equal ref, kv.ref

    stubs.put("/v0/items/#{kv.key}") { error_response(:version_mismatch) }
    assert_raises Orchestrate::API::VersionMismatch do
      kv.save!
    end

    stubs.put("/v0/items/#{kv.key}") do |env|
      ref = make_ref
      error_response(:indexing_conflict, {
        headers: {"Location" => "/v0/items/#{kv.key}/refs/#{ref}"},
        conflicts_uri: "/v0/items/#{kv.key}/refs/#{ref}/conflicts"
      })
    end
    kv.save!
    assert_equal ref, kv.ref

    stubs.put("/v0/items/#{kv.key}") { error_response(:bad_request) }
    assert_raises Orchestrate::API::BadRequest do
      kv.save!
    end

    stubs.put("/v0/items/#{kv.key}") { error_response(:service_error) }
    assert_raises Orchestrate::API::ServiceError do
      kv.save!
    end
  end

end

