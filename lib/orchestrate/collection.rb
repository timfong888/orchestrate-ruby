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
      KeyValue.new(app, name, key_name)
    end

  end
end
