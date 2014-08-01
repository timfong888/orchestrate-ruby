require "test_helper"

class RefTest < MiniTest::Unit::TestCase
  def setup
    @app, @stubs = make_application({parallel: true})
    @kv = make_kv_item(@app[:items], @stubs)
    @limit_to_assert = "100"
    @called = false
    @wants_values = false
    @stubs.get("/v0/items/#{@kv.key}/refs") do |env|
      @called = true
      if @wants_values
        assert_equal("true", env.params['values'])
      else
        assert_nil env.params['values']
      end
      assert_equal @limit_to_assert.to_s, env.params['limit']
      assert_includes [nil, "100"], env.params['offset']
      range = env.params['offset'] ? 101..150 : 1..100
      list = range.map do |i|
        make_kv_listing(@kv.collection,
                        {value: @wants_values, key: @kv.key,
                         ref: "#{i}", tombstone: i % 6 == 0,
                         reftime: Time.now.to_f - i * 3600_00})
      end
      body = {results: list, count: range.respond_to?(:size) ? range.size : range.end - range.begin}
      next_link = "/v0/items/#{@kv.key}/refs?offset=100&limit=100"
      next_link += "&values=true" if @wants_values
      body['next'] = next_link unless env.params['offset']
      [200, response_headers, body.to_json]
    end
    @assert_ref_listing = lambda do |ref|
      assert ref.archival?
      assert_equal @kv.key, ref.key
      if ref.ref.to_i % 6 == 0
        assert ref.tombstone?, "Ref #{ref.ref} should be tombstone, isn't"
        assert_nil ref.value
      else
        refute ref.tombstone?, "Ref #{ref.ref} should not be tombstone, is"
        if @wants_values
          assert_kind_of Hash, ref.value
        else
          assert_equal Hash.new, ref.value
        end
      end
    end
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

  def test_enumerates_over_refs
    refs = @kv.refs.to_a
    assert_equal 150, refs.size
    refs.each(&@assert_ref_listing)
  end

  def test_enumerates_in_parallel_raises_not_ready_if_forced
    @limit_to_assert = "5"
    assert_raises Orchestrate::ResultsNotReady do
      @app.in_parallel { @kv.refs.take(5) }
    end
  end

  def test_enumerates_in_parallel_prefetches_lazy_enums
    return unless [].respond_to?(:lazy)
    refs = nil
    @app.in_parallel { refs = @kv.refs.lazy.map {|r| r } }
    assert @called, "lazy enumerator in parallel was not prefetched"
    refs = refs.force
    assert_equal 150, refs.length
    refs.each(&@assert_ref_listing)
  end

  def test_enumerator_in_parallel_fetches_enums
    refs = nil
    @app.in_parallel { refs = @kv.refs.each }
    assert @called, "enumerator wasn't prefetched inside of parallel"
    assert_equal 150, refs.to_a.size
    refs.each(&@assert_ref_listing)
  end

  def test_enumerator_doesnt_prefetch_lazy_enums
    return unless [].respond_to?(:lazy)
    refs = @kv.refs.lazy.map {|r| r }
    refute @called, "lazy enumerator was prefetched outside of parallel"
    refs = refs.force
    assert_equal 150, refs.length
    refs.each(&@assert_ref_listing)
  end

  def test_enumerator_prefetches_enums
    refs = @kv.refs.each
    assert @called, "enumerator was not prefetched"
    assert_equal 150, refs.to_a.size
    refs.each(&@assert_ref_listing)
  end

  def test_take_sets_limit
    @limit_to_assert = 5
    refs = @kv.refs.take(5).to_a
    assert_equal 5, refs.length
    refs.each(&@assert_ref_listing)
  end

  def test_offset_sets_offset
    refs = @kv.refs.offset(100).to_a
    assert_equal 50, refs.size
    refs.each(&@assert_ref_listing)
  end

  def test_enumerates_with_values
    @wants_values = true
    refs = @kv.refs.with_values.to_a
    assert_equal 150, refs.size
    refs.each(&@assert_ref_listing)
  end

end
