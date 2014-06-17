require "test_helper"

class CollectionEnumerationTest < MiniTest::Unit::TestCase

  def make_kv_listing(collection, key)
    { "path" => { "collection" => collection, "key" => key, "ref" => make_ref },
      "reftime" => Time.now.to_f - (rand(24) * 3600 * 1000),
      "value" => {"key" => "value_#{key}_"}
    }
  end

  def test_enumerates_over_all
    app, stubs = make_application
    stubs.get("/v0/items") do |env|
      body = case env.params['afterKey']
      when nil
        { "results" => 10.times.map {|x| make_kv_listing(:items, "key-#{x}") },
          "next" => "/v0/items?afterKey=key-9", "count" => 10 }
      when 'key-9'
        { "results" => 4.times.map {|x| make_kv_listing(:items, "key-#{10+x}")},
          "count" => 4 }
      else
        raise ArgumentError.new("unexpected afterKey: #{env.params['afterKey']}")
      end
      [ 200, response_headers, body.to_json ]
    end
    items = app[:items].map {|doc| doc }
    assert_equal 14, items.length
  end

end

