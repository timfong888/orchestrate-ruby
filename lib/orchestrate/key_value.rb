module Orchestrate
  class KeyValue

    def self.load(collection, key)
      kv = new(collection, key)
      kv.reload
      kv
    end

    attr_reader :collection
    attr_reader :collection_name
    attr_reader :key
    attr_reader :id
    attr_reader :ref
    attr_accessor :value

    attr_reader :loaded
    attr_reader :last_request_time

    def to_s
      "#<Orchestrate::KeyValue id=#{id} ref=#{ref} last_request_time=#{last_request_time}>"
    end
    alias :inspect :to_s

    def initialize(coll, key_name_or_listing, response=nil)
      @collection = coll
      @collection_name = coll.name
      @app = coll.app
      if key_name_or_listing.kind_of?(Hash)
        path = key_name_or_listing.fetch('path')
        @key = path.fetch('key')
        @ref = path.fetch('ref')
        @value = key_name_or_listing.fetch('value')
      else
        @key = key_name_or_listing.to_s
      end
      @id = "#{collection_name}/#{key}"
      @loaded = false
      load_from_response(response) if response
    end

    def loaded?
      !! @loaded
    end

    def reload
      load_from_response(@app.client.get(collection_name, key))
    end

    def [](attr_name)
      value[attr_name.to_s]
    end

    def []=(attr_name, attr_value)
      value[attr_name.to_s] = attr_value
    end

    def save
      begin
        save!
      rescue API::RequestError, API::ServiceError
        false
      end
    end

    def save!
      begin
        load_from_response(@app.client.put(collection_name, key, value, ref), false)
      rescue API::IndexingConflict => e
        @ref = e.response.headers['Location'].split('/').last
        @last_request_time = Time.parse(e.response.headers['Date'])
        true
      end
    end

    def destroy
      begin
        destroy!
        true
      rescue API::VersionMismatch
        false
      end
    end

    def destroy!
      response = @app.client.delete(collection_name, key, ref)
      @ref = nil
      @last_request_time = response.request_time
    end

    private
    def load_from_response(response, set_body=true)
      @ref = response.ref
      @value = response.body if set_body
      @last_request_time = response.request_time
      @loaded = true
    end

  end
end
