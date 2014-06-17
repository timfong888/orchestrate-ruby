module Orchestrate
  class Collection

    attr_reader :app

    attr_reader :name

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

    def set(key_name, value)
      resp = app.client.put(name, key_name, value)
      kv = KeyValue.new(self, key_name, resp)
      kv.value = value
      kv
    end

  end
end
