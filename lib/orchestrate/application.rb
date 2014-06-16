module Orchestrate
  class Application

    attr_reader :api_key

    attr_reader :client

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

    def [](collection_name)
      Collection.new(self, collection_name)
    end

  end
end
