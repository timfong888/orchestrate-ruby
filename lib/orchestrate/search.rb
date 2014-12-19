module Orchestrate
  # Search builder object for constructing queries
  class Search
    # @return [Collection] The collection this object will search.
    attr_reader :collection

    # @return [#to_s] The Lucene Query String given as the search query.
    attr_reader :query

    # @return [#to_s] The sorting parameters.
    attr_reader :sort

    # @return [#to_s] The aggregate parameters to insert into the search query.
    attr_reader :aggregate

    # Initialize a new SearchBuilder object
    # @param collection [Orchestrate::Collection] The collection to search.
    # @param query [#to_s] The Lucene Query to perform.
    def initialize(collection, query)
      @collection = collection
      @query = query
      @aggregate = nil
      @sort = nil
      @limit = 100
      @offset = nil
    end

    # Sets the sorting parameters for a query's Search Results.
    # #order takes multiple arguments,
    # but each even numbered argument must be either :asc or :desc
    # Odd-numbered arguments defaults to :asc
    # @example
    #   @app[:items].search("foo").order(:name, :asc, :rank, :desc, :created_at)
    def order(*args)
      @sort = args.each_slice(2).map {|field, dir| dir ||= :asc; "#{field}:#{dir}" }.join(',')
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
        @limit = count > 100 ? 100 : count
        self
      else
        @limit
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
        @offset = count
        self
      else
        @offset
      end
    end

    # @!group Aggregate Queries
    def stats(field_name)
      stats = "#{field_name}:stats"
      @aggregate = @aggregate ? @aggregate << ',' + stats : stats
      self
    end

    def range(field_name, *args)
      nums = args.each_slice(2).map {|first, last| dir ||= :asc; "#{first}~#{last}" }.join(":")
      range = "#{field_name}:range:#{nums}"
      @aggregate = @aggregate ? @aggregate << ',' + range : range
      self
    end

    def distance(field_name, *args)
      nums = args.each_slice(2).map {|first, last| dir ||= :asc; "#{first}~#{last}" }.join(":")
      distance = "#{field_name}:distance:#{nums}"
      @aggregate = @aggregate ? @aggregate << ',' + distance : distance
      self
    end

    # @param interval [#to_s] The value measure chronological data by.
    # Accepted intervals are 'year', 'quarter', 'month', 'week', 'day', and 'hour'
    def time_series(field_name, interval)
      time = "#{field_name}:time_series:#{interval}"
      @aggregate = @aggregate ? @aggregate << ',' + time : time
      self
    end
    # @!endgroup

    # @return [SearchResults] A SearchResults object to enumerate over.
    def execute
      params = {limit:limit}
      params[:aggregate] = aggregate if aggregate
      params[:offset] = offset if offset
      params[:sort] = sort if sort
      response = collection.perform(:search, query, params)
      SearchResults.new(collection, query, params, response)
    end

    def lazy
      params = {limit:limit}
      params[:aggregate] = aggregate if aggregate
      params[:offset] = offset if offset
      params[:sort] = sort if sort
      SearchResults.new(collection, query, params, nil).lazy
    end

    # An enumerator for searching an Orchestrate::Collection
    class SearchResults
      # @return [Collection] The collection this object will search.
      attr_reader :collection

      # @return [#to_s] The Lucene Query String given as the search query.
      attr_reader :query

      # @return [Hash] The query paramaters.
      attr_reader :options

      # Initialize a new SearchResults object
      # @param collection [Orchestrate::Collection] The collection searched.
      # @param query [#to_s] The Lucene Query performed.
      # @param options [Hash] The query parameters.
      # @param response [CollectionResponse] The initial Collection Response from the search query.
      def initialize(collection, query, options, response)
        @collection = collection
        @query = query
        @options = options
        @response = response
        @aggregates = nil
      end

      # @return [#to_json] The aggregate results.
      def aggregates
        @aggregates ||= @response.aggregates
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

      # Creates a Lazy Enumerator for the Search Results.  If called inside its
      # app's `in_parallel` block, will pre-fetch results.
      def lazy
        return each.lazy if collection.app.inside_parallel?
        super
      end
    end

    # class StatsAggregate
      
    #   attr_reader :collection

    #   attr_reader :kind

    #   attr_reader :field

    #   attr_reader :count

    #   attr_reader :statistics

    #   def initialize(collection, listing)
    #     @collection = collection
    #     @kind = listing['aggregate_kind']
    #     @field = listing['field_name']
    #     @count = listing['value_count']
    #     @statistics = listing['statistics']
    #   end
    # end

    # class RangeAggregate
      
    #   attr_reader :collection

    #   attr_reader :kind

    #   attr_reader :field

    #   attr_reader :count

    #   attr_reader :buckets

    #   def initialize(collection, listing)
    #     @collection = collection
    #     @kind = listing['aggregate_kind']
    #     @field = listing['field_name']
    #     @count = listing['value_count']
    #     @buckets = listing['buckets']
    #   end
    # end

    # class DistanceAggregate < RangeAggregate 
    # end

    # class TimeSeriesAggregate
    #   attr_reader :collection

    #   attr_reader :kind

    #   attr_reader :field

    #   attr_reader :count

    #   attr_reader :interval

    #   attr_reader :buckets

    #   def initialize(collection, listing)
    #     @collection = collection
    #     @kind = listing['aggregate_kind']
    #     @field = listing['field_name']
    #     @count = listing['value_count']
    #     @interval = listing['interval']
    #     @buckets = listing['buckets']
    #   end
    # end

  end
end
