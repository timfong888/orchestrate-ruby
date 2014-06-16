require_relative '../../test_helper'

class ResponseTest < MiniTest::Unit::TestCase

  def setup
    @client, @stubs, @basic_auth = make_client_and_artifacts
  end

  def test_collection_with_next_prev_link
    @stubs.get("/v0/things") do |env|
      assert_authorization @basic_auth, env
      case env.params['offset']
      when nil, '0'
        nextLink = "/v0/things?offset=10"
        [ 200, response_headers, { count: 14, next: nextLink, results: [] }.to_json ]
      when '10'
        prevLink = "/v0/things?offset=0"
        [ 200, response_headers, { count: 14, prev: prevLink, results: [] }.to_json ]
      else
        [ 404, response_headers, '{}' ]
      end
    end
    response = @client.list(:things)
    assert response.next_link

    next_page = response.next_results
    assert_equal 200, next_page.status
    assert_equal 14, next_page.count
    assert_nil next_page.next_results

    previous_page = next_page.previous_results
    assert_equal 200, previous_page.status
    assert_equal 14, previous_page.count
    assert_nil previous_page.previous_results
  end
end
