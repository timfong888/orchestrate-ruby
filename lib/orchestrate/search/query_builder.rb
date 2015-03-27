module Orchestrate::Search
  # Query Builder object for constructing search queries
  class QueryBuilder
    # @return [Collection] The collection this object will search.
    attr_reader :collection

    # Initialize a new SearchBuilder object
    # @param collection [Orchestrate::Collection] The collection to search.
    # @param query [#to_s] The Lucene Query to perform.
    def initialize(collection, query)
      @collection = collection
      @query = query
      @kinds = []
      @types = []
    end

    # @return [#to_s] The Lucene Query String.
    def query
      query = "(#{@query})"
      query << " AND @path.kind:(#{@kinds.join(' ')})" if @kinds.any?
      query << " AND @path.type:(#{@types.join(' ')})" if @types.any?
      query
    end

    # @return Pretty-Printed string representation of the Search object
    def to_s
      "#<Orchestrate::Search::QueryBuilder collection=#{collection.name} query=#{query} options=#{options}>"
    end
    alias :inspect :to_s

    # @return [Hash] Optional parameters for the search query.
    def options
      @options ||= { limit: 100 }
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

    # Sets the 'kind' to search.
    # @param kinds [Array<String>] The orchestrate kinds to be included ('item' or 'event').
    # @return [QueryBuilder] self.
    def kinds(*kinds)
      @kinds = kinds
      self
    end

    # Sets the event types to search.
    # @param types [Array<String>] The orchestrate event types to search (e.g. 'activities', 'wall_posts')
    # @return [QueryBuilder] self.
    def types(*types)
      @types = types
      self
    end

    # @return [AggregateBuilder] An AggregateBuilder object to construct aggregate search params
    def aggregate
      options[:aggregate] ||= AggregateBuilder.new(self)
    end

    # @return [Orchestrate::Search::Results] A Results object to enumerate over.
    def find
      options[:aggregate] = options[:aggregate].to_param if options[:aggregate]
      Results.new(collection, query, options)
    end
  end
end
