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

    def initialize(coll, key_name)
      @collection = coll
      @collection_name = coll.name
      @app = coll.app
      @key = key_name.to_s
      @id = "#{collection_name}/#{key}"
      @loaded = false
    end

    attr_reader :ref
    attr_reader :value

    def reload
      response = @app.client.get(collection_name, key)
      @ref = response.ref
      @value = response.body
    end

  end
end
