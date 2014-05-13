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

    #
    # Configuration for the wrapper instance. If configuration is not
    # explicitly provided during initialization, this will default to
    # Orchestrate.config.
    #
    attr_accessor :config

    # The Faraday HTTP "connection" for the client.
    attr_accessor :http

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

    # -------------------------------------------------------------------------
    #  collection

    #  * required: { collection }
    #  * optional: { path }, which should have been called <em>params</em>
    #
    def list(args)
      send_request :get, args
    end

    #  * required: { collection, query }
    #
    def search(args)
      # TODO
      # don't clobber anything in existing path parameter
      send_request :get, args.merge(path: "?query=#{args[:query].gsub(/\s/, '%20')}")
    end

    #  Deletes a collection
    #  * required: collection
    #
    def delete_collection(collection)
      send_request :delete, [collection], {force:true}
    end

    # -------------------------------------------------------------------------
    #  collection/key

    #  * required: { collection, key }
    #
    def get_key(args)
      send_request :get, args
    end

    #  * required: { collection, key, json }
    #
    def put_key(args)
      send_request :put, args
    end

    #  * required: { collection, key }
    #
    def delete_key(args)
      send_request :delete, args
    end

    #  * required: { collection, key }
    #
    def purge_key(args)
      send_request :delete, args.merge(path: "?purge=true")
    end

    # -------------------------------------------------------------------------
    #  collection/key/ref

    #   * required: { collection, key, ref }
    #
    def get_by_ref(args)
      send_request :get, args
    end

    #  * required: { collection, key, json, ref }
    #
    def put_key_if_match(args)
      send_request :put, args
    end

    # * required: { collection, key, json }
    #
    def put_key_if_none_match(args)
      send_request :put, args.merge(ref: '"*"')
    end

    # -------------------------------------------------------------------------
    #  collection/key/events

    #  * required: { collection, key, event_type }
    #  * optional: { timestamp }, where timestamp = { :start => start, :end => end }
    #
    def get_events(args)
      send_request :get, args
    end

    #  * required: { collection, key, event_type, json }
    #  * optional: { timestamp }, where timestamp is a scalar value
    #
    def put_event(args)
      send_request :put, args
    end

    # -------------------------------------------------------------------------
    #  collection/key/graph

    #  * required: { collection, key, kind }
    #
    def get_graph(args)
      send_request :get, args
    end

    #  * required: { collection, key, kind, to_collection, to_key }
    #
    def put_graph(args)
      send_request :put, args
    end

    #  * required: { collection, key, kind, to_collection, to_key }
    #
    def delete_graph(args)
      send_request :delete, args.merge(path: "?purge=true")
    end

    #
    # Performs the HTTP request against the API and returns an API::Response.
    #
    def send_request(method, url, query_string={}, headers={})
      if url.is_a?(Hash)
        ref = url[:ref]
        body = url[:json]
        url = build_url(method, url)
      else
        url = "/v0/#{url.join('/')}"
      end
      # TODO: move header manipulation into the API method
      response = http.send(method) do |request|
        config.logger.debug "Performing #{method.to_s.upcase} request to \"#{url}\""
        request.url url, query_string
        if method == :put
          request.headers['Content-Type'] = 'application/json'
          if ref == "*"
            request['If-None-Match'] = ref
          elsif ref
            request['If-Match'] = ref
          end
          request.body = body
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
