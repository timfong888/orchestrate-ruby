require 'test_helper'

class QueryBuilderTest < MiniTest::Unit::TestCase
  def setup
    @builder = Orchestrate::Search::QueryBuilder.new(nil, '*')
  end

  def test_event_query
    @builder.kinds('event')
    assert_equal '(*) AND @path.kind:(event)', @builder.query
  end

  def test_event_or_item_query
    @builder.kinds('event', 'item')
    assert_equal '(*) AND @path.kind:(event item)', @builder.query
  end

  def test_event_types_query
    @builder.kinds('event').types('activities')
    assert_equal '(*) AND @path.kind:(event) AND @path.type:(activities)',
                 @builder.query
  end
end
