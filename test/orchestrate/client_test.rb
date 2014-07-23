require "test_helper"
require 'thread'

class ClientTest < MiniTest::Unit::TestCase

  def test_initialization
    client = Orchestrate::Client.new('8c3')
    assert_equal '8c3', client.api_key
  end

  def test_parallelism
    thing_body = {"foo" => "bar"}
    list_body = {"count" => 1, "results" => [{"value"=>{"a" => "b"}, "path" => {}, "reftime" => ""}] }
    client, stubs = make_client_and_artifacts(true)
    stubs.get("/v0/foo") do |env|
      [ 200, response_headers, list_body.to_json ]
    end
    stubs.get("/v0/things/foo") do |env|
      [ 200, response_headers, thing_body.to_json ]
    end
    responses = nil
    responses = client.in_parallel do |r|
      r[:list] = client.list(:foo)
      r[:thing] = client.get(:things, "foo")
    end
    assert responses[:list]
    assert_equal 200, responses[:list].status
    assert_equal list_body, responses[:list].body
    assert responses[:thing]
    assert_equal 200, responses[:thing].status
    assert_equal thing_body, responses[:thing].body
  end

  def test_parallelism_uses_own_client
    waiting = false
    client, stubs = make_client_and_artifacts(true)
    stubs.get("/v0/foo") do |env|
      [ 200, response_headers, {"count" => 1, "results" => [{"value" => {"a" => "a"}}]}.to_json ]
    end
    parallel_getter = lambda do |c|
      resp = c.in_parallel do |r|
        sleep 1 if waiting
        r[:list] = c.list(:foo)
        assert_nil r[:list].body
      end
      assert resp[:list].body
      assert_equal 1, resp[:list].results.length
      resp[:list].results
    end
    single_getter = lambda do |c|
      resp = c.list(:foo)
      assert_equal 1, resp.results.length
      resp.results
    end
    parallel_getter.call(client)
    single_getter.call(client)

    waiting = true
    [parallel_getter, single_getter].map do |t|
      Thread.new(client, &t)
    end.each(&:join)
  end

  def test_ping_request_success
    client, stubs = make_client_and_artifacts
    stubs.head("/v0") do |env|
      [ 200, response_headers, '' ]
    end
    client.ping
  end

  def test_ping_request_unauthorized
    client, stubs = make_client_and_artifacts
    headers = response_headers
    stubs.head("/v0") { [ 401, headers, '' ] }
    assert_raises Orchestrate::API::Unauthorized do
      client.ping
    end
  end

end
