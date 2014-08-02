module Orchestrate
  # A Ref is a specific immutable value that has been assigned to a Key.
  #
  # Ref is subclassed from KeyValue and as such contains its `#save` and `#update`
  # methods.  Unless used on the most recent Ref, these will fail with a
  # VersionMismatch error, as the #save and #update methods use Put-If-Match
  # semantics.
  class Ref < KeyValue

    # Is this a historic ref value?  True for Ref objects.  Use this instead of
    # `#is_a?` or `#kind_of?`.
    # @return [true, false]
    def archival?
      true
    end
  end

  # An enumerator over a query for listing Ref values in an Orchestrate::KeyValue.
  class RefList

    # @return [KeyValue]
    attr_accessor :key_value

    # Instantiates a new RefList
    # @param key_value [KeyValue] The KeyValue item to retrieve Refs for.
    def initialize(key_value)
      @key_value = key_value
    end

    # Accessor for individual Refs.
    # @param ref_id [#to_s] The ref of the specific immutable value to retrieve.
    def [](ref_id)
      response = @key_value.perform(:get, ref_id)
      Ref.new(@key_value.collection, @key_value.key, response)
    end

    # @!group Ref Enumeration

    include Enumerable

    # Iterates over each Ref for the KeyValue.  Used as the basis for Enumerable.
    # Refs are provided in time-series order, newest to oldest.
    # @overload each
    #   @return Enumerator
    # @overload each(&block)
    #   @yieldparam [Ref] ref the Ref item
    # @see RefList::Fetcher#each
    # @example
    #   ref_ids = kv.refs.take(20).map(&:ref)
    def each(&block)
      Fetcher.new(self).each(&block)
    end

    # Creates a Lazy Enumerator for the RefList.  If called inside the Applciation's
    # `#in_parallel` block, pre-fetches the first page of results.
    # @return [Enumerator::Lazy]
    def lazy
      Fetcher.new(self).lazy
    end

    # Returns the first n items.  Equivalent to Enumerable#take.  Sets the `limit`
    # parameter on the query to Orchestrate, so we don't ask for more items
    # than desired.
    # @return [Array<Ref>]
    def take(count)
      Fetcher.new(self).take(count)
    end

    # Set the offset for the query to Orchestrate, so you can skip items.  Does
    # not fetch results.  Implemented as a separate method from drop, unlike #take,
    # because take is a more common use case.
    # @return [RefList::Fetcher]
    def offset(count)
      Fetcher.new(self).offset(count)
    end

    # Specifies that the query to Orchestrate should use the `values` parameter,
    # and that the query should return the values for each ref.
    # @return [RefList::Fetcher]
    def with_values
      Fetcher.new(self).with_values
    end

    # @!endgroup

    # Responsible for actually retrieving the list of Refs from Orchestrate.
    class Fetcher

      # The KeyValue to retrieve Refs for.
      # @return [KeyValue]
      attr_accessor :key_value

      # The maximum number of Refs to return.
      # @return [Integer]
      attr_accessor :limit

      # Whether to request values for each Ref or not.
      # @return [nil, true] defaults to nil
      attr_accessor :values

      # Instantiates a new RefList::Fetcher.
      # @param reflist [RefList] The RefList to base the queries on.
      def initialize(reflist)
        @key_value = reflist.key_value
        @limit = 100
      end

      include Enumerable

      # @!group Ref Enumeration

      # Iterates over each Ref for the KeyValue.  Used as the basis for Enumerable.
      # Refs are provided in time-series order, newest to oldest.
      # @overload each
      #   @return Enumerator
      # @overload each(&block)
      #   @yieldparam [Ref] ref the Ref item
      # @example
      #   ref_enum = kv.refs.each
      def each
        params = {limit: limit}
        params[:offset] = offset if offset
        params[:values] = true if values
        @response ||= key_value.perform(:list_refs, params)
        return enum_for(:each) unless block_given?
        raise ResultsNotReady.new if key_value.collection.app.inside_parallel?
        loop do
          @response.results.each do |doc|
            yield Ref.from_listing(key_value.collection, doc, @response)
          end
          break unless @response.next_link
          @response = @response.next_results
        end
        @response = nil
      end

      # Creates a Lazy Enumerator for the Fetcher.  If called inside the Application's
      # `#in_parallel` block, pre-fetches the first page of results.
      # @return [Enumerator::Lazy]
      def lazy
        return each.lazy if key_value.collection.app.inside_parallel?
        super
      end

      # Returns the first n items.  Equivalent to Enumerable#take.  Sets the `limit`
      # parameter on the query to Orchestrate, so we don't ask for more items than
      # desired.
      # @param count [Integer] A positive integer constrained between 1 and 100.
      # @return [Array<Ref>]
      def take(count)
        count = 1 if count < 1
        count = 100 if count > 100
        @limit = count
        super(count)
      end

      # Sets the offset for the query to Orchestrate, so you can skip items.  Does
      # not fetch results.  Implemented as a separate method from drop, unlike #take,
      # because take is a more common use case.
      # @overload offset
      #   @return [Integer] the current offset value
      # @overload offset(count)
      #   @param count [Integer] The number of records to skip.  Constrained to positive integers.
      #   @return [self]
      def offset(count=nil)
        if count
          count = 1 if count < 1
          @offset = count.to_i
          return self
        else
          @offset
        end
      end

      # Specifies the query to Orchestrate shoul duse the `values` parameter,
      # and the query should return values for each ref.
      # @return [self]
      def with_values
        @values = true
        self
      end
    end
  end
end
