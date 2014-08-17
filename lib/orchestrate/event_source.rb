module Orchestrate

  # Manages Event Types for a KeyValue item.
  class EventSource

    # Instantiages a new EventSource manager.
    # @param kv_item [Orchestrate::KeyValue] The KeyValue item to which events belong.
    def initialize(kv_item)
      @kv_item = kv_item
      @types = {}
    end

    # Accessor for event types.
    # @param event_type [#to_s] The type key for the events.
    # @return [EventType]
    def [](event_type)
      @types[event_type.to_s] ||= EventType.new(@kv_item, event_type)
    end
  end

  # Manages events of a specific type that belong to a specific KeyValue item.
  class EventType

    # @return [Orchestrate::KeyValue] The KeyValue this EventType is managing events for.
    attr_reader :kv_item

    # @return [String] The name for the type of events this EventType manages.
    attr_reader :type

    # Instantiates a new EventType.
    # @param kv_item [Orchestrate::KeyValue] The KeyValue this EventType manages events for.
    # @param event_type [#to_s] The type of events this EventType manages.
    def initialize(kv_item, event_type)
      @kv_item = kv_item
      @type = event_type.to_s
    end

    # Calls a method on the KeyValue's Collection's API Client, providing the event type.
    # @param api_method [Symbol] The method on the client to call.
    # @param args [#to_s, #to_json, Hash] The remaining arguments for the specified method.
    # @return [API::Response]
    def perform(api_method, *args)
      kv_item.perform(api_method, type, *args)
    end

    # Creates a new Event of the given type for the associated KeyValue.
    # @param body [#to_json] The value for the event.
    # @return [Orchestrate::Event] The event that was created.
    def <<(body)
      List.new(self).push(body)
    end
    alias :push :<<

    # Instantiates a new EventType::List with the given bounds.  Can be used to
    # access single events or create events with a specific timestamp.
    # @param bounds [#to_s, Time, Date, Integer, Hash] The bounds value for the List.
    # @see EventType::List#initialize
    # @example Accessing an existing event by timestamp/ordinal
    #   kv.events[:checkins][timestamp][1]
    # @example Creating an Event with a specified timestamp
    #   kv.events[:checkins][Time.now - 3600] << {"place" => "home"}
    # @example Listing events within a time range
    #   kv.events[:checkins][{before: Time.now - 3600, after: Time.now - 24 * 3600}].to_a
    #   # equivalent to:
    #   # kv.events[:checkins].before(Time.now - 3600).after(Time.now - 24 * 3600).to_a
    def [](bounds)
      List.new(self, bounds)
    end

    include Enumerable

    # Iterates over events belonging to the KeyValue of the specified Type.
    # Used as the basis for enumerable methods.  Events are provided in reverse
    # chronological order by timestamp and ordinal value.
    # @overlaod each
    #   @return Enumerator
    # @overload each(&block)
    #   @yieldparam [Orchestrate::Event] event The Event item
    def each(&block)
      List.new(self).each(&block)
    end

    # Creates a Lazy Enumerator for the EventList.  If called inside the app's
    # `#in_parallel` block, will prefetch results.
    # @return Enumerator::Lazy
    def lazy
      List.new(self).lazy
    end

    # Returns the first n items.  Equivalent to Enumerable#take.  Sets the `limit`
    # parameter on the query to Orchestrate, so we don't ask for more than is needed.
    # @param count [Integer] The number of events to limit to.
    # @return [Array]
    def take(count)
      List.new(self).take(count)
    end

    # Sets the inclusive start boundary for enumeration over events.
    # Overwrites any value given to #before.
    # @param bound [Orchestrate::Event, Time, Date, Integer, #to_s] The inclusive start of the event range.
    # @return [EventType::List]
    def start(bound)
      List.new(self).start(bound)
    end

    # Sets the exclusive start boundary for enumeration over events.
    # Overwrites any value given to #start
    # @param bound [Orchestrate::Event, Time, Date, Integer, #to_s] The exclusive start of the event range.
    # @return [EventType::List]
    def after(bound)
      List.new(self).after(bound)
    end

    # Sets the exclusive end boundary for enumeration over events.
    # Overwrites any value given to #end
    # @param bound [Orchestrate::Event, Time, Date, Integer, #to_s] The exclusive end of the event range.
    # @return [EventType::List]
    def before(bound)
      List.new(self).before(bound)
    end

    # Sets the inclusive end boundary for enumeration over events.
    # Overwrites any value given to #before
    # @param bound [Orchestrate::Event, Time, Date, Integer, #to_s] The inclusive end of the event range.
    # @return [EventType::List]
    def end(bound)
      List.new(self).start(bound)
    end

    class List
      attr_reader :type
      attr_reader :type_name
      attr_reader :kv_item
      def initialize(type, bounds=nil)
        @type = type
        @type_name = type.type
        @kv_item = type.kv_item
        if bounds.kind_of?(Hash)
          @bounds = bounds
        else
          @bounds = {limit: 100}
          @bounds[:start] = bounds if bounds
        end
      end

      def perform(api_method, *args)
        type.perform(api_method, *args)
      end

      def <<(body)
        response = perform(:post_event, body, @bounds[:start])
        Event.from_bodyless_response(type, body, response)
      end
      alias :push :<<

      def [](ordinal)
        begin
          response = perform(:get_event, @bounds[:start], ordinal)
          Event.new(type, response)
        rescue API::NotFound
          nil
        end
      end

      include Enumerable

      def each(&block)
        @response = perform(:list_events, @bounds)
        return enum_for(:each) unless block_given?
        raise ResultsNotReady.new if type.kv_item.collection.app.inside_parallel?
        loop do
          @response.results.each do |listing|
            yield Event.from_listing(type, listing, @response)
          end
          break unless @response.next_link
          @response = @response.next_results
        end
        @response = nil
      end

      def lazy
        return each.lazy if type.kv_item.collection.app.inside_parallel?
        super
      end

      def take(count)
        count = 1 if count < 1
        @bounds[:limit] = count > 100 ? 100 : count
        super(count)
      end

      def start(bound)
        @bounds[:start] = extract_bound_from(bound)
        @bounds.delete(:after)
        self
      end

      def after(bound)
        @bounds[:after] = extract_bound_from(bound)
        @bounds.delete(:start)
        self
      end

      def before(bound)
        @bounds[:before] = extract_bound_from(bound)
        @bounds.delete(:end)
        self
      end

      def end(bound)
        @bounds[:end] = extract_bound_from(bound)
        @bounds.delete(:before)
        self
      end

      private
      def extract_bound_from(bound)
        if bound.kind_of?(Event)
          "#{bound.timestamp}/#{bound.ordinal}"
        else bound
        end
      end
    end
  end
end
