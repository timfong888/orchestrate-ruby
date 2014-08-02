require 'uri'
module Orchestrate
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
      @value = nil
      load_from_response(response) if response
    end

    def path
      "/#{key.path}/events/#{URI.escape(type_name)}/#{timestamp}/#{ordinal}"
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
        @time = Time.at(@timestamp / 1000.0)
        @last_request_time = response.request_time
      end
    end
  end
end
