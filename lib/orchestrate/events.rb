require 'uri'
module Orchestrate
  class EventSource
    def initialize(kv_item)
      @kv_item = kv_item
      @types = {}
    end

    def [](event_type)
      @types[event_type.to_s] ||= EventsStem.new(@kv_item, event_type)
    end
  end

  class EventsStem
    attr_accessor :kv_item
    attr_accessor :type
    def initialize(kv_item, event_type)
      @kv_item = kv_item
      @type = event_type.to_s
    end

    def <<(body)
      response = kv_item.perform(:post_event, type, body)
      Event.from_bodyless_response(self, body, response)
    end
    alias :push :<<
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
        vers, coll, k, e, t, ts, ord = response.headers['Location'].split('/')
        @timestamp = ts.to_i
        @ordinal = ord.to_i
        @time = Time.at(@timestamp / 1000.0)
        @last_request_time = response.request_time
      end
    end
  end
end
