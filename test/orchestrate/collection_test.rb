require "test_helper"

class CollectionTest < MiniTest::Unit::TestCase

  def test_instantiates_with_app_and_name
    app, stubs = make_application
    users = Orchestrate::Collection.new(app, :users)
    assert_equal app, users.app
    assert_equal 'users', users.name
  end

end

