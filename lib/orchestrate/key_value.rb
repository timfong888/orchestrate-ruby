module Orchestrate
  # Key/Value pairs are pieces of data identified by a unique key for
  # a collection and have corresponding value.
  class KeyValue

    # Instantiates and loads a KeyValue item.
    # @param collection [Orchestrate::Collection] The collection to which the KeyValue belongs.
    # @param key [#to_s] The key name.
    # @return Orchestrate::KeyValue key_value The KeyValue item.
    # @raise Orchestrate::API::NotFound if there is no value for the provided key.
    def self.load(collection, key)
      kv = new(collection, key)
      kv.reload
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
    # @param key_name_or_listing [Hash] A listing result from Client#list
    # @param key_name_or_listing [#to_s] The name of the key
    # @param response_or_request_time [nil, Time, Orchestrate::API::Response]
    #   If key_name_or_listing is a listing, and this value is a Time, used to set last_request_time.
    #   Otherwise if an API::Request, used to load attributes and value.
    # @return Orchestrate::KeyValue
    def initialize(coll, key_name_or_listing, response_or_request_time=nil)
      @collection = coll
      @collection_name = coll.name
      @app = coll.app
      if key_name_or_listing.kind_of?(Hash)
        path = key_name_or_listing.fetch('path')
        @key = path.fetch('key')
        @ref = path.fetch('ref')
        @reftime = Time.at(key_name_or_listing.fetch('reftime') / 1000.0)
        @value = key_name_or_listing.fetch('value')
        @last_request_time = response_or_request_time if response_or_request_time.kind_of?(Time)
      else
        @key = key_name_or_listing.to_s
      end
      @id = "#{collection_name}/#{key}"
      load_from_response(response) if response_or_request_time.kind_of?(API::Response)
    end

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
        load_from_response(@app.client.put(collection_name, key, value, ref), false)
        true
      rescue API::IndexingConflict => e
        @ref = e.response.headers['Location'].split('/').last
        @last_request_time = Time.parse(e.response.headers['Date'])
        true
      end
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

    private
    def load_from_response(response, set_body=true)
      @ref = response.ref
      @value = response.body if set_body
      @last_request_time = response.request_time
    end

    public
    # @!visibility private
    def to_s
      "#<Orchestrate::KeyValue id=#{id} ref=#{ref} last_request_time=#{last_request_time}>"
    end
    alias :inspect :to_s

  end
end
