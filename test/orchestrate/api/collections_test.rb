require_relative '../../test_helper'

class CollectionTest < MiniTest::Unit::TestCase
  def setup
    @collection = 'test'
    @client, @stubs, @basic_auth = make_client_and_artifacts
  end

  def test_deletes_collection
    @stubs.delete("/v0/#{@collection}") do |env|
      assert_authorization @basic_auth, env
      assert_equal "true", env.params["force"]
      headers = response_headers
      headers.delete('Content-Type')
      [204, headers, '']
    end

    response = @client.delete_collection(@collection)
    assert_equal 204, response.status
    assert_equal '', response.body
    assert_equal response.headers['X-Orchestrate-Req-Id'], response.request_id
  end

  def test_lists_collection_without_params
    body = {"count" => 1, "results" => [
      { "value" => {"value" => "one"}, "path" => {}, "reftime" => "" }
    ], "next" => "/v0/#{@collection}?afterKey=one"}

    @stubs.get("/v0/#{@collection}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      [200, response_headers, body.to_json]
    end

    response = @client.list(@collection)
    assert_equal 200, response.status
    assert_equal body, response.body
    assert_equal response.headers['X-Orchestrate-Req-Id'], response.request_id
    assert_equal body['count'], response.count
    assert_equal body['results'], response.results
    assert_equal body['next'], response.next_link
  end

  def test_lists_collections_with_params_passes_them
    body = {"count" => 0, "results" => []}
    @stubs.get("/v0/#{@collection}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      assert_equal "1", env.params['limit']
      assert_equal "foo", env.params['startKey']
      assert_equal ['limit', 'startKey'], env.params.keys
      [ 200, response_headers, body.to_json]
    end

    response = @client.list(@collection, {limit:1, start: 'foo'})
    assert_equal 200, response.status
    assert_equal body, response.body
    assert_nil response.next_link
  end

  def test_search_with_simple_query
    query = 'text:"The Right Way" and go'
    body = {  "count" => 1, "total_count" => 1,
              "results" => [{"path" => {}, "score" => 0.5 }] }

    @stubs.get("/v0/#{@collection}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      assert_equal query, env.params['query']
      [ 200, response_headers, body.to_json]
    end

    response = @client.search(@collection, query)
    assert_equal 200, response.status
    assert_equal body, response.body
    assert_equal body['count'], response.count
    assert_equal body['total_count'], response.total_count
    assert_equal body['results'], response.results
    assert_nil response.next_link
    assert_nil response.prev_link
  end

  def test_search_with_extra_params
    query = 'text:"The Right Way" and go'
    body = { "results" => [{"value" => {}, "path" => {}, "score" => 0.5}],
             "count" => 1, "total_count" => 10,
             "next" => "/v0/#{@collection}?limit=1&offset=4&query=__query__",
             "prev" => "/v0/#{@collection}?limit=1&offset=2&query=__query__" }

    @stubs.get("/v0/#{@collection}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      assert_equal query, env.params['query']
      assert_equal '3', env.params['offset']
      assert_equal '1', env.params['limit']
      [ 200, response_headers, body.to_json]
    end

    response = @client.search(@collection, query, {offset: 3, limit: 1})
    assert_equal 200, response.status
    assert_equal body, response.body
    assert_equal body['results'], response.results
    assert_equal body['count'], response.count
    assert_equal body['total_count'], response.total_count
    assert_equal body['next'], response.next_link
    assert_equal body['prev'], response.prev_link
  end

end
