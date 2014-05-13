require_relative "../../test_helper"

class KeyValueTest < MiniTest::Unit::TestCase
  def setup
    @collection = 'test'
    @key = 'keyname'
    @client, @stubs, @basic_auth = make_client_and_artifacts
  end

  def test_gets_current_value_for_key_when_exists
    ref = SecureRandom.hex(16)
    ref_url = "/v0/#{@collection}/#{@key}/refs/#{ref}"
    body = '{"key":"value"}' 
    @stubs.get("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      headers = {
        'Content-Location' => ref_url,
        'ETag' => "\"#{ref}\"",
      }.merge(chunked_encoding_header)
      [ 200, response_headers(headers), body]
    end

    response = @client.get(@collection, @key)
    assert_equal 200, response.header.code
    assert_equal body, response.body.content

    assert_equal "\"#{ref}\"", response.header.etag
    assert_equal ref_url, response.header.content['Content-Location']
  end

  def test_gets_key_value_is_404_when_does_not_exist
    @stubs.get("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      [ 404, response_headers(), response_not_found({collection:@collection, key:@key}) ]
    end

    response = @client.get(@collection, @key)
    assert_equal 404, response.header.code
    assert_equal 'items_not_found', response.body.code
  end

  def test_puts_key_value_without_ref
    body='{"foo":"bar"}'
    @stubs.put("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_header 'Content-Type', 'application/json', env
      assert_equal body, env.body
      [ 201, response_headers, '' ]
    end

    response = @client.put(@collection, @key, body)
    assert_equal 201, response.header.code
  end

  def test_puts_key_value_with_specific_ref
    body = '{"foo":"bar"}'
    ref = '123456'

    @stubs.put("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-Match', ref, env
      assert_header 'Content-Type', 'application/json', env
      assert_equal body, env.body
      [ 200, response_headers, '' ]
    end

    response = @client.put(@collection, @key, body, ref)
    assert_equal 200, response.header.code
  end

  def test_puts_key_value_with_inspecific_ref
    body = '{"foo":"bar"}'

    @stubs.put("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-None-Match', '*', env
      assert_header 'Content-Type', 'application/json', env
      assert_equal body, env.body
      [ 200, response_headers, '' ]
    end

    response = @client.put(@collection, @key, body, false)
    assert_equal 200, response.header.code
  end

  def test_delete_key_value
    @stubs.delete("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      [ 204, response_headers, '' ]
    end
    response = @client.delete(@collection, @key)
    assert_equal 204, response.header.code
  end

  def test_delete_key_value_with_condition
    ref='"12345"'
    @stubs.delete("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-Match', ref, env
      [ 204, response_headers, '' ]
    end
    response = @client.delete(@collection, @key, ref)
    assert_equal 204, response.header.code
  end

  def test_delete_key_value_with_purge
    @stubs.delete("/v0/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_equal "true", env.params["purge"]
      [ 204, response_headers, '' ]
    end
    response = @client.purge_key({collection:@collection, key:@key})
    assert_equal 204, response.header.code
  end

  def test_gets_ref
    ref = '123456'
    @stubs.get("/v0/#{@collection}/#{@key}/refs/#{ref}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      [ 200, response_headers, '' ]
    end

    response = @client.get_by_ref({collection:@collection, key:@key, ref:ref})
    assert_equal 200, response.header.code
  end

end
