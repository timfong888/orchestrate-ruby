require 'uri'
module Orchestrate

  # Events are a way to associate Time-ordered data with a key.
  class Event

    # Instantiates an Event from a value and response without a body.
    # @param stem [Orchestrate::EventType] The associated EventType.
    # @param value [Hash] The value for the event.
    # @param response [API::Response] The associated response for creating the event.
    # @return [Event]
    def self.from_bodyless_response(stem, value, response)
      event = new(stem, response)
      event.value = value
      event
    end

    # Instantiates an Event from a value in a listing and an associated response.
    # @param stem [Orchestrate::EventType] The associated EventType
    # @param listing [Hash] The entry in the LIST result
    # @param response [API::Response] The associated response for the list query.
    # @return [Event]
    def self.from_listing(stem, listing, response=nil)
      event = new(stem)
      event.value = listing['value']
      event.instance_variable_set(:@timestamp, listing['path']['timestamp'])
      event.instance_variable_set(:@ordinal, listing['path']['ordinal'])
      event.instance_variable_set(:@ref, listing['path']['ref'])
      event.instance_variable_set(:@last_request_time, response.request_time) if response
      event
    end

    # @return [Orchestrate::EventType] The associated EventType.
    attr_reader :type

    # @return [String] The associated name of the event type.
    attr_reader :type_name

    # @return [Orchestrate::KeyValue] The assoicated KeyValue item.
    attr_reader :key

    # @return [String] The key of the associated item.
    attr_reader :key_name

    # @return [String] The immutable ref for the current value of this event.
    attr_reader :ref

    # @return [Integer] The timestamp of the event, in number of milliseconds since epoch.
    # @see #time
    attr_reader :timestamp

    # @return [Integer] The ordinal of the event.
    attr_reader :ordinal

    # @return [Time] The time which the event was loaded.
    attr_reader :last_request_time

    # @return [Hash] The value for the event.
    attr_accessor :value

    # Instantiates a new Event item.  You generally don't want to call this
    # yourself, but use accessor methods from the KeyValue and EventType.
    # @param stem [Orchestrate::EventType] The associated EventType.
    # @param response [nil, Orchestrate::API::Response]
    #   If an API::Response, used to load attributes and value.
    # @return Orchestrate::Event
    def initialize(stem, response=nil)
      @type = stem
      @type_name = type.type
      @key = stem.kv_item
      @key_name = key.key
      @value = nil
      load_from_response(response) if response
    end

    # Equivalent to `String#==`.  Compares by KeyValue, Type, Timestamp and Ordinal.
    # @param other [Orchestrate::Event] the Event to compare against.
    # @return [true, false]
    def ==(other)
      other.kind_of?(Orchestrate::Event) && \
        other.type == type && \
        other.timestamp == timestamp && \
        other.ordinal == ordinal
    end
    alias :eql? :==

    # Equivalent to `String#<=>`.  Compares by KeyValue, Type, Timestamp and
    # Ordinal.  Sorts newer timestamps before older timestamps.  If timestamps
    # are equivalent, sorts by ordinal.  This behavior emulates the order which
    # events are returned in a list events query from the Orchestrate API.
    # @param other [Orchestrate::Event] the Event to compare against.
    # @return [nil, -1, 0, 1]
    def <=>(other)
      return nil unless other.kind_of?(Orchestrate::Event)
      return nil unless other.type == type
      if other.timestamp == timestamp
        other.ordinal <=> ordinal
      else
        other.timestamp > timestamp ? -1 : 1
      end
    end

    # @return [String] A pretty-printed representation of the event.
    def to_s
      "#<Orchestrate::Event collection=#{key.collection_name} key=#{key_name} type=#{type_name} time=#{time} ordinal=#{ordinal} ref=#{ref} last_request_time=#{last_request_time}>"
    end

    # @group Attributes

    # @return [String] The full path of the event.
    def path
      @path ||= "/#{key.path}/events/#{URI.escape(type_name)}/#{timestamp}/#{ordinal}"
    end

    # @return [Time] The timestamp of the event as a Time object.
    def time
      @time ||= Time.at(@timestamp / 1000.0)
    end

    # Accessor for a property on the event's value.
    # @param attr_name [#to_s] the attribute name to retrieve.
    # @return [nil, true, false, Numeric, String, Array, Hash] The value for the attribute.
    def [](attr_name)
      value[attr_name.to_s]
    end

    # Set an attribute on the event's value to a specified value.
    # @param attr_name [#to_s] The name of the attribute.
    # @param attr_val [#to_json] The new value for the attribute
    # @return [attr_val]
    def []=(attr_name, attr_val)
      value[attr_name.to_s] = attr_val
    end

    # @endgroup
    # @group Persistence

    # Saves the Event item to Orchestrate using 'If-Match' with the current ref.
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

    # Saves the Event item to Orchestrate using 'If-Match' with the current ref.
    # Sets the new ref for this value to the ref attribute.
    # Raises an exception on failure to save.
    # @return [true]
    # @raise [Orchestrate::API::VersionMismatch] If the Event has been updated with a new value since this Event was loaded.
    # @raise [Orchestrate::API::RequestError, Orchestrate::API::ServiceError] If there are any other problems with saving.
    def save!
      response = perform(:put_event, value, ref)
      load_from_response(response)
      true
    end

    # Merges a set of values into the event's existing value and saves.
    # @param merge [#each_pair] The Hash-like to merge into #value.  Keys will be stringified.
    # @return [true, false]
    def update(merge)
      begin
        update!(merge)
      rescue API::RequestError, API::ServiceError
        false
      end
    end

    # Merges a set of values into the event's existing value and saves.
    # @param merge [#each_pair] The Hash-like to merge into #value.  Keys will be stringified.
    # @return [true]
    # @raise [Orchestrate::API::VersionMismatch] If the Event has been updated with a new value since this Event was loaded.
    # @raise [Orchestrate::API::RequestError, Orchestrate::API::ServiceError] If there are any other problems with saving.
    def update!(merge)
      merge.each_pair {|key, value| @value[key.to_s] = value }
      save!
    end

    # Deletes the event from Orchesrate using 'If-Match' with the current ref.
    # Returns false if the event failed to delete because a new ref has been created since this Event was loaded.
    # @return [true, false]
    def purge
      begin
        purge!
      rescue API::RequestError
        false
      end
    end

    # Deletes the event from Orchesrate using 'If-Match' with the current ref.
    # @return [true]
    # @raise [Orchestrate::API::VersionMismatch] If the Event has been updated with a new ref since this Event was loaded.
    def purge!
      response = perform(:purge_event, ref)
      @ref = nil
      @last_request_time = response.request_time
      true
    end

    # @endgroup persistence

    # Performs a request using the associated API client, with collection_name,
    # key, event_type, timestamp, and ordinal pre-filled.
    # @param api_method [Symbol] the method on API::Client to call.
    # @param args [#to_s, #to_json, Hash] The remaining arguments for the method being called.
    # @return [API::Request]
    def perform(api_method, *args)
      type.perform(api_method, timestamp, ordinal, *args)
    end

    private
    def load_from_response(response)
      response.on_complete do
        @ref = response.ref if response.respond_to?(:ref)
        if response.headers['Location']
          loc = response.headers['Location'].split('/')
          @timestamp = loc[6].to_i
          @ordinal = loc[7].to_i
        elsif response.body.kind_of?(Hash)
          @value = response.body['value']
          @timestamp = response.body['timestamp']
          @ordinal = response.body['ordinal']
        end
        @last_request_time = response.request_time
      end
    end
  end
end
