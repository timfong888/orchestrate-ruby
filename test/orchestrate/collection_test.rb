require "test_helper"

class CollectionTest < MiniTest::Unit::TestCase

  def test_instantiates_with_app_and_name
    app, stubs = make_application
    users = Orchestrate::Collection.new(app, :users)
    assert_equal app, users.app
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

end

