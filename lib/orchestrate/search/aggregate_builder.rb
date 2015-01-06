module Orchestrate::Search
  # Aggregate Builder object for constructing aggregate params included in a search
  class AggregateBuilder

    # @return [QueryBuilder] 
    attr_reader :builder

    # @return [Array] Aggregate param arguments
    attr_reader :aggregates

    extend Forwardable

    # Initialize a new AggregateBuilder object
    # @param builder [Orchestrate::Search::SearchBuilder] The Search Builder object
    def initialize(builder)
      @builder = builder
      @aggregates = []
    end

    def_delegator :@builder, :options
    def_delegator :@builder, :order
    def_delegator :@builder, :limit
    def_delegator :@builder, :offset
    def_delegator :@builder, :aggregate
    def_delegator :@builder, :find

    # @return Pretty-Printed string representation of the AggregateBuilder object
    def to_s
      "#<Orchestrate::Search::AggregateBuilder collection=#{builder.collection.name} query=#{builder.query} aggregate=#{to_param}>"
    end
    alias :inspect :to_s

    # @return constructed aggregate string parameter for search query
    def to_param
      aggregates.map {|agg| agg.to_s }.join(',')
    end

    # @!group Aggregate Functions

    # @param field_name [#to_s]
    # @return [AggregateBuilder]
    def stats(field_name)
      aggregates << "#{field_name}:stats"
      self
    end

    # @param field_name [#to_s]
    # @return [RangeBuilder]
    def range(field_name)
      rng = RangeBuilder.new(self, "#{field_name}:range:")
      aggregates << rng
      rng
    end

    # @param field_name [#to_s]
    # @return [DistanceBuilder]
    def distance(field_name)
      dist = DistanceBuilder.new(self, "#{field_name}:distance:")
      aggregates << dist
      dist
    end

    # @param field_name [#to_s]
    # @return [TimeSeriesBuilder]
    def time_series(field_name)
      time = TimeSeriesBuilder.new(self, "#{field_name}:time_series:")
      aggregates << time
      time
    end
    # @!endgroup
  end

  # Range Builder object for constructing range functions to be included in the aggregate param
  class RangeBuilder

    # @return [AggregateBuilder]
    attr_reader :builder

    # @return [#to_s] The field to operate over
    attr_reader :field_name

    extend Forwardable

    # Initialize a new RangeBuilder object
    # @param builder [AggregateBuilder] The Aggregate Builder object
    # @param field [#to_s]
    def initialize(builder, field_name)
      @builder = builder
      @field_name = field_name
    end

    def_delegator :@builder, :options
    def_delegator :@builder, :order
    def_delegator :@builder, :limit
    def_delegator :@builder, :offset
    def_delegator :@builder, :aggregate
    def_delegator :@builder, :find
    def_delegator :@builder, :stats
    def_delegator :@builder, :range
    def_delegator :@builder, :distance
    def_delegator :@builder, :time_series

    # @return string representation of the aggregate range param
    def to_s
      "#{field_name}"
    end
    alias :inspect :to_s

    # @param x [Integer]
    # @return [RangeBuilder]
    def below(x)
      @field_name << "*~#{x}:"
      self
    end

    # @param x [Integer]
    # @return [RangeBuilder]
    def above(x)
      @field_name << "#{x}~*:"
      self
    end

    # @param x [Integer]
    # @param y [Integer]
    # @return [RangeBuilder]
    def between(x, y)
      @field_name << "#{x}~#{y}:"
      self
    end
  end

  # Distance Builder object for constructing distance functions for the aggregate param
  class DistanceBuilder < RangeBuilder
  end

  # Time Series Builder object for constructing time series functions for the aggregate param
  class TimeSeriesBuilder

    # @return [AggregateBuilder]
    attr_reader :builder

    # @return [#to_s] The field to operate over
    attr_reader :field_name

    # @return [#to_s] The interval of time for the TimeSeries function
    attr_reader :interval

    extend Forwardable

    # Initialize a new TimeSeriesBuilder object
    # @param builder [AggregateBuilder] The Aggregate Builder object
    # @param field_name [#to_s] The field to operate over
    def initialize(builder, field_name)
      @builder = builder
      @field_name = field_name
      @interval = nil
    end

    def_delegator :@builder, :options
    def_delegator :@builder, :order
    def_delegator :@builder, :limit
    def_delegator :@builder, :offset
    def_delegator :@builder, :aggregate
    def_delegator :@builder, :find
    def_delegator :@builder, :stats
    def_delegator :@builder, :range
    def_delegator :@builder, :distance
    def_delegator :@builder, :time_series

    # @return string representation of the aggregate range param
    def to_s
      "#{field_name}#{interval}"
    end
    alias :inspect :to_s

    # Set time series interval to year
    # @return [AggregateBuilder]
    def year
      @interval = 'year'
      self
    end

    # Set time series interval to quarter
    # @return [AggregateBuilder]
    def quarter
      @interval = 'quarter'
      self
    end

    # Set time series interval to month
    # @return [AggregateBuilder]
    def month
      @interval = 'month'
      self
    end

    # Set time series interval to week
    # @return [AggregateBuilder]
    def week
      @interval = 'week'
      self
    end

    # Set time series interval to day
    # @return [AggregateBuilder]
    def day
      @interval = 'day'
      self
    end

    # Set time series interval to hour
    # @return [AggregateBuilder]
    def hour
      @interval = 'hour'
      self
    end
  end
end