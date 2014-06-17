module Orchestrate
  class Collection

    attr_reader :app

    attr_reader :name

    def to_s
      "#<Orchestrate::Collection name=#{name} api_key=#{app.api_key[0..7]}...>"
    end
    alias :inspect :to_s

    def initialize(app, collection_name)
      if app.kind_of? Orchestrate::Client
        @app = Application.new(app)
      else
        @app = app
      end
      @name = collection_name.to_s
    end

    def destroy!
      app.client.delete_collection(name)
    end

    def [](key_name)
      begin
        KeyValue.load(self, key_name)
      rescue API::NotFound
        nil
      end
    end

    def []=(key_name, value)
      set(key_name, value)
    end

    def set(key_name, value, condition=nil)
      resp = app.client.put(name, key_name, value, condition)
      kv = KeyValue.new(self, key_name, resp)
      kv.value = value
      kv
    end

    def create(key_name, value)
      set(key_name, value, false)
    end

    include Enumerable
    def each
      return enum_for(:each) unless block_given?
      response = app.client.list(name)
      loop do
        response.results.each do |doc|
          yield KeyValue.new(self, doc, response.request_time)
        end
        break unless response.next_link
        response = response.next_results
      end
    end

  end
end
