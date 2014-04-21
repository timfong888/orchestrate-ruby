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
    @stubs.get("/#{@collection}/#{@key}/relations/#{@kind}") do |env|
      assert_authorization @basic_auth, env
      [200, response_headers, '{"count":3, "results":[]}']
    end
    response = @client.get_graph({collection:@collection, key:@key, kind:@kind})
    assert_equal 200, response.status
    assert_equal 3, response.body['count']
    assert response.body['results']
  end
end
