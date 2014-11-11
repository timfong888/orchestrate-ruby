module Orchestrate

  # Applications in Orchestrate are the highest level of your project.
  class Application

    # @return [String] The API key provided
    attr_reader :api_key

    # @return [String] The Orchestrate data center URL
    attr_reader :host

    # @return [Orchestrate::Client] The client tied to this application.
    attr_reader :client

    # Instantiate a new Application
    # @param client_or_api_key [Orchestrate::Client, #to_s] A client instantiated with the API key and faraday setup, or the API key for your Orchestrate Application.
    # @yieldparam [Faraday::Connection] connection Setup for the Faraday connection.
    # @return Orchestrate::Application
    def initialize(client_or_api_key, host="https://api.orchestrate.io", &client_setup)
      if client_or_api_key.kind_of?(Orchestrate::Client)
        @client = client_or_api_key
        @api_key = client.api_key
        @host = client.host
      else
        @api_key = client_or_api_key
        @host = host
        @client = Client.new(api_key, host, &client_setup)
      end
      client.ping
    end

    # Accessor for Collections
    # @param collection_name [#to_s] The name of the collection.
    # @return Orchestrate::Collection
    def [](collection_name)
      Collection.new(self, collection_name)
    end

    # Performs requests in parallel.  Requires using a Faraday adapter that supports parallel requests.
    # @yieldparam accumulator [Hash] A place to store the results of the parallel responses.
    # @example Performing three requests at once
    #   responses = app.in_parallel do |r|
    #     r[:some_items] = app[:site_globals].lazy
    #     r[:user]       = app[:users][current_user_key]
    #     r[:user_feed]  = app.client.list_events(:users, current_user_key, :notices)
    #   end
    # @see README See the Readme for more examples.
    # @note This method is not Thread-safe.  Requests generated from the same
    #   application instance in different threads while #in_parallel is running
    #   will behave unpredictably.  Use `#dup` to create per-thread application
    #   instances.
    def in_parallel(&block)
      @inside_parallel = true
      results = client.in_parallel(&block)
      @inside_parallel = nil
      results
    end

    # is the Application currently inside a block from `#in_parallel?`?
    # @return [true, false]
    def inside_parallel?
      !! @inside_parallel
    end

    # Perform a request against the client.
    # @param api_method [Symbol] The method on the client to call
    # @param args [#to_s, #to_json, Hash] The arguments for the method being called.
    # @return Orchestrate::API::Response
    def perform(api_method, *args)
      client.send(api_method, *args)
    end

    # @return a pretty-printed representation of the application.
    def to_s
      "#<Orchestrate::Application api_key=#{api_key[0..7]}...>"
    end
    alias :inspect :to_s

  end
end
