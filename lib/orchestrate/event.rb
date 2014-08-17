require 'uri'
module Orchestrate
  class Event
    def self.from_bodyless_response(stem, value, response)
      event = new(stem, response)
      event.value = value
      event
    end

    def self.from_listing(stem, listing, response)
      event = new(stem)
      event.value = listing['value']
      event.instance_variable_set(:@timestamp, listing['timestamp'])
      event.instance_variable_set(:@ordinal, listing['ordinal'])
      event.instance_variable_set(:@ref, listing['path']['ref'])
      event.instance_variable_set(:@last_request_time, response.request_time)
      event
    end

    attr_reader :type
    attr_reader :type_name
    attr_reader :key
    attr_reader :key_name
    attr_reader :ref
    attr_reader :timestamp
    attr_reader :ordinal
    attr_reader :last_request_time
    attr_accessor :value

    def initialize(stem, response=nil)
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

    def time
      @time ||= Time.at(@timestamp / 1000.0)
    end

    def [](attr_name)
      value[attr_name.to_s]
    end

    def []=(attr_name, attr_val)
      value[attr_name.to_s] = attr_val
    end

    def save
      begin
        save!
      rescue API::RequestError, API::ServiceError
        false
      end
    end

    def save!
      response = perform(:put_event, value, ref)
      load_from_response(response)
      true
    end

    def update(merge)
      begin
        update!(merge)
      rescue API::RequestError, API::ServiceError
        false
      end
    end

    def update!(merge)
      merge.each_pair {|key, value| @value[key.to_s] = value }
      save!
    end

    def purge
      begin
        purge!
      rescue API::RequestError
        false
      end
    end

    def purge!
      response = perform(:purge_event, ref)
      @ref = nil
      @last_request_time = response.request_time
      true
    end

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
