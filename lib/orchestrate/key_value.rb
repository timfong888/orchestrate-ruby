require 'uri'
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
      kv.instance_variable_set(:@tombstone, path['tombstone'])
      kv.value = listing.fetch('value', nil)
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

    # The 'address' of this KeyValue item, representated as #[collection_name]/#[key]
    # @return [String]
    attr_reader :path

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

    # When the KeyValue was last loaded from Orchestrate.
    # @return [Time]
    attr_reader :last_request_time

    # Instantiates a new KeyValue item.  You generally don't want to call this yourself, but rather use
    # the methods on Orchestrate::Collection to load a KeyValue.
    # @param coll [Orchestrate::Collection] The collection to which this KeyValue belongs.
    # @param key_name [#to_s] The name of the key
    # @param associated_response [nil, Orchestrate::API::Response]
    #   If an API::Response, used to load attributes and value.
    # @return Orchestrate::KeyValue
    def initialize(coll, key_name, associated_response=nil)
      @collection = coll
      @collection_name = coll.name
      @app = coll.app
      @key = key_name.to_s
      @id = "#{collection_name}/#{key}"
      @path = "#{URI.escape(collection_name)}/#{URI.escape(key)}"
      @value = {}
      @ref = false
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
      load_from_response(perform(:get))
    end

    # Is this the "Current" value for this KeyValue?  False for non-Ref objects.
    # Use this instead of `#is_a?` or `#kind_of?`.
    # @return [true, false]
    def archival?
      false
    end

    # Is this a Ref that represents a null value (created through `#destroy` or
    # similar)?  False for most cases -- The only way to retrieve a Ref for which
    # this will return true is by enumerating trhough values from a RefList.
    # @return [true, false]
    def tombstone?
      !! @tombstone
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
        load_from_response(perform(:put, value, ref))
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
    def set(merge)
      begin
        set!(merge)
      rescue API::RequestError, API::ServiceError
        false
      end
    end

    # Merges a set of values into the item's existing value and saves.
    # @param merge [#each_pair] The Hash-like to merge into #value.  Keys will be stringified.
    # @return [true]
    # @raise [Orchestrate::API::VersionMismatch] If the KeyValue item has been updated with a new ref since this KeyValue was loaded.
    # @raise [Orchestrate::API::RequestError, Orchestrate::API::ServiceError] If there was any other problem with saving.
    def set!(merge)
      merge.each_pair {|key, value| @value[key.to_s] = value }
      save!
    end

    # @!group patch-merge

    # Merges the given value into a KeyValue item using a patch request,
    # enabling merges to be peformed without retrieving the KeyValue item.
    # @param value [#to_json] Hash of partial values, to be converted to json,
    # and merged into the KeyValue item.
    # @param ref [String] optional condition, provide ref for 'If-Match' header
    def merge(value, ref=nil, upsert=false)
      self.perform(:patch_merge, value, ref, upsert)
    end

    # @!endgroup patch-merge
    # @!group patch-operations

    # Create a new patch builder.
    # @return Orchestrate::KeyValue::OperationSet
    # @todo Consider deprecating methods per operation in favor of using this
    #       method.
    def patch
      OperationSet.new(self)
    end

    # Manipulate a KeyValue item with a set of operations.
    # Chain a series of operation methods (#add, #remove, etc) to build the set,
    # operations will be executed by Orchestrate in sequential order.
    # @param ref [String] optional condition, provide ref for 'If-Match' header
    # To perform singular operations or a set, add #update to the end of the method chain.
    # @example
    #   users['jon-snow'].add(:beard, true).remove(:some_field).update()
    # @raise Orchestrate::API::NotFound if key does not exist
    def update(ref=nil)
      OperationSet.new(self).update(ref)
    end

    # Adds a new field/value pair to a KeyValue at the designated path (field name).
    # @param path [#to_s] The location of the field to add.
    # @param value [#to_json] The value to assign to the specified field.
    # @return Orchestrate::KeyValue::OperationSet
    def add(path, value)
      OperationSet.new(self).add(path, value)
    end

    # Removes a field/value pair from a KeyValue item
    # @param path [#to_s] The field to remove.
    # @raise Orchestrate::API::RequestError if field does not exist
    def remove(path)
      OperationSet.new(self).remove(path)
    end

    # Replaces an existing field's value
    # @param path [#to_s] The field whose value to replace.
    # @param value [#to_json] The value to assign to the specified field.
    # @raise Orchestrate::API::RequestError if field does not exist
    # @return Orchestrate::KeyValue::OperationSet
    def replace(path, value)
      OperationSet.new(self).replace(path, value)
    end

    # Moves a KeyValue item's field/value pair to a new field (path)
    # @param from_path [#to_s] The field to move.
    # @param to_path [#to_s] The new location of the moved field.
    # @raise Orchestrate::API::RequestError if field does not exist
    # @return Orchestrate::KeyValue::OperationSet
    def move(from_path, to_path)
      OperationSet.new(self).move(from_path, to_path)
    end

    # Copies a KeyValue item's field value to another field (path)
    # @param from_path [#to_s] The field to copy.
    # @param to_path [#to_s] The target location to copy field/value to.
    # @raise Orchestrate::API::RequestError if field does not exist
    # @return Orchestrate::KeyValue::OperationSet
    def copy(from_path, to_path)
      OperationSet.new(self).copy(from_path, to_path)
    end

    # Increases a KeyValue item's field number value by given amount
    # @param path [#to_s] The field (with a number value) to increment.
    # @param amount [Integer] The amount to increment the field's value by.
    # @raise Orchestrate::API::RequestError if field does not exist or
    # if existing value is not a number type
    # @return Orchestrate::KeyValue::OperationSet
    def increment(path, amount)
      OperationSet.new(self).increment(path, amount)
    end
    alias :inc :increment

    # Decreases a KeyValue item's field number value by given amount
    # @param path [#to_s] The field (with a number value) to decrement.
    # @param amount [Integer] The amount to decrement the field's value by.
    # @raise Orchestrate::API::RequestError if field does not exist or
    # if existing value is not a number type
    # @return Orchestrate::KeyValue::OperationSet
    def decrement(path, amount)
      OperationSet.new(self).decrement(path, amount)
    end
    alias :dec :decrement

    # Tests equality of a KeyValue's existing field/value pair
    # @param path [#to_s] The field to check equality of.
    # @param value [#to_json] The expected value of the field.
    # @raise Orchestrate::API::RequestError if field does not exist
    # @raise Orchestrate::API::IndexingError if equality check fails
    # @return Orchestrate::KeyValue::OperationSet
    def test(path, value)
      OperationSet.new(self).test(path, value)
    end

    # An object which builds a set of operations for manipulating an Orchestrate::KeyValue
    class OperationSet

      # @return [KeyValue] The keyvalue this object will manipulate.
      attr_reader :key_value

      attr_reader :operations

      # Initialize a new OperationSet object
      # @param key_value [Orchestrate::KeyValue] The keyvalue to manipulate.
      def initialize(key_value, operations = [], child = false)
        @key_value = key_value
        @operations = operations
        @child = child
        @upsert = false
      end

      def update(ref = nil)
        return false if @child
        key_value.perform(:patch, @operations, ref, @upsert)
      end

      def upsert(upsert = true)
        @upsert = upsert
        self
      end

      def add(path, value)
        @operations.push(op: "add", path: path, value: value)
        self
      end

      def remove(path)
        @operations.push(op: "remove", path: path)
        self
      end

      def replace(path, value)
        @operations.push(op: "replace", path: path, value: value)
        self
      end

      def move(from_path, to_path)
        @operations.push(op: "move", from: from_path, path: to_path)
        self
      end

      def copy(from_path, to_path)
        @operations.push(op: "copy", from: from_path, path: to_path)
        self
      end

      def increment(path, amount)
        @operations.push(op: "inc", path: path, value: amount)
        self
      end
      alias :inc :increment

      def decrement(path, amount)
        @operations.push(op: "inc", path: path, value: -amount)
        self
      end
      alias :dec :decrement

      def test(path, value, options = {})
        negate = options[:negate] || false
        @operations.push(op: 'test', path: path, value: value, negate: negate)
        self
      end

      def test_presence(path)
        @operations.push(op: 'test', path: path)
        self
      end

      def test_absence(path)
        @operations.push(op: 'test', path: path, negate: true)
        self
      end

      def init(path, value)
        @operations.push(op: 'init', path: path, value: value)
        self
      end

      def append(path, value)
        @operations.push(op: 'append', path: path, value: value)
        self
      end

      # item.patch.add('a', {}).patch('a') { |p| p.add('b', 'c') }.update
      def patch(path, conditional = false)
        p = OperationSet.new(@key_value, [], true)
        yield p
        @operations.push(op: 'patch', path: path, value: p.operations, conditional: conditional)
        self
      end

      def merge(path, value)
        @operations.push(op: 'merge', path: path, value: value)
        self
      end
    end

    # @!endgroup patch-operations

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
      response = perform(:delete, ref)
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
      response = perform(:purge, ref)
      @ref = nil
      @last_request_time = response.request_time
      true
    end

    # @!endgroup persistence
    #
    # @!group refs

    # Entry point for retrieving Refs associated with this KeyValue.
    # @return [Orchestrate::RefList] A RefList instance bound to this KeyValue.
    def refs
      @refs ||= RefList.new(self)
    end

    # @!endgroup refs
    #
    # @!group relations

    # Entry point for managing the graph relationships for this KeyValue item
    # @return [Orchestrate::Graph] A graph instance bound to this item.
    def relations
      @relations ||= Graph.new(self)
    end

    # @!endgroup relations
    # @!group events

    # Entry point for managing events associated with this KeyValue item.
    # @return [Orchestrate::EventSource]
    def events
      @events ||= EventSource.new(self)
    end

    # @!endgroup events

    # Calls a method on the Collection's Application's client, providing the
    # Collection's name and KeyValue's key.
    # @param api_method [Symbol] The method on the client to call.
    # @param args [#to_s, #to_json, Hash] The arguments for the method.
    # @return API::Response
    def perform(api_method, *args)
      collection.perform(api_method, key, *args)
    end

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
