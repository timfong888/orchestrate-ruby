require "orchestrate/api/procedural"
require 'faraday'
require 'faraday_middleware'

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

    # The Faraday HTTP "connection" for the client.
    attr_accessor :http

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
    def initialize(config = Orchestrate.config)
      @config = config

      @http = Faraday.new(config.base_url) do |faraday|
        if config.faraday.respond_to?(:call)
          config.faraday.call(faraday)
        else
          faraday.adapter Faraday.default_adapter
        end

        # faraday seems to want you do specify these twice.
        faraday.request :basic_auth, config.api_key, ''
        faraday.basic_auth config.api_key, ''

        # parses JSON responses
        # faraday.response :json, :content_type => /\bjson$/
      end
    end

    #
    # Performs the HTTP request against the API and returns an API::Response.
    #
    def send_request(method, args)
      ref = args[:ref]
      # TODO: move header manipulation into the API method
      url = build_url(method, args)
      response = http.send(method) do |request|
        config.logger.debug "Performing #{method.to_s.upcase} request to \"#{url}\""
        request.url url
        if method == :put
          request.headers['Content-Type'] = 'application/json'
          if ref == "*"
            request['If-None-Match'] = ref
          elsif ref
            request['If-Match'] = ref
          end
          request.body = args[:json]
        elsif method == :delete && ref != "*"
          request['If-Match'] = ref
        elsif method == :get
          request['Accept'] = 'application/json'
        end
        request.headers['User-Agent'] = "ruby/orchestrate/#{Orchestrate::VERSION}"
      end
      API::Response.new(response)
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
