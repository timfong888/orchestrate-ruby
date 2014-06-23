module Orchestrate

  # Applications in Orchestrate are the highest level of your project.
  class Application

    # @return [String] The API key provided
    attr_reader :api_key

    # @return [Orchestrate::Client] The client tied to this application.
    attr_reader :client

    # Instantiate a new Application
    # @param client_or_api_key [#to_s] The API key for your Orchestrate Application.
    # @param client_or_api_key [Orchestrate::Client] A client instantiated with an Application and Faraday setup.
    # @yieldparam [Faraday::Connection] connection Setup for the Faraday connection.
    # @return Orchestrate::Application
    def initialize(client_or_api_key, &client_setup)
      if client_or_api_key.kind_of?(Orchestrate::Client)
        @client = client_or_api_key
        @api_key = client.api_key
      else
        @api_key = client_or_api_key
        @client = Client.new(api_key, &client_setup)
      end
      client.ping
    end

    # Accessor for Collections
    # @param collection_name [#to_s] The name of the collection.
    # @return Orchestrate::Collection
    def [](collection_name)
      Collection.new(self, collection_name)
    end

    # @!visibility private
    def to_s
      "#<Orchestrate::Application api_key=#{api_key[0..7]}...>"
    end
    alias :inspect :to_s

  end
end
