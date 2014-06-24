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
      app.client.delete_collection(name)
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
      resp = app.client.put(name, key_name, value, condition)
      kv = KeyValue.new(self, key_name, resp)
      kv.value = value
      kv
    end

    # [Creates a KeyValue item with an auto-generated
    # key](http://orchestrate.io/docs/api/#key/value/post-\(create-&-generate-key\))
    # @param value [#to_json] The value to store
    # @return [Orchestrate::KeyValue] The KeyValue created.
    # @note If the create is considered a success but the client is unable to parse the key
    #   from the location header, an API::ServiceError is raised.
    def <<(value)
      response = app.client.post(name, value)
      match_data = response.location.match(%r{#{name}/([^/]+)})
      raise API::ServiceError.new(response) unless match_data
      kv = KeyValue.new(self, match_data[1], response)
      kv.value = value
      kv
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

    # [Deletes the value for a KeyValue
    # item](http://orchestrate.io/docs/api/#key/value/delete12).
    # @param key_name [#to_s] The name of the key
    # @return [true] If the request suceeds.
    def delete(key_name)
      app.client.delete(name, key_name)
      true
    end

    # [Purges a KeyValue item and its Ref
    # history](http://orchestrate.io/docs/api/#key/value/delete12).
    # @param key_name [#to_s] The name of the key
    # @return [true] If the request suceeds.
    def purge(key_name)
      app.client.purge(name, key_name)
      true
    end

    # @!endgroup


    include Enumerable
    # @!group KeyValue enumerators

    # Lazily iterates over each KeyValue item in the collection.  Used as the basis for Enumerable methods.
    # Items are provided in lexicographically sorted order by key name.
    # @yieldparam [Orchestrate::KeyValue] key_value The KeyValue item
    # @example
    #   keys = collection.take(20).map(&:key)
    #   # returns the first 20 keys in the collection.
    def each
      return enum_for(:each) unless block_given?
      response = app.client.list(name)
      loop do
        response.results.each do |doc|
          yield KeyValue.new(self, doc, response.request_time)
        end
        break unless response.next_link
        response = response.next_results
      end
    end

    # @!endgroup

  end
end
