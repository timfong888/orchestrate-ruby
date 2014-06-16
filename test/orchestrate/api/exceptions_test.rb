require_relative '../../test_helper'

class ExceptionsTest < MiniTest::Unit::TestCase
  def setup
    @client, @stubs, @basic_auth = make_client_and_artifacts
  end

  def test_raises_on_unauthroized
    @stubs.get("/v0/foo") do |env|
      assert_authorization @basic_auth, env
      [ 401, response_headers, {
        "message" => "Valid credentials are required.",
        "code" => "security_unauthorized"
      }.to_json ]
    end
    assert_raises Orchestrate::API::Unauthorized do
      @client.list(:foo)
    end
  end

  def test_raises_on_bad_request
    message = "Invalid value for header 'If-Match'."
    @stubs.put("/v0/foo/bar") do |env|
      [400, response_headers, {
        message: message,
        code: "api_bad_request"
      }.to_json ]
    end
    err = assert_raises Orchestrate::API::BadRequest do
      @client.put(:foo, "bar", {}, "'foo'")
    end
    assert_equal message, err.message
  end

  def test_raises_on_malformed_search_query
    @stubs.get("/v0/foo") do |env|
      [ 400, response_headers, {
        message: "The search query provided is invalid.",
        code: "search_query_malformed"
      }.to_json ]
    end
    assert_raises Orchestrate::API::MalformedSearch do
      @client.search(:foo, "foo=\"no")
    end
  end

  def test_raises_on_invalid_search_param
    @stubs.get("/v0/foo") do |env|
      [ 400, response_headers, {
        message: "A provided search query param is invalid.",
        details: { query: "Query is empty." },
        code: "search_param_invalid"
      }.to_json ]
    end
    assert_raises Orchestrate::API::InvalidSearchParam do
      @client.search(:foo, '')
    end
  end

  def test_raises_on_malformed_ref
    @stubs.put("/v0/foo/bar") do |env|
      [ 400, response_headers, {
        message: "The provided Item Ref is malformed.",
        details: { ref: "blerg" },
        code: "item_ref_malformed"
      }.to_json ]
    end
    assert_raises Orchestrate::API::MalformedRef do
      @client.put(:foo, "bar", {:blerg => 'blerg'}, "blerg")
    end
  end

  def test_raises_on_indexing_conflict
    @stubs.put("/v0/foo/bar") do |env|
      [ 409, response_headers, {
        message: "The item has been stored but conflicts were detected when indexing. Conflicting fields have not been indexed.",
        details: {
          conflicts: { name: { type: "string", expected: "long" } },
          conflicts_uri: "/v0/test/one/refs/f8a86a25029a907b/conflicts"
        },
        code: "indexing_conflict"
      }.to_json ]
    end
    assert_raises Orchestrate::API::IndexingConflict do
      @client.put(:foo, 'bar', {count: "foo"})
    end
  end

  def test_raises_on_version_mismatch
    @stubs.put("/v0/foo/bar") do |env|
      [ 412, response_headers, {
        message: "The version of the item does not match.",
        code: "item_version_mismatch"
      }.to_json ]
    end
    assert_raises Orchestrate::API::VersionMismatch do
      @client.put(:foo, 'bar', {foo:'bar'}, "7ae8635207acbb2f")
    end
  end

  def test_raises_on_item_already_present
    @stubs.put("/v0/foo/bar") do |env|
      [ 412, response_headers, {
        message: "The item is already present.",
        code: "item_already_present"
      }.to_json ]
    end
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

