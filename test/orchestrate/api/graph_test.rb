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
    body = { "count" => 0, "results" => [] }
    @stubs.get("/v0/#{@collection}/#{@key}/relations/#{@kind}/#{@kind}") do |env|
      assert_authorization @basic_auth, env
      assert_accepts_json env
      [200, response_headers, body.to_json]
    end

    response = @client.get_relations(@collection, @key, @kind, @kind)
    assert_equal 200, response.status
    assert_equal body, response.body
  end

  def test_put_graph
    @stubs.put("/v0/#{@collection}/#{@key}/relation/#{@kind}/#{@target_collection}/#{@target_key}") do |env|
      assert_authorization @basic_auth, env
      [ 204, response_headers, '' ]
    end
    response = @client.put_relation(@collection, @key, @kind, @target_collection, @target_key)
    assert_equal 204, response.status
  end

  def test_delete_graph
    @stubs.delete("/v0/#{@collection}/#{@key}/relation/#{@kind}/#{@target_collection}/#{@target_key}") do |env|
      assert_authorization @basic_auth, env
      assert_equal 'true', env.params['purge']
      [ 204, response_headers, '' ]
    end
    response = @client.delete_relation(@collection, @key, @kind, @target_collection, @target_key)
    assert_equal 204, response.status
  end
end
