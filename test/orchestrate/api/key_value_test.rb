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
    @stubs.get("/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      headers = {
        'Content-Location' => ref_url,
        'ETag' => ref
      }.merge(chunked_encoding_header)
      [ 200, response_headers(headers), '{}' ]
    end

    response = @client.get_key({collection:@collection, key:@key})
    assert_equal 200, response.status
    assert_equal '{}', response.body

    assert_equal ref, response.headers['ETag']
    assert_equal ref_url, response.headers['Content-Location']
    assert_equal 'chunked', response.headers['transfer-encoding']
  end
end
