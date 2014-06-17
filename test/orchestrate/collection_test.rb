require "test_helper"

class CollectionTest < MiniTest::Unit::TestCase

  def test_instantiates_with_app_and_name
    app, stubs = make_application
    users = Orchestrate::Collection.new(app, :users)
    assert_equal app, users.app
    assert_equal 'users', users.name
  end

  def test_instantiates_with_client_and_name
    client, stubs = make_client_and_artifacts
    stubs.head("/v0") { [200, response_headers, ''] }
    users = Orchestrate::Collection.new(client, :users)
    assert_equal client, users.app.client
    assert_equal 'users', users.name
  end

  def test_destroy
    app, stubs = make_application
    users = Orchestrate::Collection.new(app, :users)
    stubs.delete("/v0/users") do |env|
      assert_equal "true", env.params["force"]
      [204, response_headers, '']
    end
    assert true, users.destroy!
  end

  def test_kv_getter_when_present
    app, stubs = make_application
    items = Orchestrate::Collection.new(app, :items)
    body = {"hello" => "world"}
    stubs.get("/v0/items/hello") do |env|
      [200, response_headers, body]
    end
    hello = items[:hello]
    assert_kind_of Orchestrate::KeyValue, hello
  end

  def test_kv_getter_when_absent
    app, stubs = make_application
    items = Orchestrate::Collection.new(app, :items)
    stubs.get("/v0/items/absent") do |env|
      [404, response_headers, response_not_found('absent')]
    end
    assert_nil items[:absent]
  end

  def test_kv_setter
    app, stubs = make_application
    items = Orchestrate::Collection.new(app, :items)
    body = { "hello" => "world" }
    ref = nil
    stubs.put("/v0/items/newitem") do |env|
      assert_header "If-Match", nil, env
      assert_header "If-None-Match", nil, env
      assert_equal body, JSON.parse(env.body)
      ref = make_ref
      [ 201, response_headers({'Etag' => %|"#{ref}"|, 'Location' => "/v0/items/newitem/refs/#{ref}"}), '' ]
    end
    items[:newitem] = body
    assert ref
  end

  def test_set_performs_put
    app, stubs = make_application
    items = Orchestrate::Collection.new(app, :items)
    body = { "hello" => "world" }
    ref = nil
    stubs.put("/v0/items/newitem") do |env|
      assert_header "If-Match", nil, env
      assert_header "If-None-Match", nil, env
      assert_equal body, JSON.parse(env.body)
      ref = make_ref
      [ 201, response_headers({'Etag' => %|"#{ref}"|, 'Location' => "/v0/items/newitem/refs/#{ref}"}), '' ]
    end
    kv = items.set(:newitem, body)
    assert_equal ref, kv.ref
    assert_equal "newitem", kv.key
    assert_equal body, kv.value
    assert kv.loaded?
    assert_in_delta Time.now.to_f, kv.last_request_time.to_f, 1
  end

  def test_create_performs_put_if_absent
    app, stubs = make_application
    items = Orchestrate::Collection.new(app, :items)
    body = { "hello" => "world" }
    ref = nil
    stubs.put("/v0/items/newitem") do |env|
      assert_header "If-Match", nil, env
      assert_header "If-None-Match", '"*"', env
      assert_equal body, JSON.parse(env.body)
      ref = make_ref
      [ 201, response_headers({"Etag" => %|"#{ref}"|, "Location" => "/v0/items/newitem/refs/#{ref}"}), '' ]
    end
    kv = items.create(:newitem, body)
    assert_equal items, kv.collection
    assert_equal "newitem", kv.key
    assert_equal ref, kv.ref
    assert_equal body, kv.value
    assert kv.loaded?
    assert_in_delta Time.now.to_f, kv.last_request_time.to_f, 1
  end

end

