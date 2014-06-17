require "test_helper"

class KeyValueTest < MiniTest::Unit::TestCase
  def test_load_with_collection_and_key
    app, stubs = make_application
    items = app[:items]
    ref = "123456"
    body = {"hello" => "world"}
    res_headers = response_headers({
      'Etag' => "\"#{ref}\"",
      'Content-Location' => "/v0/items/hello/refs/#{ref}"
    })
    stubs.get('/v0/items/hello') {|env| [200, res_headers, body.to_json] }
    kv = Orchestrate::KeyValue.load(items, :hello)
    assert_equal "hello", kv.key
    assert_equal ref, kv.ref
    assert_equal "items/hello", kv.id
  end
end

