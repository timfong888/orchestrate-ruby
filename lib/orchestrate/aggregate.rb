module Orchestrate

  class Collection

    # Aggregate Builder object for constructing aggregate params included in a search
    class AggregateBuilder

      attr_reader :search

      attr_reader :agg_arr

      extend Forwardable

      def initialize(search)
        @search = search
        @agg_arr = []
      end

      def to_s
        
      end
      alias :inspect :to_s

      # @!group Aggregate Queries
      def stats(field_name)
        agg_arr << "#{field_name}:stats"
        self
      end

      def range(field_name)
        RangeBuilder.new(self, "#{field_name}:range:")
      end

      def distance(field_name)
        DistanceBuilder.new(self, "#{field_name}:distance:")
      end

      # @param interval [#to_s] The value measure chronological data by.
      # Accepted intervals are 'year', 'quarter', 'month', 'week', 'day', and 'hour'
      def time_series(field_name, interval)
        agg_arr << "#{field_name}:time_series:#{interval}"
        self
      end
      # @!endgroup

      def add_aggregate(arg)
        agg_arr << arg
        self
      end

      def build
        aggregate = agg_arr.join(',')
        @search.set_aggregates(aggregate)
        @search
      end
    end

    class RangeBuilder

      attr_reader :builder

      attr_reader :field

      def initialize(builder, field)
        @builder = builder
        @field = field
      end

      def below(x)
        field << "*~#{x}:"
        self
      end

      def above(x)
        field << "#{x}~*:"
        self
      end

      def between(x, y)
        field << "#{x}~#{y}:"
        self
      end

      def build
        @builder.add_aggregate(field)
        @builder
      end
    end

    class DistanceBuilder < RangeBuilder
    end
  end
end