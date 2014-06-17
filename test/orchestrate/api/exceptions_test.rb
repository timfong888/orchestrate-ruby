require_relative '../../test_helper'

class ExceptionsTest < MiniTest::Unit::TestCase
  def setup
    @client, @stubs, @basic_auth = make_client_and_artifacts
  end

  def test_raises_on_unauthroized
    @stubs.get("/v0/foo") do |env|
      assert_authorization @basic_auth, env
      error_response(:unauthorized)
    end
    assert_raises Orchestrate::API::Unauthorized do
      @client.list(:foo)
    end
  end

  def test_raises_on_bad_request
    @stubs.put("/v0/foo/bar") { error_response(:bad_request) }
    assert_raises Orchestrate::API::BadRequest do
      @client.put(:foo, "bar", {}, "'foo'")
    end
  end

  def test_raises_on_malformed_search_query
    @stubs.get("/v0/foo") { error_response(:search_query_malformed) }
    assert_raises Orchestrate::API::MalformedSearch do
      @client.search(:foo, "foo=\"no")
    end
  end

  def test_raises_on_invalid_search_param
    @stubs.get("/v0/foo") { error_response(:invalid_search_param) }
    assert_raises Orchestrate::API::InvalidSearchParam do
      @client.search(:foo, '')
    end
  end

  def test_raises_on_malformed_ref
    @stubs.put("/v0/foo/bar") { error_response(:malformed_ref) }
    assert_raises Orchestrate::API::MalformedRef do
      @client.put(:foo, "bar", {:blerg => 'blerg'}, "blerg")
    end
  end

  def test_raises_on_indexing_conflict
    @stubs.put("/v0/foo/bar") { error_response(:indexing_conflict) }
    assert_raises Orchestrate::API::IndexingConflict do
      @client.put(:foo, 'bar', {count: "foo"})
    end
  end

  def test_raises_on_version_mismatch
    @stubs.put("/v0/foo/bar") { error_response(:version_mismatch) }
    assert_raises Orchestrate::API::VersionMismatch do
      @client.put(:foo, 'bar', {foo:'bar'}, "7ae8635207acbb2f")
    end
  end

  def test_raises_on_item_already_present
    @stubs.put("/v0/foo/bar") { error_response(:already_present) }
    assert_raises Orchestrate::API::AlreadyPresent do
      @client.put_if_absent(:foo, 'bar', {foo:'bar'})
    end
  end

  def test_raises_on_unexpected_response_error
    @stubs.get("/v0/teapot/spout") do |env|
      [ 418, response_headers, {
        message: "I'm a little teapot",
        code: "teapot"
      }.to_json ]
    end
    assert_raises Orchestrate::API::RequestError do
      @client.get(:teapot, "spout")
    end
  end

  def test_raises_on_security_authentication
    @stubs.get("/v0/test/123") do |env|
      [ 500, response_headers, {
        message: "An error occurred while trying to authenticate.",
        code: "security_authentication"
      }.to_json ]
    end
    assert_raises Orchestrate::API::SecurityAuthentication do
      @client.get(:test, '123')
    end
  end

  def test_raises_on_search_index_not_found
    @stubs.get("/v0/test") do |env|
      [ 500, response_headers, {
        message: "Index could not be queried for this application.",
        code: "search_index_not_found"
      }.to_json ]
    end
    assert_raises Orchestrate::API::SearchIndexNotFound do
      @client.search(:test, '123')
    end
  end

  def test_raises_on_internal_error
    @stubs.get("/v0/test/123") do |env|
      [ 500, response_headers, {
        message: "Internal Error.",
        code: "internal_error"
      }.to_json ]
    end
    assert_raises Orchestrate::API::InternalError do
      @client.get(:test, '123')
    end
  end

  def test_raises_on_generic_500_error
    body = "The bees, they're in my eyes"
    @stubs.get("/v0/test/123") do |env|
      [ 500, {}, body ]
    end
    err = assert_raises Orchestrate::API::ServiceError do
      @client.get(:test, '123')
    end
    assert_equal body, err.message
  end
end

