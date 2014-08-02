require 'uri'
module Orchestrate
  class EventSource
    def initialize(kv_item)
      @kv_item = kv_item
      @types = {}
    end

    def [](event_type)
      @types[event_type.to_s] ||= EventsType.new(@kv_item, event_type)
    end
  end

  class EventsType
    attr_reader :kv_item
    attr_reader :type
    def initialize(kv_item, event_type)
      @kv_item = kv_item
      @type = event_type.to_s
    end

    def <<(body)
      Range.new(self).push(body)
    end
    alias :push :<<

    def [](bounds)
      Range.new(self, bounds)
    end

    class Range
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
          @bounds[:start] = bounds
        end
      end

      def perform(api_method, *args)
        kv_item.perform(api_method, type_name, *args)
      end

      def <<(body)
        response = perform(:post_event, body, @bounds[:start])
        Event.from_bodyless_response(type, body, response)
      end
      alias :push :<<
    end
  end

  class Event
    def self.from_bodyless_response(stem, value, response)
      event = new(stem, response)
      event.value = value
      event
    end

    attr_reader :type
    attr_reader :type_name
    attr_reader :key
    attr_reader :key_name
    attr_reader :ref
    attr_reader :timestamp
    attr_reader :time
    attr_reader :ordinal
    attr_reader :last_request_time
    attr_accessor :value

    def initialize(stem, response)
      @type = stem
      @type_name = type.type
      @key = stem.kv_item
      @key_name = key.key
      load_from_response(response) if response
      @value = nil
    end

    def path
      "/#{key.path}/events/#{URI.escape(type_name)}/#{timestamp}/#{ordinal}"
    end

    private
    def load_from_response(response)
      response.on_complete do
        @ref = response.ref if response.respond_to?(:ref)
        loc = response.headers['Location'].split('/')
        @timestamp = loc[6].to_i
        @ordinal = loc[7].to_i
        @time = Time.at(@timestamp / 1000.0)
        @last_request_time = response.request_time
      end
    end
  end
end
