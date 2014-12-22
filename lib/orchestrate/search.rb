module Orchestrate

  class Collection

    # Search Builder object for constructing search queries
    class SearchBuilder
      # @return [Collection] The collection this object will search.
      attr_reader :collection

      # @return [#to_s] The Lucene Query String given as the search query.
      attr_reader :query

      # @return [#to_s] The sorting parameters.
      attr_reader :sort

      attr_reader :aggregates

      # Initialize a new SearchBuilder object
      # @param collection [Orchestrate::Collection] The collection to search.
      # @param query [#to_s] The Lucene Query to perform.
      def initialize(collection, query)
        @collection = collection
        @query = query
        @aggregates = nil
        @sort = nil
        @limit = 100
        @offset = nil
      end

      # @return Pretty-Printed string representation of the Search object
      def to_s
        "#<Orchestrate::Collection::SearchBuilder collection=#{collection.name} query=#{query} aggregate=#{aggregates} sort=#{sort} limit=#{limit} offset=#{offset}>"
      end
      alias :inspect :to_s

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

      def aggregate
        AggregateBuilder.new(self)
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

      # @return [SearchResults] A SearchResults object to enumerate over.
      def execute
        params = build
        response = collection.perform(:search, query, params)
        SearchResults.new(collection, query, params, response, response.aggregates)
      end

      def lazy
        params = build
        SearchResults.new(collection, query, params, nil, nil).lazy
      end

      def build
        params = {limit:limit}
        params[:offset] = offset if offset
        params[:sort] = sort if sort
        params[:aggregate] = aggregates if aggregates
        params
      end

      def set_aggregates(arg)
        @aggregates = @aggregates ? @aggregates << arg : arg
      end
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
      def initialize(collection, query, options, response, aggregates)
        @collection = collection
        @query = query
        @options = options
        @response = response
        @aggregates = aggregates 
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

  end
end
