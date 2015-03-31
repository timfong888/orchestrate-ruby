require 'test_helper'

class AggregateBuilderTest < MiniTest::Unit::TestCase
  def setup
    @query_builder = Orchestrate::Search::QueryBuilder.new(nil, '*')
    @builder = Orchestrate::Search::AggregateBuilder.new(@query_builder)
  end

  def test_top_values_aggregate
    top_values = @builder.top_values('name')
    assert_equal 'name:top_values', top_values.to_param
  end

  def test_top_values_aggregate_with_offset_limit
    top_values = @builder.top_values('name', 0, 10)
    assert_equal 'name:top_values:offset:0:limit:10', top_values.to_param
  end

  def test_top_values_aggregate_with_offset
    assert_raises(ArgumentError) do
      @builder.top_values('name', 0)
    end
  end

  def test_top_values_aggregate_with_limit
    assert_raises(ArgumentError) do
      @builder.top_values('name', nil, 10)
    end
  end

  # TODO: abstract delegator assertions into a re-usable helper
  def test_top_values_delegators
    # this test asserts that the top values aggregator delegates all expected
    # query builder and aggregate builder methods
    builder = MiniTest::Mock.new
    top_values = Orchestrate::Search::TopValuesBuilder.new(builder, "field_name")
    Orchestrate::Search::QueryBuilderDelegator.public_instance_methods.each do |m|
      builder.expect(m, true)
      top_values.send(m)
    end
    Orchestrate::Search::AggregateBuilderDelegator.public_instance_methods.each do |m|
      builder.expect(m, true)
      top_values.send(m)
    end
    builder.verify
  end
end
