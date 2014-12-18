module Orchestrate

  class Search
    # @return [Collection] The collection this object will search.
    attr_reader :collection

    # @return [#to_s] The Lucene Query String given as the search query.
    attr_reader :query
    
    # @return [#to_s] The sorting parameters.
    attr_reader :sort

    # @return [#to_s] The string of aggregate function params to insert into the search query.
    attr_reader :aggregate

    # @return [Integer] The number of results to fetch per request.
    attr_reader :limit

    # @return [Integer] The number of results to fetch per request.
    attr_reader :offset

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
    # #order takes multiple arguments, but each even numbered argument must be either :asc or :desc
    # Odd-numbered arguments defaults to :asc
    # @example
    #   @app[:items].search("some_query").order(:name, :asc, :rank, :desc, :created_at)
    def order(*args)
      @sort = args.each_slice(2).map {|field, dir| dir ||= :asc; "#{field}:#{dir}" }.join(",")
      self
    end

    # Returns the first n items.  Equivalent to Enumerable#take.  Sets the
    # `limit` parameter on the query to Orchestrate, so we don't ask for more than is needed.
    # @param count [Integer] The number of items to limit to.
    # @return [Array]
    def take(count)
      @limit = count > 100 ? 100 : count
      self
    end

    # Sets the offset for the query to Orchestrate, so you can skip items.  Does not fire a request.
    # Impelemented as separate method from drop, unlike #take, because take is a more common use case.
    # @overload offset
    #   @return [Integer, nil] The number of items to skip.  Nil is equivalent to zero.
    # @overload offset(count)
    #   @param count [Integer] The number of items to skip.
    #   @return [SearchBuilder] self.
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
      @aggregate = @aggregate ? @aggregate << "," + stats : stats
      self
    end

    def range(field_name, *args)
      nums = args.each_slice(2).map {|first, last| dir ||= :asc; "#{first}~#{last}" }.join(":")
      range = "#{field_name}:range:#{nums}"
      @aggregate = @aggregate ? @aggregate << "," + range : range
      self
    end

    def distance(field_name, *args)
      nums = args.each_slice(2).map {|first, last| dir ||= :asc; "#{first}~#{last}" }.join(":")
      distance = "#{field_name}:distance:#{nums}"
      @aggregate = @aggregate ? @aggregate << "," + distance : distance
      self
    end

    # @param interval [#to_s] The value measure chronological data by.
    # Accepted intervals are 'year', 'quarter', 'month', 'week', 'day', and 'hour'
    def time_series(field_name, interval)
      time = "#{field_name}:time_series:#{interval}"
      @aggregate = @aggregate ? @aggregate << "," + time : time
      self
    end
    # @!endgroup

    # @return [SearchResults] A SearchResults object to enumerate over.
    def each(&block)
      options = self.build_params
      SearchResults.new(@collection, @query, options).each(&block)
    end

    def aggregates(&block)
      options = self.build_params
      AggregateResults.new(@collection, @query, options).each(&block)
    end

    def build_params
      params = {limit:limit}
      params[:aggregate] = aggregate if aggregate
      params[:offset] = offset if offset
      params[:sort] = sort if sort
      params
    end

    # An enumerator with a query for searching an Orchestrate::Collection
    class SearchResults
      # @return [Collection] The collection this object will search.
      attr_reader :collection

      # @return [#to_s] The Lucene Query String given as the search query.
      attr_reader :query

      # @return [Hash] The query paramaters.
      attr_reader :options

      attr_reader :response

      # Initialize a new SearchResults object
      # @param collection [Orchestrate::Collection] The collection to search.
      # @param query [#to_s] The Lucene Query to perform.
      def initialize(collection, query, options, response=nil)
        @collection = collection
        @query = query
        @options = options
        @response = response
      end

      include Enumerable

      # Iterates over each result from the Search.  Used as the basis for Enumerable methods.  Items are
      # provided on the basis of score, with most relevant first.
      # @overload each
      #   @return Enumerator
      # @overload each(&block)
      #   @yieldparam [Array<(Float, Orchestrate::KeyValue)>] score,key_value  The item's score and the item.
      # @example
      #   collection.search("trendy").take(5).each do |score, item|
      #     puts "#{item.key} has a trend score of #{score}"
      #   end
      def each
        @response ||= collection.perform(:search, query, options)
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

    class AggregateResults
      # @return [Collection] The collection this object will search.
      attr_reader :collection

      # @return [#to_s] The Lucene Query String given as the search query.
      attr_reader :query

      # @return [Hash] The query paramaters.
      attr_reader :options

      attr_reader :response

      # Initialize a new SearchResults object
      # @param collection [Orchestrate::Collection] The collection to search.
      # @param query [#to_s] The Lucene Query to perform.
      def initialize(collection, query, options, response=nil)
        @collection = collection
        @query = query
        @options = options
        @response = response
      end

      include Enumerable

      # Iterates over each result from the Search.  Used as the basis for Enumerable methods.  Items are
      # provided on the basis of score, with most relevant first.
      # @overload each
      #   @return Enumerator
      # @overload each(&block)
      #   @yieldparam [Array<(Float, Orchestrate::KeyValue)>] score,key_value  The item's score and the item.
      # @example
      #   collection.search("trendy").take(5).each do |score, item|
      #     puts "#{item.key} has a trend score of #{score}"
      #   end
      def each
        @response ||= collection.perform(:search, query, options)
        return enum_for(:each) unless block_given?
        raise ResultsNotReady.new if collection.app.inside_parallel?
        @response.aggregates.each do |listing|
          yield Aggregate.new(collection, listing)
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

    class Aggregate
      # @return [#to_s] The sorting parameters.
      attr_reader :collection

      def initialize(collection, listing)
        @collection = collection
        listing.each {|k,v| instance_variable_set("@#{k}",v)}
      end
    end      

  end
end
