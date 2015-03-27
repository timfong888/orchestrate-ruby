module Orchestrate::Search
  # An enumerator for searching an Orchestrate::Collection
  class Results
    # @return [Collection] The collection this object will search.
    attr_reader :collection

    # @return [#to_s] The Lucene Query String given as the search query.
    attr_reader :query

    # @return [Hash] The query paramaters.
    attr_reader :options

    # @return [Orchestrate::API::CollectionResponse] The response object
    attr_reader :response

    # @return [#to_json] The response object's aggregate results
    attr_reader :aggregates

    # Initialize a new SearchResults object
    # @param collection [Orchestrate::Collection] The collection searched.
    # @param query [#to_s] The Lucene Query performed.
    # @param options [Hash] The query parameters.
    def initialize(collection, query, options)
      @collection = collection
      @query = query
      @options = options
      @response = nil
      @aggregates = nil
    end

    include Enumerable

    # Iterates over each result from the Search. Used as the basis for Enumerable methods.
    # Items are provided on the basis of score, with most relevant first.
    # @overload each
    #   @return Enumerator
    # @overload each(&block)
    #   @yieldparam [Array<(Float, Orchestrate::KeyValue)>] score,key_value  The item's score and the item.
    # @example
    #   collection.search("trendy").limit(5).execute.each do |score, item|
    #     puts "#{item.key} has a trend score of #{score}"
    #   end
    def each
      @response ||= collection.perform(:search, query, options)
      @aggregates ||= @response.aggregates
      return enum_for(:each) unless block_given?
      raise Orchestrate::ResultsNotReady.new if collection.app.inside_parallel?
      loop do
        @response.results.each do |listing|
          case listing['path']['kind']
          when 'event'
            kv = collection.stub(listing['key'])
            event_type = Orchestrate::EventType.new(kv, listing['type'])
            event = Orchestrate::Event.from_listing(event_type, listing, @response)
            yield [listing['score'], event]
          else
            yield [listing['score'], Orchestrate::KeyValue.from_listing(collection, listing, @response)]
          end
        end
        break unless @response.next_link
        @response = @response.next_results
      end
      @response = nil
    end

    # Iterates over each aggregate result from the Search. Used as the basis for Enumerable methods.  Items are
    # provided on the basis of score, with most relevant first.
    # @overload each_aggregate
    #   @return Enumerator
    # @overload each_aggregate(&block)
    #   @yieldparam <(Orchestrate::Collection::AggregateResult)>
    def each_aggregate
      @response ||= collection.perform(:search, query, options)
      @aggregates ||= @response.aggregates
      return enum_for(:each_aggregate) unless block_given?
      raise Orchestrate::ResultsNotReady.new if collection.app.inside_parallel?
      @aggregates.each do |listing|
        case listing['aggregate_kind']
        when 'stats'
          yield StatsResult.new(collection, listing)
        when 'range'
          yield RangeResult.new(collection, listing)
        when 'distance'
          yield DistanceResult.new(collection, listing)
        when 'time_series'
          yield TimeSeriesResult.new(collection, listing)
        end
      end
    end

    # Creates a Lazy Enumerator for the Search Results.  If called inside its
    # app's `in_parallel` block, will pre-fetch results.
    def lazy
      return each.lazy if collection.app.inside_parallel?
      super
    end
  end

  # Base object representing an individual Aggregate result
  class AggregateResult
    # @return [Collection] The collection searched.
    attr_reader :collection

    # @return [#to_s] The aggregate kind/type
    attr_reader :kind

    # @return [#to_s] The field name the aggregate function operated over.
    attr_reader :field_name

    # @return [Integer] Number of field values included in the aggregate function.
    attr_reader :count

    # Initialize a new AggregateResult object
    # @param collection [Orchestrate::Collection] The collection searched.
    # @param listing [#to_json] The aggregate result returned from the search.
    def initialize(collection, listing)
      @collection = collection
      @kind = listing['aggregate_kind']
      @field_name = listing['field_name']
      @count = listing['value_count']
    end
  end

  # Stats Aggregate result object
  class StatsResult < AggregateResult
    # @return [Hash] The statistics results
    attr_reader :statistics

    # @return [Float] Lowest numerical value of the statistics result
    attr_reader :min

    # @return [Float] Highest numerical value of the statistics result
    attr_reader :max

    # @return [Float] Average of included numerical values
    attr_reader :mean

    # @return [Float] Total of included numerical values
    attr_reader :sum

    # @return [Float]
    attr_reader :sum_of_squares

    # @return [Float]
    attr_reader :variance

    # @return [Float]
    attr_reader :std_dev

    # Initialize a new StatsResult object
    # @param collection [Orchestrate::Collection] The collection searched.
    # @param listing [#to_json] The aggregate result returned from the search.
    def initialize(collection, listing)
      super(collection, listing)
      if listing['statistics']
        @statistics = listing['statistics']
        @min = @statistics['min']
        @max = @statistics['max']
        @mean = @statistics['mean']
        @sum = @statistics['sum']
        @sum_of_squares = @statistics['sum_of_squares']
        @variance = @statistics['variance']
        @std_dev = @statistics['std_dev']
      end
    end

    # @return Pretty-Printed string representation of the StatsResult object
    def to_s
      stats = "statistics={\n  min=#{min},\n  max=#{max},\n  mean=#{mean},\n  sum=#{sum},\n  sum_of_squares=#{sum_of_squares},\n  variance=#{variance},\n  std_dev=#{std_dev}\n}"
      "#<Orchestrate::Search::StatsResult collection=#{collection.name} field_name=#{field_name} count=#{count} #{stats}>"
    end
    alias :inspect :to_s
  end

  # Range Aggregate result object
  class RangeResult < AggregateResult
    # @return [Array] Range buckets/sets results
    attr_reader :buckets

    # Initialize a new RangeResult object
    # @param collection [Orchestrate::Collection] The collection searched.
    # @param listing [#to_json] The aggregate result returned from the search.
    def initialize(collection, listing)
      super(collection, listing)
      @buckets = listing['buckets']
    end

    # @return Pretty-Printed string representation of the RangeResult object
    def to_s
      "#<Orchestrate::Search::RangeResult collection=#{collection.name} field_name=#{field_name} buckets=#{buckets}>"
    end
    alias :inspect :to_s
  end

  # Distance Aggregate result object
  class DistanceResult < RangeResult
    # @return Pretty-Printed string representation of the DistanceResult object
    def to_s
      "#<Orchestrate::Search::DistanceResult collection=#{collection.name} field_name=#{field_name} buckets=#{buckets}>"
    end
    alias :inspect :to_s
  end

  # Time Series Aggregate result object
  class TimeSeriesResult < RangeResult
    # @return [#to_s] Time interval
    attr_reader :interval

    # Initialize a new TimeSeriesResult object
    # @param collection [Orchestrate::Collection] The collection searched.
    # @param listing [#to_json] The aggregate result returned from the search.
    def initialize(collection, listing)
      super(collection, listing)
      @interval = listing['interval']
    end

    # @return Pretty-Printed string representation of the TimeSeriesResult object
    def to_s
      "#<Orchestrate::Search::TimeSeriesResult collection=#{collection.name} field_name=#{field_name} interval=#{interval} buckets=#{buckets}>"
    end
    alias :inspect :to_s
  end
end
