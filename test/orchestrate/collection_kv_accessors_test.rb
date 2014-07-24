require "test_helper"

class Collection_KV_Accessors_Test < MiniTest::Unit::TestCase
  def setup
    @app, @stubs = make_application
    @items = @app[:items]
  end

  def test_kv_getter_when_present
    body = {"hello" => "world"}
    @stubs.get("/v0/items/hello") do |env|
      [200, response_headers, body.to_json]
    end
    hello = @items[:hello]
    assert_kind_of Orchestrate::KeyValue, hello
  end

  def test_kv_getter_when_absent
    @stubs.get("/v0/items/absent") do |env|
      [404, response_headers, response_not_found('absent')]
    end
    assert_nil @items[:absent]
  end

  def test_kv_builder
    body = {"hello" => "nothing"}
    kv = @items.build(:absent, body)
    assert_equal 'absent', kv.key
    assert_equal body, kv.value
    assert_equal false, kv.ref
  end

  def test_kv_stubber
    kv = @items.stub(:hello)
    assert_equal 'hello', kv.key
    assert_equal false, kv.ref
    assert_nil kv.value
    refute kv.loaded?
  end

  def test_kv_setter
    body = { "hello" => "world" }
    ref = nil
    @stubs.put("/v0/items/newitem") do |env|
      assert_header "If-Match", nil, env
      assert_header "If-None-Match", nil, env
      assert_equal body, JSON.parse(env.body)
      ref = make_ref
      [ 201, response_headers({'Etag' => %|"#{ref}"|, 'Location' => "/v0/items/newitem/refs/#{ref}"}), '' ]
    end
    @items[:newitem] = body
    assert ref
  end

  def test_set_performs_put
    body = { "hello" => "world" }
    ref = nil
    @stubs.put("/v0/items/newitem") do |env|
      assert_header "If-Match", nil, env
      assert_header "If-None-Match", nil, env
      assert_equal body, JSON.parse(env.body)
      ref = make_ref
      [ 201, response_headers({'Etag' => %|"#{ref}"|, 'Location' => "/v0/items/newitem/refs/#{ref}"}), '' ]
    end
    kv = @items.set(:newitem, body)
    assert_equal ref, kv.ref
    assert_equal "newitem", kv.key
    assert_equal body, kv.value
    assert kv.loaded?
    assert_in_delta Time.now.to_f, kv.last_request_time.to_f, 1.1
  end

  def test_append_operator_performs_post
    body = { "hello" => "world" }
    key = nil
    ref = nil
    @stubs.post("/v0/items") do |env|
      assert_header 'Content-Type', 'application/json', env
      assert_equal body, JSON.parse(env.body)
      ref = make_ref
      key = SecureRandom.hex(16)
      [ 201, response_headers({
        'Etag' => %|"#{ref}"|, "Location" => "/v0/items/#{key}/refs/#{ref}"
      }), '' ]
    end
    kv = @items << body
    assert kv
    assert_equal key, kv.key
    assert_equal ref, kv.ref
    assert_equal body, kv.value
    assert kv.loaded?
    assert_in_delta Time.now.to_f, kv.last_request_time.to_f, 1.1
  end

  def test_create_performs_post_with_one_arg
    body = { "hello" => "world" }
    key = nil
    ref = nil
    @stubs.post("/v0/items") do |env|
      assert_header 'Content-Type', 'application/json', env
      assert_equal body, JSON.parse(env.body)
      ref = make_ref
      key = SecureRandom.hex(16)
      [ 201, response_headers({
        'Etag' => %|"#{ref}"|, "Location" => "/v0/items/#{key}/refs/#{ref}"
      }), '' ]
    end
    kv = @items.create(body)
    assert kv
    assert_equal key, kv.key
    assert_equal ref, kv.ref
    assert_equal body, kv.value
    assert kv.loaded?
    assert_in_delta Time.now.to_f, kv.last_request_time.to_f, 1.1
  end

  def test_create_performs_put_if_absent_with_two_args
    body = { "hello" => "world" }
    ref = nil
    @stubs.put("/v0/items/newitem") do |env|
      assert_header "If-Match", nil, env
      assert_header "If-None-Match", '"*"', env
      assert_equal body, JSON.parse(env.body)
      ref = make_ref
      [ 201, response_headers({"Etag" => %|"#{ref}"|, "Location" => "/v0/items/newitem/refs/#{ref}"}), '' ]
    end
    kv = @items.create(:newitem, body)
    assert_equal @items, kv.collection
    assert_equal "newitem", kv.key
    assert_equal ref, kv.ref
    assert_equal body, kv.value
    assert kv.loaded?
    assert_in_delta Time.now.to_f, kv.last_request_time.to_f, 1.1
  end

  def test_create_performs_put_if_absent_with_two_args_returns_false_on_already_exists
    @stubs.put("/v0/items/newitem") do |env|
      assert_header "If-Match", nil, env
      assert_header "If-None-Match", '"*"', env
      error_response(:already_present)
    end
    assert_equal false, @items.create(:newitem, {"hello" => "world"})
  end

  def test_delete_performs_delete
    @stubs.delete("/v0/items/olditem") do |env|
      assert_nil env.params['purge']
      [ 204, response_headers, '' ]
    end
    assert_equal true, @items.delete(:olditem)
  end

  def test_purge_performs_purge
    @stubs.delete("/v0/items/olditem") do |env|
      assert_equal "true", env.params['purge']
      [ 204, response_headers, '' ]
    end
    assert_equal true, @items.purge(:olditem)
  end
end

