module Orchestrate
  class Application

    attr_reader :api_key

    attr_reader :client

    def initialize(api_key, &client_setup)
      @api_key = api_key
      @client = Client.new(api_key, &client_setup)
      client.ping
    end

  end
end
