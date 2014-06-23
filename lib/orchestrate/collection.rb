module Orchestrate
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

    # Deletes the collection.
    # @return Orchestrate::API::Response
    def destroy!
      app.client.delete_collection(name)
    end

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

    # [Creates a KeyValue item by key, if the key doesn't have
    # a value](http://orchestrate.io/docs/api/#key/value/put-\(create/update\)).
    # @param key_name [#to_s] The name of the key
    # @param value [#to_json] The value to store at the key
    # @return [Orchestrate::KeyValue, nil] The KeyValue if created, false if not
    def create(key_name, value)
      set(key_name, value, false)
    rescue Orchestrate::API::AlreadyPresent
      false
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

    # @!visibility private
    def to_s
      "#<Orchestrate::Collection name=#{name} api_key=#{app.api_key[0..7]}...>"
    end
    alias :inspect :to_s

  end
end
