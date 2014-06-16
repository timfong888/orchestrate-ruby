module Orchestrate
  class Collection

    attr_reader :app

    attr_reader :name

    def initialize(app, collection_name)
      @app = app
      @name = collection_name.to_s
    end

  end
end
