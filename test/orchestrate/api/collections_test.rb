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

end
