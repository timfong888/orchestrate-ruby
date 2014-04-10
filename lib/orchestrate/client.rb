require "orchestrate/api/procedural"

module Orchestrate

  # ==== Ruby Client for the Orchestrate REST *API*.
  #
  # The primary entry point is the #send_request method, which generates a
  # Request, and returns the Response to the caller.
  #
  # {Usage examples for each HTTP request}[Procedural.html] are documented in
  # the Procedural interface module.
  #
  class Client

    include API::Procedural

    #
    # Configuration for the wrapper instance. If configuration is not
    # explicitly provided during initialization, this will default to
    # Orchestrate.config.
    #
    attr_accessor :config

    #
    # Returns the wrapper configuration. If the wrapper does not have
    # explicitly provided configuration, this will return the global
    # configuration from Orchestrate.config.
    #
    def config # :nodoc:
      @config ||= Orchestrate.config
    end

    #
    # Initialize and return a new Client instance. Optionally, configure
    # options for the instance by passing a Configuration object. If no
    # custom configuration is provided, the configuration options from
    # Orchestrate.config will be used.
    def initialize(config = nil)
      @config = config
    end

    #
    # Creates the Request object and sends it via the perform method,
    # which generates and returns the Response object.
    #
    def send_request(method, args)
      request = API::Request.new(method, build_url(method, args), config.api_key) do |r|
        r.data = args[:json] if args[:json]
        r.ref = args[:ref] if args[:ref]
        r.verbose = config.verbose
      end
      request.perform
    end

    # ------------------------------------------------------------------------

    private

      #
      # Builds the URL for each HTTP request to the orchestrate.io api.
      #
      def build_url(method, args)
        API::URL.new(method, config.base_url, args).path
      end

  end

end
