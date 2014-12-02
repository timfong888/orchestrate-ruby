require_relative "../../test_helper"

class KeyValueAPITest < MiniTest::Unit::TestCase
  def setup
    @collection = 'test'
    @key = 'keyname'
    @client, @stubs, @basic_auth = make_client_and_artifacts
  end

  def test_gets_current_value_for_key_when_exists
    ref = SecureRandom.hex(16)
    ref_url = "/v0/#{@collection}/#{@key}/refs/#{ref}"
    body = { "key" => "value" }
    @stubs.get("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      headers = {
        'Content-Location' => ref_url,
        'ETag' => "\"#{ref}-gzip\"",
      }.merge(chunked_encoding_header)
      [ 200, response_headers(headers), body.to_json]
    end

    response = @client.get(@collection, @key)
    assert_equal 200, response.status
    assert_equal body, response.body

    assert_equal "\"#{ref}-gzip\"", response.headers['Etag']
    assert_equal ref_url, response.headers['Content-Location']

    assert_equal ref_url, response.location
    assert_equal ref, response.ref
    assert_equal Time.parse(response.headers['Date']), response.request_time
    assert_equal response.headers['X-Orchestrate-Req-Id'], response.request_id
  end

  def test_gets_key_value_is_404_when_does_not_exist
    @stubs.get("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      [ 404, response_headers(), response_not_found({collection:@collection, key:@key}) ]
    end

    assert_raises Orchestrate::API::NotFound do
      @client.get(@collection, @key)
    end
  end

  def test_posts_key_value
    body = {"foo" => "bar"}
    ref = "12345"
    key = "567890ac"
    @stubs.post("/v0/#{@collection}") do |env|
      assert_authorization @basic_auth, env
      assert_header 'Content-Type', 'application/json', env
      assert_equal body.to_json, env.body
      headers = { "Location" => "/v0/#{@collection}/#{key}/refs/#{ref}", "Etag" => "\"#{ref}\"" }
      [ 201, response_headers(headers), '' ]
    end
    response = @client.post(@collection, body)
    assert_equal 201, response.status
    assert_equal ref, response.ref
    assert_equal "/v0/#{@collection}/#{key}/refs/#{ref}", response.location
  end

  def test_puts_key_value_without_ref
    body = {"foo" => "bar"}
    ref = "12345"
    base_location = "/v0/#{@collection}/#{@key}"
    @stubs.put(base_location) do |env|
      assert_authorization @basic_auth, env
      assert_header 'Content-Type', 'application/json', env
      assert_equal body.to_json, env.body
      headers = { "Location" => "#{base_location}/refs/#{ref}", 
                  "Etag" => "\"#{ref}\"" }
      [ 201, response_headers(headers), '' ]
    end

    response = @client.put(@collection, @key, body)
    assert_equal 201, response.status
    assert_equal ref, response.ref
    assert_equal "#{base_location}/refs/#{ref}", response.location
  end

  def test_puts_key_value_with_specific_ref
    body = {"foo" => "bar"}
    ref = '123456'

    @stubs.put("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-Match', "\"#{ref}\"", env
      assert_header 'Content-Type', 'application/json', env
      assert_equal body.to_json, env.body
      [ 200, response_headers, '' ]
    end

    response = @client.put(@collection, @key, body, ref)
    assert_equal 200, response.status
  end

  def test_puts_key_value_if_unmodified
    body = {"foo" => "bar"}
    ref = '123456'

    @stubs.put("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-Match', "\"#{ref}\"", env
      assert_header 'Content-Type', 'application/json', env
      assert_equal body.to_json, env.body
      [ 200, response_headers, '' ]
    end

    response = @client.put_if_unmodified(@collection, @key, body, ref)
    assert_equal 200, response.status
  end

  def test_puts_key_value_with_inspecific_ref
    body = {"foo" => "bar"}

    @stubs.put("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-None-Match', '"*"', env
      assert_header 'Content-Type', 'application/json', env
      assert_equal body.to_json, env.body
      [ 200, response_headers, '' ]
    end

    response = @client.put(@collection, @key, body, false)
    assert_equal 200, response.status
  end

  def test_puts_key_value_if_absent
    body = {"foo" => "bar"}
    @stubs.put("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-None-Match', '"*"', env
      assert_header 'Content-Type', 'application/json', env
      assert_equal body.to_json, env.body
      [ 200, response_headers, '' ]
    end

    response = @client.put_if_absent(@collection, @key, body)
    assert_equal 200, response.status
  end

  def test_patches_key_value_without_ref
    body =[ {"op" => "add", "path" => "foo", "value" => "bar"} ]
    ref = "12345"
    base_location = "/v0/#{@collection}/#{@key}"
    @stubs.patch(base_location) do |env|
      assert_authorization @basic_auth, env
      assert_header 'Content-Type', 'application/json-patch+json', env
      assert_equal body.to_json, env.body
      headers = { "Location" => "#{base_location}/refs/#{ref}", 
                  "Etag" => "\"#{ref}\"" }
      [ 201, response_headers(headers), '' ]
    end

    response = @client.patch(@collection, @key, body)
    assert_equal 201, response.status
    assert_equal ref, response.ref
    assert_equal "#{base_location}/refs/#{ref}", response.location
  end

  def test_patches_key_value_with_specific_ref
    body = [ {"op" => "add", "path" => "foo", "value" => "bar"} ]
    ref = '123456'

    @stubs.patch("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-Match', "\"#{ref}\"", env
      assert_header 'Content-Type', 'application/json-patch+json', env
      assert_equal body.to_json, env.body
      [ 201, response_headers, '' ]
    end

    response = @client.patch(@collection, @key, body, ref)
    assert_equal 201, response.status
  end

  def test_patch_merges_key_value_without_ref
    body = {"foo" => "bar"}
    ref = "12345"
    base_location = "/v0/#{@collection}/#{@key}"
    @stubs.patch(base_location) do |env|
      assert_authorization @basic_auth, env
      assert_header 'Content-Type', 'application/merge-patch+json', env
      assert_equal body.to_json, env.body
      headers = { "Location" => "#{base_location}/refs/#{ref}", 
                  "Etag" => "\"#{ref}\"" }
      [ 201, response_headers(headers), '' ]
    end

    response = @client.patch_merge(@collection, @key, body)
    assert_equal 201, response.status
    assert_equal ref, response.ref
    assert_equal "#{base_location}/refs/#{ref}", response.location
  end

  def test_patch_merges_key_value_with_specific_ref
    body = {"foo" => "bar"}
    ref = '123456'

    @stubs.patch("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-Match', "\"#{ref}\"", env
      assert_header 'Content-Type', 'application/merge-patch+json', env
      assert_equal body.to_json, env.body
      [ 201, response_headers, '' ]
    end

    response = @client.patch_merge(@collection, @key, body, ref)
    assert_equal 201, response.status
  end

  def test_delete_key_value
    @stubs.delete("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      [ 204, response_headers, '' ]
    end
    response = @client.delete(@collection, @key)
    assert_equal 204, response.status
    assert_equal response.headers['X-Orchestrate-Req-Id'], response.request_id
  end

  def test_delete_key_value_with_condition
    ref="12345"
    @stubs.delete("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-Match', "\"#{ref}\"", env
      [ 204, response_headers, '' ]
    end
    response = @client.delete(@collection, @key, ref)
    assert_equal 204, response.status
  end

  def test_delete_key_value_with_quoted_condition
    ref='"12345"'
    @stubs.delete("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-Match', ref, env
      [ 204, response_headers, '' ]
    end
    response = @client.delete(@collection, @key, ref)
    assert_equal 204, response.status
  end

  def test_delete_key_value_with_purge
    @stubs.delete("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_equal "true", env.params["purge"]
      [ 204, response_headers, '' ]
    end
    response = @client.purge(@collection, @key)
    assert_equal 204, response.status
    assert_equal response.headers['X-Orchestrate-Req-Id'], response.request_id
  end

  def test_delete_key_value_with_purge_and_condition
    ref = "12345"
    @stubs.delete("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_equal "true", env.params["purge"]
      assert_header 'If-Match', "\"#{ref}\"", env
      [ 204, response_headers, '' ]
    end
    response = @client.purge(@collection, @key, ref)
    assert_equal 204, response.status
  end

  def test_gets_ref
    body = {"key" => "value"}
    ref = '123456'
    ref_url = "/v0/#{@collection}/#{@key}/refs/#{ref}"
    @stubs.get(ref_url) do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      headers = {
        'Content-Location' => ref_url,
        'Etag' => "\"#{ref}\""
      }
      [ 200, response_headers(headers), body.to_json ]
    end

    response = @client.get(@collection, @key, ref)
    assert_equal 200, response.status
    assert_equal body, response.body

    assert_equal ref_url, response.location
    assert_equal ref, response.ref
    assert_equal Time.parse(response.headers['Date']), response.request_time
    assert_equal response.headers['X-Orchestrate-Req-Id'], response.request_id
  end

  def test_list_refs
    reflist = (1..3).map do |i|
      { "path" => {}, "reftime" => Time.now.to_i - (-2 * i * 3600 * 1000) }
    end
    body = { "results" => reflist, "count" => 3, "prev" => "__PREV__" }

    @stubs.get("/v0/#{@collection}/#{@key}/refs") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      assert_equal "10", env.params['offset']
      [ 200, response_headers, body.to_json ]
    end

    response = @client.list_refs(@collection, @key, {offset: 10})
    assert_equal 200, response.status
    assert_equal body, response.body
    assert_equal body['count'], response.count
    assert_equal body['results'], response.results
    assert_equal body['prev'], response.prev_link
    assert_nil response.next_link
  end

end
