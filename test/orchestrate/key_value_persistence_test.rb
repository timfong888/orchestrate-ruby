require "test_helper"

class KeyValuePersistenceTest < MiniTest::Unit::TestCase
  def setup
    @app, @stubs = make_application
    @items = @app[:items]
    @kv = make_kv_item(@items, @stubs, :loaded => Time.now - 60, body: {"hello" => "world", "another" => "key"})
  end

  def test_save_performs_put_if_match_and_returns_true_on_success
    @kv[:foo] = "bar"
    new_ref = nil
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      assert_equal @kv.value, JSON.parse(env.body)
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      new_ref = make_ref
      [ 201, response_headers({'Etag' => new_ref, "Location" => "/v0/items/#{@kv.key}/refs/#{new_ref}"}), '' ]
    end
    assert_equal true, @kv.save
    assert_equal new_ref, @kv.ref
    assert_in_delta Time.now.to_f, @kv.last_request_time.to_f, 1.1
    assert_equal "bar", @kv[:foo]
  end

  def test_save_performs_put_if_match_and_returns_false_on_version_mismatch
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      error_response(:version_mismatch)
    end
    assert_equal false, @kv.save
  end

  def test_save_performs_put_if_match_and_returns_true_on_indexing_conflict
    ref = @kv.ref
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      ref = make_ref
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      error_response(:indexing_conflict, {
        headers: {"Location" => "/v0/items/#{@kv.key}/refs/#{ref}"},
        conflicts_uri: "/v0/items/#{@kv.key}/refs/#{ref}/conflicts"
      })
    end
    assert_equal true, @kv.save
    assert_equal ref, @kv.ref
    assert_in_delta Time.now.to_f, @kv.last_request_time.to_f, 1.1
  end

  def test_save_returns_false_on_etc_errors
    @stubs.put("/v0/items/#{@kv.key}") { error_response(:bad_request) }
    assert_equal false, @kv.save

    @stubs.put("/v0/items/#{@kv.key}") { error_response(:service_error) }
    assert_equal false, @kv.save
  end

  def test_save_bang_performs_put_if_match_doesnt_raise_on_success
    @kv[:foo] = "bar"
    ref = @kv.ref
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      assert_equal @kv.value, JSON.parse(env.body)
      assert_header 'If-Match', %|"#{ref}"|, env
      ref = make_ref
      [201, response_headers({'Etag'=>%|"#{ref}"|, 'Loation'=>"/v0/items/#{@kv.key}/refs/#{ref}"}), '']
    end
    @kv.save!
    assert_equal ref, @kv.ref
    assert_in_delta Time.now.to_f, @kv.last_request_time.to_f, 1.1
  end

  def test_save_bang_performs_put_if_match_raises_on_version_mismatch
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      assert_header "If-Match", %|"#{@kv.ref}"|, env
      error_response(:version_mismatch)
    end
    assert_raises Orchestrate::API::VersionMismatch do
      @kv.save!
    end
  end

  def test_save_bang_performs_put_if_match_doesnt_raise_on_indexing_conflict
    ref = @kv.ref
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      ref = make_ref
      assert_header "If-Match", %|"#{@kv.ref}"|, env
      error_response(:indexing_conflict, {
        headers: {"Location" => "/v0/items/#{@kv.key}/refs/#{ref}"},
        conflicts_uri: "/v0/items/#{@kv.key}/refs/#{ref}/conflicts"
      })
    end
    @kv.save!
    assert_equal ref, @kv.ref
    assert_in_delta Time.now.to_f, @kv.last_request_time.to_f, 1.1
  end

  def test_save_bang_performs_put_if_match_raises_on_request_error
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      assert_header "If-Match", %|"#{@kv.ref}"|, env
      error_response(:bad_request)
    end
    assert_raises Orchestrate::API::BadRequest do
      @kv.save!
    end
  end

  def test_save_bang_performs_put_if_match_raises_on_service_error
    @stubs.put("/v0/items/#{@kv.key}") { error_response(:service_error) }
    assert_raises Orchestrate::API::ServiceError do
      @kv.save!
    end
  end

  def test_set_merges_values_and_saves
    set = {hello: "there", 'two' => 2}
    body = @kv.value
    set.each_pair {|key, value| body[key.to_s] = value }
    new_ref = make_ref
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      assert_equal body, JSON.parse(env.body)
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      [201, response_headers({'Etag' => new_ref, "Location" => "/v0/items/#{@kv.key}/refs/#{new_ref}"}), '']
    end
    @kv.set(set)
    assert_equal body, @kv.value
    assert_equal new_ref, @kv.ref
  end

  def test_set_merges_values_and_returns_false_on_error
    set = {hello: "there", 'two' => 2}
    body = @kv.value
    set.each_pair {|key, value| body[key.to_s] = value }
    old_ref = @kv.ref
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      assert_equal body, JSON.parse(env.body)
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      error_response(:service_error)
    end
    refute @kv.set(set)
    assert_equal body, @kv.value
    assert_equal old_ref, @kv.ref
  end

  def test_set_bang_merges_values_and_save_bangs
    set = {hello: "there", 'two' => 2}
    body = @kv.value
    set.each_pair {|key, value| body[key.to_s] = value }
    new_ref = make_ref
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      assert_equal body, JSON.parse(env.body)
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      [201, response_headers({'Etag' => new_ref, "Location" => "/v0/items/#{@kv.key}/refs/#{new_ref}"}), '']
    end
    @kv.set!(set)
    assert_equal body, @kv.value
    assert_equal new_ref, @kv.ref
  end

  def test_set_bang_merges_values_and_save_bangs_raises_on_error
    set = {hello: "there", 'two' => 2}
    body = @kv.value
    set.each_pair {|key, value| body[key.to_s] = value }
    old_ref = @kv.ref
    @stubs.put("/v0/items/#{@kv.key}") do |env|
      assert_equal body, JSON.parse(env.body)
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      error_response(:service_error)
    end
    assert_raises Orchestrate::API::ServiceError do
      @kv.set!(set)
    end
    assert_equal body, @kv.value
    assert_equal old_ref, @kv.ref
  end

  def test_merge_patch_merges_partial_value_into_existing_kv_without_ref
    merge = {"foo" => "bar"}
    body = @kv.value
    body["foo"] = "bar"
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal merge, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/merge-patch+json', env
      [201, response_headers({'Etag' => @kv.ref, "Location" => "/v0/items/#{@kv.key}/refs/#{@kv.ref}"}), '']
    end
    @kv.merge(merge)
    assert_equal body, @kv.value
  end

  def test_merge_patch_merges_partial_value_into_existing_kv_with_ref
    merge = {"foo" => "bar"}
    body = @kv.value
    body["foo"] = "bar"
    ref = @kv.ref
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal merge, JSON.parse(env.body)
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      assert_header 'Content-Type', 'application/merge-patch+json', env
      [201, response_headers({'Etag' => ref, "Location" => "/v0/items/#{@kv.key}/refs/#{ref}"}), '']
    end
    @kv.merge(merge, ref)
    assert_equal body, @kv.value
    assert_equal ref, @kv.ref
  end

  def test_update_add_operation_creates_new_field_and_value_without_ref
    add = [{ "op" => "add", "path" => "aloha", "value" => "universe"}]
    body = @kv.value
    body["aloha"] = "universe"
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal add, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      [201, response_headers({'Etag' => @kv.ref, "Location" => "/v0/items/#{@kv.key}/refs/#{@kv.ref}"}), '']
    end
    @kv.add(:aloha, "universe").update()
    assert_equal body, @kv.value
  end

  def test_update_add_operation_creates_new_field_and_value_with_ref
    add = [{ "op" => "add", "path" => "aloha", "value" => "universe"}]
    body = @kv.value
    body["aloha"] = "universe"
    ref = @kv.ref
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal add, JSON.parse(env.body)
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      assert_header 'Content-Type', 'application/json-patch+json', env
      [201, response_headers({'Etag' => ref, "Location" => "/v0/items/#{@kv.key}/refs/#{ref}"}), '']
    end
    @kv.add(:aloha, "universe").update(ref)
    assert_equal body, @kv.value
    assert_equal ref, @kv.ref
  end

  def test_update_remove_operation_removes_new_field_and_value_without_ref
    remove = [{ "op" => "remove", "path" => "hello"}]
    body = @kv.value
    body.delete("hello")
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal remove, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      [201, response_headers({'Etag' => @kv.ref, "Location" => "/v0/items/#{@kv.key}/refs/#{@kv.ref}"}), '']
    end
    @kv.remove(:hello).update()
    assert_equal body, @kv.value
  end

  def test_update_remove_operation_removes_new_field_and_value_with_ref
    remove = [{ "op" => "remove", "path" => "hello"}]
    body = @kv.value
    body.delete("hello")
    ref = @kv.ref
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal remove, JSON.parse(env.body)
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      assert_header 'Content-Type', 'application/json-patch+json', env
      [201, response_headers({'Etag' => ref, "Location" => "/v0/items/#{@kv.key}/refs/#{ref}"}), '']
    end
    @kv.remove(:hello).update(ref)
    assert_equal body, @kv.value
    assert_equal ref, @kv.ref
  end

  def test_update_remove_operation_raises_error_with_non_existing_field
    remove = [{ "op" => "remove", "path" => "foo"}]
    body = @kv.value
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal remove, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      error_response(:malformed_ref)
    end
    assert_raises Orchestrate::API::MalformedRef do
      @kv.remove(:foo).update()
    end
  end

  def test_update_replace_operation_replaces_field_with_new_value_without_ref
    replace = [{ "op" => "replace", "path" => "hello", "value" => "universe"}]
    body = @kv.value
    body["hello"] = "universe"
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal replace, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      [201, response_headers({'Etag' => @kv.ref, "Location" => "/v0/items/#{@kv.key}/refs/#{@kv.ref}"}), '']
    end
    @kv.replace(:hello, "universe").update()
    assert_equal body, @kv.value
  end

  def test_update_replace_operation_replaces_field_with_new_value_with_ref
    replace = [{ "op" => "replace", "path" => "hello", "value" => "universe"}]
    body = @kv.value
    body["hello"] = "universe"
    ref = @kv.ref
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal replace, JSON.parse(env.body)
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      assert_header 'Content-Type', 'application/json-patch+json', env
      [201, response_headers({'Etag' => ref, "Location" => "/v0/items/#{@kv.key}/refs/#{ref}"}), '']
    end
    @kv.replace(:hello, "universe").update(ref)
    assert_equal body, @kv.value
    assert_equal ref, @kv.ref
  end

  def test_update_replace_operation_raises_error_with_non_existing_field
    replace = [{ "op" => "replace", "path" => "foo", "value" => "bar"}]
    body = @kv.value
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal replace, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      error_response(:malformed_ref)
    end
    assert_raises Orchestrate::API::MalformedRef do
      @kv.replace(:foo, "bar").update()
    end
  end

  def test_update_move_operation_moves_field_without_ref
    move = [{ "op" => "move", "from" => "hello", "path" => "foo" }]
    body = @kv.value
    body.delete("hello")
    body["foo"] = "world"
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal move, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      [201, response_headers({'Etag' => @kv.ref, "Location" => "/v0/items/#{@kv.key}/refs/#{@kv.ref}"}), '']
    end
    @kv.move(:hello, :foo).update()
    assert_equal body, @kv.value
  end

  def test_update_move_operation_moves_field_with_ref
    move = [{ "op" => "move", "from" => "hello", "path" => "foo" }]
    body = @kv.value
    body.delete("hello")
    body["foo"] = "world"
    ref = @kv.ref
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal move, JSON.parse(env.body)
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      assert_header 'Content-Type', 'application/json-patch+json', env
      [201, response_headers({'Etag' => ref, "Location" => "/v0/items/#{@kv.key}/refs/#{ref}"}), '']
    end
    @kv.move(:hello, :foo).update(ref)
    assert_equal body, @kv.value
    assert_equal ref, @kv.ref
  end

  def test_update_move_operation_raises_error_with_non_existing_field
    move = [{ "op" => "move", "from" => "foo", "path" => "hello" }]
    body = @kv.value
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal move, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      error_response(:malformed_ref)
    end
    assert_raises Orchestrate::API::MalformedRef do
      @kv.move(:foo, :hello).update()
    end
  end

  def test_update_copy_operation_copies_field_without_ref
    copy = [{ "op" => "copy", "from" => "hello", "path" => "foo" }]
    body = @kv.value
    body["foo"] = "world"
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal copy, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      [201, response_headers({'Etag' => @kv.ref, "Location" => "/v0/items/#{@kv.key}/refs/#{@kv.ref}"}), '']
    end
    @kv.copy(:hello, :foo).update()
    assert_equal body, @kv.value
  end

  def test_update_copy_operation_copies_field_with_ref
    copy = [{ "op" => "copy", "from" => "hello", "path" => "foo" }]
    body = @kv.value
    body["foo"] = "world"
    ref = @kv.ref
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal copy, JSON.parse(env.body)
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      assert_header 'Content-Type', 'application/json-patch+json', env
      [201, response_headers({'Etag' => ref, "Location" => "/v0/items/#{@kv.key}/refs/#{ref}"}), '']
    end
    @kv.copy(:hello, :foo).update(ref)
    assert_equal body, @kv.value
    assert_equal ref, @kv.ref
  end

  def test_update_copy_operation_raises_error_with_non_existing_field
    copy = [{ "op" => "copy", "from" => "foo", "path" => "hello" }]
    body = @kv.value
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal copy, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      error_response(:malformed_ref)
    end
    assert_raises Orchestrate::API::MalformedRef do
      @kv.copy(:foo, :hello).update()
    end
  end

  def test_update_increment_operation_increases_field_number_value_without_ref
    increment = [{ "op" => "inc", "path" => "count", "value" => 1 }]
    body = @kv.value
    old_count = 2
    body["count"] = 3
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal increment, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      [201, response_headers({'Etag' => @kv.ref, "Location" => "/v0/items/#{@kv.key}/refs/#{@kv.ref}"}), '']
    end
    @kv.increment(:count, 1).update()
    assert_equal body, @kv.value
    assert_equal old_count+1, @kv.value["count"]
  end

  def test_update_increment_operation_increases_field_number_value_with_ref
    increment = [{ "op" => "inc", "path" => "count", "value" => 1 }]
    body = @kv.value
    old_count = 2
    body["count"] = 3
    ref = @kv.ref
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal increment, JSON.parse(env.body)
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      assert_header 'Content-Type', 'application/json-patch+json', env
      [201, response_headers({'Etag' => ref, "Location" => "/v0/items/#{@kv.key}/refs/#{ref}"}), '']
    end
    @kv.increment(:count, 1).update(ref)
    assert_equal body, @kv.value
    assert_equal ref, @kv.ref
    assert_equal old_count+1, @kv.value["count"]
  end

  def test_update_increment_operation_raises_error_with_non_number_field
    increment = [{ "op" => "inc", "path" => "hello", "value" => 1 }]
    body = @kv.value
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal increment, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      error_response(:malformed_ref)
    end
    assert_raises Orchestrate::API::MalformedRef do
      @kv.increment(:hello, 1).update()
    end
  end

  def test_update_increment_operation_raises_error_with_non_existing_field
    increment = [{ "op" => "inc", "path" => "foo", "value" => 1 }]
    body = @kv.value
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal increment, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      error_response(:malformed_ref)
    end
    assert_raises Orchestrate::API::MalformedRef do
      @kv.increment(:foo, 1).update()
    end
  end

  def test_update_decrement_operation_decreases_field_number_value_without_ref
    decrement = [{ "op" => "inc", "path" => "count", "value" => -1 }]
    body = @kv.value
    old_count = 3
    body["count"] = 2
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal decrement, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      [201, response_headers({'Etag' => @kv.ref, "Location" => "/v0/items/#{@kv.key}/refs/#{@kv.ref}"}), '']
    end
    @kv.decrement(:count, 1).update()
    assert_equal body, @kv.value
    assert_equal old_count-1, @kv.value["count"]
  end

  def test_update_decrement_operation_decreases_field_number_value_with_ref
    decrement = [{ "op" => "inc", "path" => "count", "value" => -1 }]
    body = @kv.value
    old_count = 3
    body["count"] = 2
    ref = @kv.ref
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal decrement, JSON.parse(env.body)
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      assert_header 'Content-Type', 'application/json-patch+json', env
      [201, response_headers({'Etag' => ref, "Location" => "/v0/items/#{@kv.key}/refs/#{ref}"}), '']
    end
    @kv.decrement(:count, 1).update(ref)
    assert_equal body, @kv.value
    assert_equal ref, @kv.ref
    assert_equal old_count-1, @kv.value["count"]
  end

  def test_update_decrement_operation_raises_error_with_non_number_field
    decrement = [{ "op" => "inc", "path" => "hello", "value" => -1 }]
    body = @kv.value
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal decrement, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      error_response(:malformed_ref)
    end
    assert_raises Orchestrate::API::MalformedRef do
      @kv.decrement(:hello, 1).update()
    end
  end

  def test_update_decrement_operation_raises_error_with_non_existing_field
    decrement = [{ "op" => "inc", "path" => "foo", "value" => -1 }]
    body = @kv.value
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal decrement, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      error_response(:malformed_ref)
    end
    assert_raises Orchestrate::API::MalformedRef do
      @kv.decrement(:foo, 1).update()
    end
  end

  def test_update_test_operation_checks_equality_of_field_value_success
    test = [{ "op" => "test", "path" => "count", "value" => 1 }]
    body = @kv.value
    body["count"] = 1
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal test, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      [201, response_headers({'Etag' => @kv.ref, "Location" => "/v0/items/#{@kv.key}/refs/#{@kv.ref}"}), '']
    end
    @kv.test(:count, 1).update()
    assert_equal body, @kv.value
  end

  def test_update_test_operation_checks_equality_of_field_value_failure
    test = [{ "op" => "test", "path" => "count", "value" => 2 }]
    body = @kv.value
    body["count"] = 1
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_header 'Content-Type', 'application/json-patch+json', env
      error_response(:indexing_conflict)
    end
    assert_raises Orchestrate::API::IndexingConflict do
      @kv.test(:foo, 1).update()
    end
  end

  def test_update_test_operation_raises_error_with_non_existing_field
    test = [{ "op" => "test", "path" => "foo", "value" => 1 }]
    body = @kv.value
    @stubs.patch("/v0/items/#{@kv.key}") do |env|
      assert_equal test, JSON.parse(env.body)
      assert_header 'Content-Type', 'application/json-patch+json', env
      error_response(:malformed_ref)
    end
    assert_raises Orchestrate::API::MalformedRef do
      @kv.test(:foo, 1).update()
    end
  end

  def test_destroy_performs_delete_if_match_and_returns_true_on_success
    @stubs.delete("/v0/items/#{@kv.key}") do |env|
      assert_header 'If-Match', "\"#{@kv.ref}\"", env
      [204, response_headers, '']
    end
    assert_equal true, @kv.destroy
    assert_nil @kv.ref
    assert_in_delta Time.now.to_f, @kv.last_request_time.to_f, 1.1
  end

  def test_destroy_performs_delete_if_match_and_returns_false_on_error
    @stubs.delete("/v0/items/#{@kv.key}") { error_response(:version_mismatch) }
    assert_equal false, @kv.destroy
  end

  def test_destroy_bang_performs_delete_raises_on_error
    @stubs.delete("/v0/items/#{@kv.key}") { error_response(:version_mismatch) }
    assert_raises Orchestrate::API::VersionMismatch do
      @kv.destroy!
    end
  end

  def test_purge_performs_purge_if_match_and_returns_true_on_success
    @stubs.delete("/v0/items/#{@kv.key}") do |env|
      assert_header 'If-Match', %|"#{@kv.ref}"|, env
      assert_equal "true", env.params['purge']
      [ 204, response_headers, '' ]
    end
    assert_equal true, @kv.purge
    assert_nil @kv.ref
    assert_in_delta Time.now.to_f, @kv.last_request_time.to_f, 1.1
  end

  def test_purge_performs_purge_if_match_and_returns_false_on_error
    @stubs.delete("/v0/items/#{@kv.key}") { error_response(:version_mismatch) }
    assert_equal false, @kv.purge
  end

  def test_purge_bang_performs_purge_if_match_and_raises_on_error
    @stubs.delete("/v0/items/#{@kv.key}") do |env|
      assert_header 'If-Match', %|"#{@kv.ref}"|, env
      assert_equal "true", env.params['purge']
      error_response(:version_mismatch)
    end
    assert_raises Orchestrate::API::VersionMismatch do
      @kv.purge!
    end
  end

end
