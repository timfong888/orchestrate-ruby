require "test_helper"

class RelationsTest < MiniTest::Unit::TestCase

  def setup
    @app, @stubs = make_application
    @items = @app[:items]
    @kv = make_kv_item(@items, @stubs)
    @other_kv = make_kv_item(@items, @stubs)
    @relation_type = :siblings
  end

  def test_adds_relation_with_kv
    path = ['items', @kv.key, 'relation', @relation_type, :items, @other_kv.key]
    @stubs.put("/v0/#{path.join('/')}") { [ 204, response_headers, '' ] }
    @kv.relations[@relation_type] << @other_kv
    @stubs.verify_stubbed_calls
  end

  def test_adds_from_collname_and_keyname
    path = ['items', @kv.key, 'relation', @relation_type, :items, @other_kv.key]
    @stubs.put("/v0/#{path.join('/')}") { [ 204, response_headers, '' ] }
    @kv.relations[@relation_type].push(:items, @other_kv.key)
    @stubs.verify_stubbed_calls
  end

end

