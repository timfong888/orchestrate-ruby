module Orchestrate
  # Collections are groupings of KeyValue items.  They are analagous to tables in SQL databases.
  class Collection

    # @return [Orchestrate::Application] The application this collection belongs to.
    attr_reader :app

    # @return [String] The name of this collection.
    attr_reader :name

    # Instantiate the Collection
    # @param app [Orchestrate::Client, Orchestrate::Application] The application the Collection belongs to.
    # @param collection_name [#to_s] The name of the collection.
    # @return Orchestrate::Collection
    def initialize(app, collection_name)
      if app.kind_of? Orchestrate::Client
        @app = Application.new(app)
      else
        @app = app
      end
      @name = collection_name.to_s
    end

    # @return a pretty-printed representation of the collection.
    def to_s
      "#<Orchestrate::Collection name=#{name} api_key=#{app.api_key[0..7]}...>"
    end
    alias :inspect :to_s

    # Equivalent to `String#==`.  Compares by name and app's api_key.
    # @param other [Orchestrate::Collection] the collection to compare against.
    # @return [true, false]
    def ==(other)
      other.kind_of?(Orchestrate::Collection) && \
        other.app.api_key == app.api_key && \
        other.name == name
    end
    alias :eql? :==

    # Equivalent to `String#<=>`.  Compares by name and app's api_key.
    # @param other [Orchestrate::Collection] the collection to compare against.
    # @return [nil, -1, 0, 1]
    def <=>(other)
      return nil unless other.kind_of?(Orchestrate::Collection)
      return nil unless other.app.api_key == app.api_key
      other.name <=> name
    end

    # @!group Collection api

    # Deletes the collection.
    # @return Orchestrate::API::Response
    def destroy!
      perform :delete_collection
    end

    # @!endgroup

    # @!group KeyValue getters, setters

    # [Retrieves a KeyValue item by key](http://orchestrate.io/docs/api/#key/value/get).
    # @param key_name [#to_s] The key of the item
    # @return [Orchestrate::KeyValue, nil] The KeyValue item if found, nil if not.
    def [](key_name)
      begin
        KeyValue.load(self, key_name)
      rescue API::NotFound
        nil
      end
    end

    # [Sets a KeyValue item by key](http://orchestrate.io/docs/api/#key/value/put-\(create/update\)).
    # @param key_name [#to_s] The key of the item.
    # @param value [#to_json] The value to store at the key.
    # @return [value] The item provided for 'value'.
    # @note Ruby will return the value provided to `something=` methods.  If you want the KeyValue returned, use #set.
    # @raise Orchestrate::API::BadRequest the body is not valid JSON.
    # @see #set
    def []=(key_name, value)
      set(key_name, value)
    end

    # [Sets a KeyValue item by key](http://orchestrate.io/docs/api/#key/value/put-\(create/update\)).
    # @param key_name [#to_s] The key of the item.
    # @param value [#to_json] The value to store at the key.
    # @param condition [nil, false, #to_s] (see Orchestraate::Client#put)
    # @return [Orchestrate::KeyValue] The new KeyValue item.
    # @raise Orchestrate::API::BadRequest the body is not valid JSON.
    # @raise Orchestrate::API::VersionMismatch a String condition was provided, but does not match the ref for the current value.
    # @raise Orchestrate::API::AlreadyPresent a false condition was provided, but a value already exists for this key
    # @see #[]=
    def set(key_name, value, condition=nil)
      response = perform(:put, key_name, value, condition)
      KeyValue.from_bodyless_response(self, key_name, value, response)
    end

    # [Creates a KeyValue item with an auto-generated
    # key](http://orchestrate.io/docs/api/#key/value/post-\(create-&-generate-key\))
    # @param value [#to_json] The value to store
    # @return [Orchestrate::KeyValue] The KeyValue created.
    # @note If the create is considered a success but the client is unable to parse the key
    #   from the location header, an API::ServiceError is raised.
    def <<(value)
      response = perform(:post, value)
      match_data = response.location.match(%r{#{name}/([^/]+)})
      raise API::ServiceError.new(response) unless match_data
      KeyValue.from_bodyless_response(self, match_data[1], value, response)
    end

    # Creates a KeyValue item in the collection.
    # @overload create(value)
    #   (see #<<)
    #   [Creates a KeyValue item with an auto-generated
    #   key](http://orchestrate.io/docs/api/#key/value/post-\(create-&-generate-key\))
    #   @param value [#to_json] The value to store
    #   @return [Orchestrate::KeyValue] The KeyValue created.
    #   @note If the create is considered a success but the client is unable to parse the key
    #     from the location header, an API::ServiceError is raised.
    # @overload create(key_name, value)
    #   [Creates a KeyValue item by key, if the key doesn't have
    #   a value](http://orchestrate.io/docs/api/#key/value/put-\(create/update\)).
    #   @param key_name [#to_s] The name of the key
    #   @param value [#to_json] The value to store at the key
    #   @return [Orchestrate::KeyValue, nil] The KeyValue if created, false if not
    def create(key_name_or_value, value=nil)
      if value.nil? and key_name_or_value.respond_to?(:to_json)
        self << key_name_or_value
      else
        begin
          set(key_name_or_value, value, false)
        rescue Orchestrate::API::AlreadyPresent
          false
        end
      end
    end

    # Builds a new, unsaved KeyValue with the given key_name and value.
    # @param key_name [#to_s] The key of the item
    # @param value [#to_json] The value to store at the key.
    # @return [KeyValue]
    def build(key_name, value={})
      kv = KeyValue.new(self, key_name)
      kv.value = value
      kv
    end

    # Returns an unloaded KeyValue object with the given key_name, if you need
    # to access Refs, Relations or Events without loading the KeyValue's value.
    # @param key_name [#to_s] The key of the item.
    # @return [KeyValue]
    def stub(key_name)
      kv = KeyValue.new(self, key_name)
      kv.value = nil
      kv
    end

    # [Deletes the value for a KeyValue
    # item](http://orchestrate.io/docs/api/#key/value/delete12).
    # @param key_name [#to_s] The name of the key
    # @return [true] If the request suceeds.
    def delete(key_name)
      perform(:delete, key_name)
      true
    end

    # [Purges a KeyValue item and its Ref
    # history](http://orchestrate.io/docs/api/#key/value/delete12).
    # @param key_name [#to_s] The name of the key
    # @return [true] If the request suceeds.
    def purge(key_name)
      perform(:purge, key_name)
      true
    end

    # @!endgroup


    include Enumerable
    # @!group KeyValue enumerators

    # Iterates over each KeyValue item in the collection.  Used as the basis for Enumerable methods.
    # Items are provided in lexicographically sorted order by key name.
    # @overload each
    #   @return [Enumerator]
    # @overload each(&block)
    #   @yieldparam [Orchestrate::KeyValue] key_value The KeyValue item
    # @see KeyValueList#each
    # @example
    #   keys = collection.take(20).map(&:key)
    #   # returns the first 20 keys in the collection.
    def each(&block)
      KeyValueList.new(self).each(&block)
    end

    # Creates a Lazy Enumerator for the Collection's KeyValue List.  If called inside the app's
    # `#in_parallel` block, pre-fetches the first page of results.
    # @return [Enumerator::Lazy]
    def lazy
      KeyValueList.new(self).lazy
    end

    # Sets the inclusive start key for enumeration over the KeyValue items in the collection.
    # @see KeyValueList#start
    # @return [KeyValueList]
    def start(start_key)
      KeyValueList.new(self).start(start_key)
    end

    # Sets the exclusive start key for enumeration over the KeyValue items in the collection.
    # @see KeyValueList#after
    # @return [KeyValueList]
    def after(start_key)
      KeyValueList.new(self).after(start_key)
    end

    # Sets the exclusive end key for enumeration over the KeyValue items in the collection.
    # @see KeyValueList#before
    # @return [KeyValueList]
    def before(end_key)
      KeyValueList.new(self).before(end_key)
    end

    # Sets the inclusive end key for enumeration over the KeyValue items in the collection.
    # @see KeyValueList#end
    # @return [KeyValueList]
    def end(end_key)
      KeyValueList.new(self).end(end_key)
    end

    # Returns the first n items.  Equivalent to Enumerable#take.  Sets the
    # `limit` parameter on the query to Orchestrate, so we don't ask for more than is needed.
    # @param count [Integer] The number of items to limit to.
    # @return [Array<KeyValue>]
    def take(count)
      KeyValueList.new(self).take(count)
    end

    # @!endgroup

    # An enumerator with boundaries for performing a [KeyValue List
    # query](http://orchestrate.io/docs/api/#key/value/list) against a collection.
    class KeyValueList
      # @return [Collection] The collection which this KeyValueList enumerates over.
      attr_reader :collection

      # @return [Hash] parameters for setting the boundaries of the enumeration.
      attr_reader :range

      # Instantiate a new KeyValueList to enumerate over a collection
      # @param collection [Collection] the collection to enumerate over.
      # @param range [Hash] parameters for setting the boundaries of the enumeration.
      # @option range [#to_s] :begin The beginning of the range.
      # @option range [true, false] :begin_inclusive Whether the begin key is inclusive or not.
      # @option range [#to_s] :end The end of the range.
      # @option range [true, false] :end_inclusive Whether the end key is inclusive or not.
      # @return KeyValueList
      def initialize(collection, range={})
        @collection = collection
        @range = range
        range[:limit] ||= 100
      end

      # Sets the inclusive start key for enumeration over the KeyValue items in the collection.
      # Overwrites any value given to #after.
      # @param start_key [#to_s] The inclusive start of the key range.
      # @return [KeyValueList] A new KeyValueList with the new range.
      def start(start_key)
        self.class.new(collection, range.merge({begin: start_key, begin_inclusive: true}))
      end

      # Sets the exclusive start key for enumeration over the KeyValue items in the collection.
      # Overwrites any value given to #start.
      # @param start_key [#to_s] The exclusive start of the key range.
      # @return [KeyValueList] A new KeyValueList with the new range.
      def after(start_key)
        self.class.new(collection, range.merge({begin: start_key, begin_inclusive: false}))
      end

      # Sets the exclusive end key for enumeration over the KeyValue items in the collection.
      # Overwrites any value given to #end.
      # @param end_key [#to_s] The exclusive end of the key range.
      # @return [KeyValueList] A new KeyValueList with the new range.
      def before(end_key)
        self.class.new(collection, range.merge({end: end_key, end_inclusive: false}))
      end

      # Sets the inclusive end key for enumeration over the KeyValue items in the collection.
      # Overwrites any value given to #before.
      # @param end_key [#to_s] The inclusive end of the key range.
      # @return [KeyValueList] A new KeyValueList with the new range.
      def end(end_key)
        self.class.new(collection, range.merge({end: end_key, end_inclusive: true}))
      end

      include Enumerable

      # Iterates over each KeyValue item in the collection.  Used as the basis for Enumerable methods.
      # Items are provided in lexicographically sorted order by key name.
      # @overload each
      #   @return Enumerator
      # @overload each(&block)
      #   @yieldparam [Orchestrate::KeyValue] key_value The KeyValue item
      # @example
      #   keys = collection.after(:foo).take(20).map(&:key)
      #   # returns the first 20 keys in the collection that occur after "foo"
      def each
        params = {}
        if range[:begin]
          begin_key = range[:begin_inclusive] ? :start : :after
          params[begin_key] = range[:begin]
        end
        if range[:end]
          end_key = range[:end_inclusive] ? :end : :before
          params[end_key] = range[:end]
        end
        params[:limit] = range[:limit]
        @response ||= collection.perform(:list, params)
        return enum_for(:each) unless block_given?
        raise ResultsNotReady.new if collection.app.inside_parallel?
        loop do
          @response.results.each do |doc|
            yield KeyValue.from_listing(collection, doc, @response)
          end
          break unless @response.next_link
          @response = @response.next_results
        end
        @response = nil
      end

      # Creates a Lazy Enumerator for the KeyValue list.  If called inside the
      # app's `#in_parallel` block, will prefetch results.
      def lazy
        return each.lazy if collection.app.inside_parallel?
        super
      end

      # Returns the first n items.  Equivalent to Enumerable#take.  Sets the
      # `limit` parameter on the query to Orchestrate, so we don't ask for more than is needed.
      # @param count [Integer] The number of items to limit to.
      # @return [Array]
      def take(count)
        count = 1 if count < 1
        range[:limit] = count > 100 ? 100 : count
        super(count)
      end
    end

    # @param query [#to_s] The [Lucene Query
    #   String](http://lucene.apache.org/core/4_3_0/queryparser/org/apache/lucene/queryparser/classic/package-summary.html#Overview)
    #   to query the collection with.
    # @return [Orchestrate::Search::QueryBuilder] A builder object to construct the query.
    def search(query)
      Search::QueryBuilder.new(self, query)
    end

    # @!group Geo Queries
    # Performs a search for items near a specified geographic point in a collection.
    # [Search for items near a geographic point](http://orchestrate.io/docs/apiref#geo-queries-near)
    # @param field [#to_s] The field containing location data (latitude & longitude)
    # @param latitude [Float] The number representing latitude of a geographic point
    # @param longitude [Float] The number representing longitude of a geographic point
    # @param distance [Integer] The number of distance units.
    # @param units [#to_s] Unit of measurement for distance, default to kilometers (km),
    # supported units: km, m, cm, mm, mi, yd, ft, in, nmi
    # @return [Orchestrate::Search::QueryBuilder] A builder object to construct the query.
    def near(field, latitude, longitude, distance, units=nil)
      units ||= 'km'
      query = "#{field}:NEAR:{lat:#{latitude} lon:#{longitude} dist:#{distance}#{units}}"
      Search::QueryBuilder.new(self, query)
    end

    # Performs a search for items within a particular area, 
    # using a specified bounding box
    # [Search for items in a geographic bounding box](https://orchestrate.io/docs/apiref#geo-queries-bounding)
    # @param field [#to_s] The field containing location data (latitude & longitude)
    # @param box [#to_json] The values to create the bounding box,
    # @example
    #   collection.in(:field, {north: 12.5, south: 15, east: 14, west: 3})
    # @return [Orchestrate::Search::QueryBuilder] A builder object to construct the query.
    def in(field, box={})
      box = box.flatten.each_slice(2).map {|dir, val| "#{dir}:#{val}" }.join(" ")
      query = "#{field}:IN:{#{box}}"
      Search::QueryBuilder.new(self, query)
    end
    # @!endgroup

    # Tells the Applicaiton to perform a request on its client, automatically
    # providing the collection name.
    # @param api_method [Symbol] The method on the client to call.
    # @param args [#to_s, #to_json, Hash] The arguments for the method.
    # @return API::Response
    def perform(api_method, *args)
      app.perform(api_method, name, *args)
    end

  end
end
