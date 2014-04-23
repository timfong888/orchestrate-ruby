require_relative '../../test_helper'

class GraphTest < MiniTest::Unit::TestCase
  def setup
    @collection = 'tests'
    @key = 'instance'
    @kind = 'link'
    @client, @stubs, @basic_auth = make_client_and_artifacts
    @target_collection = 'bucket'
    @target_key = 'vez'
  end

  def test_get_graph
    @stubs.get("/v0/#{@collection}/#{@key}/relations/#{@kind}") do |env|
      assert_authorization @basic_auth, env
      [200, response_headers, '{"count":3, "results":[]}']
    end
    response = @client.get_graph({collection:@collection, key:@key, kind:@kind})
    assert_equal 200, response.status
    assert_equal 3, response.body['count']
    assert response.body['results']
  end

  def test_put_graph
    @stubs.put("/v0/#{@collection}/#{@key}/relation/#{@kind}/#{@target_collection}/#{@target_key}") do |env|
      assert_authorization @basic_auth, env
      [ 204, response_headers, '' ]
    end
    response = @client.put_graph({collection:@collection, key:@key, kind:@kind, to_collection:@target_collection, to_key:@target_key})
    assert_equal 204, response.status
  end

  def test_delete_graph
    @stubs.delete("/v0/#{@collection}/#{@key}/relation/#{@kind}/#{@target_collection}/#{@target_key}") do |env|
      assert_authorization @basic_auth, env
      assert_equal 'true', env.params['purge']
      [ 204, response_headers, '' ]
    end
    response = @client.delete_graph({collection:@collection, key:@key, kind:@kind, to_collection:@target_collection, to_key:@target_key})
    assert_equal 204, response.status
  end
end
