module Orchestrate
  # Key/Value pairs are pieces of data identified by a unique key for
  # a collection and have corresponding value.
  class KeyValue

    # Instantiates and loads a KeyValue item.
    # @param collection [Orchestrate::Collection] The collection to which the KeyValue belongs.
    # @param key [#to_s] The key name.
    # @return Orchestrate::KeyValue The KeyValue item.
    # @raise Orchestrate::API::NotFound if there is no value for the provided key.
    def self.load(collection, key)
      kv = new(collection, key)
      kv.reload
      kv
    end

    # Instantiate a KeyValue from a PUT or POST request and known value
    # @param collection [Orchestrate::Collection] The collection to which the KeyValue belongs.
    # @param key [#to_s] The key name.
    # @param value [#to_json] The key's value.
    # @param response [Orchestrate::API::Response] The response that is associated with the PUT/POST.
    # @return Orchestrate::KeyValue The KeyValue item.
    def self.from_bodyless_response(collection, key, value, response)
      kv = new(collection, key, response)
      kv.value = value
      kv
    end

    # Instantiate a KeyValue from a listing in a LIST or SEARCH result
    # @param collection [Orchestrate::Collection] The collection to which the KeyValue belongs.
    # @param listing [Hash] The entry in the LIST or SEARCH result
    # @option listing [Hash] path **required** The path of the entry, with collection, key and ref keys.
    # @option listing [Hash] value **required** The value for the entry
    # @option listing [Time] reftime The time which the ref was created (only returned by LIST)
    # @param response [Orchestrate::API::Response] The response which the listing came from
    # @return Orchestrate::KeyValue The KeyValue item.
    def self.from_listing(collection, listing, response)
      path = listing.fetch('path')
      key = path.fetch('key')
      ref = path.fetch('ref')
      kv = new(collection, key, response)
      kv.instance_variable_set(:@ref, ref)
      kv.instance_variable_set(:@reftime, listing['reftime']) if listing['reftime']
      kv.value = listing.fetch('value')
      kv
    end

    # The collection this KeyValue belongs to.
    # @return [Orchestrate::Collection]
    attr_reader :collection

    # The name of the collection this KeyValue belongs to.
    # @return [String]
    attr_reader :collection_name

    # The key for this KeyValue.
    # @return [String]
    attr_reader :key

    # For comparison purposes only, the 'address' of this KeyValue item.
    # Represented as "[collection_name]/[key]"
    # @return [String]
    attr_reader :id

    # The ref for the current value for this KeyValue.
    # @return [String]
    attr_reader :ref

    # If known, the time at which this ref was created.
    # @return [Time, nil]
    attr_reader :reftime

    # The value for the KeyValue at this ref.
    # @return [#to_json]
    attr_accessor :value

    # Whether the KeyValue has been loaded from Orchestrate or not.
    # @return boolean
    attr_reader :loaded

    # When the KeyValue was last loaded from Orchestrate.
    # @return [Time]
    attr_reader :last_request_time

    # Instantiates a new KeyValue item.  You generally don't want to call this yourself, but rather use
    # the methods on Orchestrate::Collection to load a KeyValue.
    # @param coll [Orchestrate::Collection] The collection to which this KeyValue belongs.
    # @param key_name [#to_s] The name of the key
    # @param associated_response [nil, Orchestrate::API::Response]
    #   If an API::Request, used to load attributes and value.
    # @return Orchestrate::KeyValue
    def initialize(coll, key_name, associated_response=nil)
      @collection = coll
      @collection_name = coll.name
      @app = coll.app
      @key = key_name.to_s
      @id = "#{collection_name}/#{key}"
      load_from_response(associated_response) if associated_response
    end

    # Equivalent to `String#==`.  Compares by key and collection.
    # @param other [Orchestrate::KeyValue] the KeyValue to compare against.
    # @return [true, false]
    def ==(other)
      other.kind_of?(Orchestrate::KeyValue) && \
        other.collection == collection && \
        other.key == key
    end
    alias :eql? :==

    # Equivalent to `String#<=>`.  Compares by key and collection.
    # @param other [Orchestrate::KeyValue] the KeyValue to compare against.
    # @return [nil, -1, 0, 1]
    def <=>(other)
      return nil unless other.kind_of?(Orchestrate::KeyValue)
      return nil unless other.collection == collection
      other.key <=> key
    end

    # @return Pretty-Printed string representation of the KeyValue
    def to_s
      "#<Orchestrate::KeyValue id=#{id} ref=#{ref} last_request_time=#{last_request_time}>"
    end
    alias :inspect :to_s

    # If the KeyValue has been loaded or not.
    # @return [true, false] loaded
    def loaded?
      !! last_request_time
    end

    # Reload this KeyValue item from Orchestrate.
    # @raise Orchestrate::API::NotFound if the KeyValue no longer exists.
    def reload
      load_from_response(@app.client.get(collection_name, key))
    end

    # @!group Attribute accessors

    # Get an attribute from the KeyValue item's value.
    # @param attr_name [#to_s] The name of the attribute.
    # @return [nil, true, false, Numeric, String, Array, Hash] the value for the attribute.
    def [](attr_name)
      value[attr_name.to_s]
    end

    # Set a value to an attribute on the KeyValue item's value.
    # @param attr_name [#to_s] The name of the attribute.
    # @param attr_value [#to_json] The new value for the attribute.
    # @return [attr_value]
    def []=(attr_name, attr_value)
      value[attr_name.to_s] = attr_value
    end

    # @!endgroup
    #
    # @!group Persistence

    # Saves the KeyValue item to Orchestrate using 'If-Match' with the current ref.
    # Sets the new ref for this value to the ref attribute.
    # Returns false on failure to save, and rescues from all Orchestrate::API errors.
    # @return [true, false]
    def save
      begin
        save!
      rescue API::RequestError, API::ServiceError
        false
      end
    end

    # Saves the KeyValue item to Orchestrate using 'If-Match' with the current ref.
    # Sets the new ref for this value to the ref attribute.
    # Raises an exception on failure to save.
    # @return [true]
    # @raise [Orchestrate::API::VersionMismatch] If the KeyValue item has been updated with a new ref since this KeyValue was loaded.
    # @raise [Orchestrate::API::RequestError, Orchestrate::API::ServiceError] If there are any other problems with saving.
    def save!
      begin
        load_from_response(@app.client.put(collection_name, key, value, ref))
        true
      rescue API::IndexingConflict => e
        @ref = e.response.headers['Location'].split('/').last
        @last_request_time = Time.parse(e.response.headers['Date'])
        true
      end
    end

    # Merges a set of values into the item's existing value and saves.
    # @param merge [#each_pair] The Hash-like to merge into #value. Keys will be stringified.
    # @return [true, false]
    def update(merge)
      begin
        update!(merge)
      rescue API::RequestError, API::ServiceError
        false
      end
    end

    # Merges a set of values into the item's existing value and saves.
    # @param merge [#each_pair] The Hash-like to merge into #value.  Keys will be stringified.
    # @return [true]
    # @raise [Orchestrate::API::VersionMismatch] If the KeyValue item has been updated with a new ref since this KeyValue was loaded.
    # @raise [Orchestrate::API::RequestError, Orchestrate::API::ServiceError] If there was any other problem with saving.
    def update!(merge)
      merge.each_pair {|key, value| @value[key.to_s] = value }
      save!
    end

    # Deletes the KeyValue item from Orchestrate using 'If-Match' with the current ref.
    # Returns false if the item failed to delete because a new ref had been created since this KeyValue was loaded.
    # @return [true, false]
    def destroy
      begin
        destroy!
      rescue API::VersionMismatch
        false
      end
    end

    # Deletes a KeyValue item from Orchestrate using 'If-Match' with the current ref.
    # @raise [Orchestrate::API::VersionMismatch] If the KeyValue item has been updated with a new ref since this KeyValue was loaded.
    def destroy!
      response = @app.client.delete(collection_name, key, ref)
      @ref = nil
      @last_request_time = response.request_time
      true
    end

    # Deletes a KeyValue item and its entire Ref history from Orchestrate using 'If-Match' with the current ref.
    # Returns false if the item failed to delete because a new ref had been created since this KeyValue was loaded.
    # @return [true, false]
    def purge
      begin
        purge!
      rescue API::VersionMismatch
        false
      end
    end

    # Deletes a KeyValue item and its entire Ref history from Orchestrate using 'If-Match' with the current ref.
    # @raise [Orchestrate::API::VersionMismatch] If the KeyValue item has been updated with a new ref since this KeyValue was loaded.
    def purge!
      response = @app.client.purge(collection_name, key, ref)
      @ref = nil
      @last_request_time = response.request_time
      true
    end

    # @!endgroup persistence
    #
    # @!group relations

    # Entry point for managing the graph relationships for this KeyValue item
    # @return [Orchestrate::Graph] A graph instance bound to this item.
    def relations
      @relations ||= Graph.new(self)
    end

    # @!endgroup relations

    private
    def load_from_response(response)
      response.on_complete do
        @ref = response.ref if response.respond_to?(:ref)
        @value = response.body unless response.body.respond_to?(:strip) && response.body.strip.empty?
        @last_request_time = response.request_time
      end
    end

  end
end
