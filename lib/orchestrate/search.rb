module Orchestrate

  class Collection

    # Search Builder object for constructing search queries
    class SearchBuilder
      # @return [Collection] The collection this object will search.
      attr_reader :collection

      # @return [#to_s] The Lucene Query String given as the search query.
      attr_reader :query

      # Initialize a new SearchBuilder object
      # @param collection [Orchestrate::Collection] The collection to search.
      # @param query [#to_s] The Lucene Query to perform.
      def initialize(collection, query)
        @collection = collection
        @query = query
      end

      # @return Pretty-Printed string representation of the Search object
      def to_s
        "#<Orchestrate::Collection::SearchBuilder collection=#{collection.name} query=#{query} options=#{options}>"
      end
      alias :inspect :to_s

      # @return [Hash] Optional parameters for the search query.
      def options
        @options ||= {limit: 100}
      end

      # Sets the sorting parameters for a query's Search Results.
      # #order takes multiple arguments,
      # but each even numbered argument must be either :asc or :desc
      # Odd-numbered arguments defaults to :asc
      # @example
      #   @app[:items].search("foo").order(:name, :asc, :rank, :desc, :created_at)
      def order(*args)
        options[:sort] = args.each_slice(2).map {|field, dir| dir ||= :asc; "#{field}:#{dir}" }.join(',')
        self
      end

      # Sets the limit for the query to Orchestrate, so we don't ask for more than is needed. 
      # Does not fire a request.
      # @overload limit
      #   @return [Integer, nil] The number of items to retrieve.  Nil is equivalent to zero.
      # @overload limit(count)
      #   @param count [Integer] The number of items to retrieve.
      #   @return [Search] self.
      def limit(count=nil)
        if count
          options[:limit] = count > 100 ? 100 : count
          self
        else
          options[:limit]
        end
      end

      # Sets the offset for the query to Orchestrate, so you can skip items.  Does not fire a request.
      # Impelemented as separate method from drop, unlike #take, because take is a more common use case.
      # @overload offset
      #   @return [Integer, nil] The number of items to skip.  Nil is equivalent to zero.
      # @overload offset(count)
      #   @param count [Integer] The number of items to skip.
      #   @return [Search] self.
      def offset(count=nil)
        if count
          options[:offset] = count
          self
        else
          options[:offset]
        end
      end

      # @return [AggregateBuilder] An AggregateBuilder object to construct aggregate search params
      def aggregate
        options[:aggregate] ||= AggregateBuilder.new(self)
      end

      # @return [SearchResults] A SearchResults object to enumerate over.
      def find
        options[:aggregate] = options[:aggregate].to_param if options[:aggregate]
        SearchResults.new(collection, query, options)
      end
    end

    # Aggregate Builder object for constructing aggregate params included in a search
    class AggregateBuilder

      # @return [SearchBuilder] 
      attr_reader :builder

      # @return [Array] Aggregate param arguments
      attr_reader :aggregates

      extend Forwardable

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

      # @return Pretty-Printed string representation of the Search object
      def to_s
        "#<Orchestrate::Collection::AggregateBuilder collection=#{builder.collection.name} query=#{builder.query} aggregate=#{aggregates}>"
      end
      alias :inspect :to_s

      # @return constructed aggregate string parameter for search query
      def to_param
        aggregates.map {|agg| agg.to_s }.join(',')
      end

      # @!group Aggregate Queries
      def stats(field_name)
        aggregates << "#{field_name}:stats"
        self
      end

      def range(field_name)
        rng = RangeBuilder.new(self, "#{field_name}:range:")
        aggregates << rng
        rng
      end

      def distance(field_name)
        dist = DistanceBuilder.new(self, "#{field_name}:distance:")
        aggregates << dist
        dist
      end

      # @param interval [#to_s] The value measure chronological data by.
      # Accepted intervals are 'year', 'quarter', 'month', 'week', 'day', and 'hour'
      def time_series(field_name, interval)
        aggregates << "#{field_name}:time_series:#{interval}"
        self
      end
      # @!endgroup
    end

    class RangeBuilder

      attr_reader :builder

      attr_reader :search

      attr_reader :field

      extend Forwardable

      def initialize(builder, field)
        @builder = builder
        @search = builder.builder
        @field = field
      end

      def_delegator :@search, :options
      def_delegator :@search, :order
      def_delegator :@search, :limit
      def_delegator :@search, :offset
      def_delegator :@search, :aggregate
      def_delegator :@search, :find
      def_delegator :@builder, :stats
      def_delegator :@builder, :range
      def_delegator :@builder, :distance
      def_delegator :@builder, :time_series

      # @return string representation of the aggregate range param
      def to_s
        "#{field}"
      end
      alias :inspect :to_s

      def below(x)
        @field << "*~#{x}:"
        self
      end

      def above(x)
        @field << "#{x}~*:"
        self
      end

      def between(x, y)
        @field << "#{x}~#{y}:"
        self
      end
    end

    class DistanceBuilder < RangeBuilder
    end

    # An enumerator for searching an Orchestrate::Collection
    class SearchResults
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

      # Iterates over each result from the Search. Used as the basis for Enumerable methods.  Items are
      # provided on the basis of score, with most relevant first.
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
        raise ResultsNotReady.new if collection.app.inside_parallel?
        loop do
          @response.results.each do |listing|
            yield [ listing['score'], KeyValue.from_listing(collection, listing, @response) ]
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
      #   @yieldparam <(Orchestrate::Collection::Aggregate)>
      def each_aggregate
        @response ||= collection.perform(:search, query, options)
        @aggregates ||= @response.aggregates
        return enum_for(:each) unless block_given?
        raise ResultsNotReady.new if collection.app.inside_parallel?
        @aggregates.each do |listing|
          case listing['aggregate_kind']
          when 'stats'
            yield StatsAggregate.new(collection, listing)
          when 'range'
            yield RangeAggregate.new(collection, listing)
          when 'distance'
            yield DistanceAggregate.new(collection, listing)
          when 'time_series'
            yield TimeSeriesAggregate.new(collection, listing)
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

    class StatsAggregate
      
      attr_reader :collection

      attr_reader :kind

      attr_reader :field

      attr_reader :count

      attr_reader :statistics

      def initialize(collection, listing)
        @collection = collection
        @kind = listing['aggregate_kind']
        @field = listing['field_name']
        @count = listing['value_count']
        @statistics = listing['statistics']
      end

      # @return Pretty-Printed string representation of the Aggregate result object
      def to_s
        "#<Orchestrate::Collection::StatsAggregate collection=#{collection.name} field=#{field}>"
      end
      alias :inspect :to_s
    end

    class RangeAggregate
      
      attr_reader :collection

      attr_reader :kind

      attr_reader :field

      attr_reader :count

      attr_reader :buckets

      def initialize(collection, listing)
        @collection = collection
        @kind = listing['aggregate_kind']
        @field = listing['field_name']
        @count = listing['value_count']
        @buckets = listing['buckets']
      end

      # @return Pretty-Printed string representation of the Aggregate result object
      def to_s
        "#<Orchestrate::Collection::RangeAggregate collection=#{collection.name} field=#{field}>"
      end
      alias :inspect :to_s
    end

    class DistanceAggregate < RangeAggregate

      # @return Pretty-Printed string representation of the Aggregate result object
      def to_s
        "#<Orchestrate::Collection::DistanceAggregate collection=#{collection.name} field=#{field}>"
      end
      alias :inspect :to_s
    end

    class TimeSeriesAggregate
      attr_reader :collection

      attr_reader :kind

      attr_reader :field

      attr_reader :count

      attr_reader :buckets

      def initialize(collection, listing)
        @collection = collection
        @kind = listing['aggregate_kind']
        @field = listing['field_name']
        @count = listing['value_count']
        @interval = listing['interval']
        @buckets = listing['buckets']
      end

      # @return Pretty-Printed string representation of the Aggregate result object
      def to_s
        "#<Orchestrate::Collection::TimeSeriesAggregate collection=#{collection.name} field=#{field}>"
      end
      alias :inspect :to_s
    end

  end
end
