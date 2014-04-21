require_relative '../../test_helper'

class CollectionTest < MiniTest::Unit::TestCase
  def setup
    @collection = 'test'
    @client, @stubs, @basic_auth = make_client_and_artifacts
  end

  def test_deletes_collection
    @stubs.delete("/#{@collection}") do |env|
      assert_authorization @basic_auth, env
      assert_equal "true", env.params["force"]
      [204, response_headers, []]
    end

    response = @client.delete_collection({collection: @collection})
    assert_equal 204, response.status
    assert response.body.empty?
  end

  def test_lists_collection_without_params
    @stubs.get("/#{@collection}") do |env|
      assert_authorization @basic_auth, env
      [200, response_headers, '{"count":3, "next":"blah", "results":[]}']
    end

    response = @client.list({collection:@collection})
    assert_equal 200, response.status
    assert_equal 3, response.body['count']
    assert response.body['results']
  end

  def test_lists_collections_with_params_passes_them
    @stubs.get("/#{@collection}") do |env|
      assert_authorization @basic_auth, env
      assert_equal "1", env.params['limit']
      [ 200, response_headers, '{"count":1, "next":"blah", "results":[]}' ]
    end

    response = @client.list({collection:@collection, path:"?limit=1"})
    assert_equal 200, response.status
    assert_equal 1, response.body['count']
    assert response.body['results']
  end

end
