require "test_helper"

class RefTest < MiniTest::Unit::TestCase
  def setup
    @app, @stubs = make_application
    @kv = make_kv_item(@app[:items], @stubs)
  end

  def test_retrieves_single_ref
    ref = make_ref
    path = "/v0/items/#{@kv.key}/refs/#{ref}"
    value = {"hello" => "history"}
    @stubs.get(path) do |env|
      [ 200, response_headers({'Etag' => "\"ref\"", "Content-Location" => path}), value.to_json]
    end
    ref_value = @kv.refs[ref]
    assert ref_value.archival?
    refute ref_value.tombstone?
    assert_equal value, ref_value.value
  end
end
