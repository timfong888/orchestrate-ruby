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
      [204, response_headers, '']
    end

    response = @client.delete_collection({collection: @collection})
    assert_equal 204, response.header.code
    assert response.body.content.empty?
  end

  def test_lists_collection_without_params
    @stubs.get("/v0/#{@collection}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      [200, response_headers, '{"count":3, "next":"blah", "results":[]}']
    end

    response = @client.list({collection:@collection})
    assert_equal 200, response.header.code
    assert_equal 3, response.body.count
    assert response.body.results
  end

  def test_lists_collections_with_params_passes_them
    @stubs.get("/v0/#{@collection}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      assert_equal "1", env.params['limit']
      [ 200, response_headers, '{"count":1, "next":"blah", "results":[]}' ]
    end

    response = @client.list({collection:@collection, path:"?limit=1"})
    assert_equal 200, response.header.code
    assert_equal 1, response.body.count
    assert response.body.results
  end

  def test_search_with_simple_query
    # note: de-URL-encoding this is done by the rack handler
    query = "foo bar"

    @stubs.get("/v0/#{@collection}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      assert_equal query, env.params['query']
      assert_match(/query=foo\+bar/, env.url.query)
      [ 200, response_headers, '{"count":3, "results":[]}' ]
    end

    response = @client.search({collection:@collection, query:query})
    assert_equal 200, response.header.code
    assert_equal 3, response.body.count
    assert response.body.results
  end

  def test_search_with_extra_params
    query = "foo bar&offset=3"
    @stubs.get("/v0/#{@collection}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      assert_equal 'foo bar', env.params['query']
      assert_equal '3', env.params['offset']
      [ 200, response_headers, '{"count":3, "results":[]}' ]
    end

    response = @client.search({collection:@collection, query:query})
    assert_equal 200, response.header.code
    assert_equal 3, response.body.count
    assert response.body.results
  end

end
