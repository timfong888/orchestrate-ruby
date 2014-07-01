require "test_helper"

class CollectionTest < MiniTest::Unit::TestCase

  def test_instantiates_with_app_and_name
    app, stubs = make_application
    users = Orchestrate::Collection.new(app, :users)
    assert_equal app, users.app
    assert_equal 'users', users.name
  end

  def test_instantiates_with_client_and_name
    client, stubs = make_client_and_artifacts
    stubs.head("/v0") { [200, response_headers, ''] }
    users = Orchestrate::Collection.new(client, :users)
    assert_equal client, users.app.client
    assert_equal 'users', users.name
  end

  def test_destroy
    app, stubs = make_application
    users = Orchestrate::Collection.new(app, :users)
    stubs.delete("/v0/users") do |env|
      assert_equal "true", env.params["force"]
      [204, response_headers, '']
    end
    assert true, users.destroy!
  end

  def test_equality
    app, stubs = make_application
    app2, stubs = make_application
    items1 = app[:items]
    items2 = app[:items]
    other = app[:other]
    assert_equal items1, items2
    refute_equal items1, other
    refute_equal items1, OpenStruct.new({name: 'items'})
    refute_equal items1, 3
    refute_equal items1, app2[:items]

    assert items1.eql?(items2)
    assert items2.eql?(items1)
    refute items1.eql?(other)
    refute other.eql?(items1)
    refute items1.eql?(app2[:items])

    # equal? is for object identity only
    refute items1.equal?(items2)
    refute other.equal?(items1)
  end

  def test_sorting
    app, stubs = make_application
    app2, stubs = make_application
    assert_equal(-1, app[:users] <=> app[:items])
    assert_equal  0, app[:items] <=> app[:items]
    assert_equal  1, app[:items] <=> app[:users]
    assert_nil 2 <=> app[:items]
    assert_nil app2[:items] <=> app[:items]
  end
end

