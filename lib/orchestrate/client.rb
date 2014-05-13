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
      send_request :delete, [collection], { query: {force:true} }
    end

    #  -------------------------------------------------------------------------
    #  Key/Value

    #  Retreives the latest value assigned to a key.
    #  * required: collection, key
    #  * optional: ref
    #
    def get(collection, key, ref=nil)
      if ref
        send_request :get, [collection, key, 'refs', ref]
      else
        send_request :get, [collection, key]
      end
    end

    #  * required: collection, key, json
    #  * optional: condition, where condition = ref="#{etag}" || true
    #     if condition is a string, it will be sent as the 'If-Match' header
    #     otherwise if condition is false, the header 'If-None-Match: *' will be sent
    #
    def put(collection, key, body, condition=nil)
      headers={}
      if condition.is_a?(String)
        headers['If-Match'] = format_ref(condition)
      elsif condition == false
        headers['If-None-Match'] = '*'
      end
      send_request :put, [collection, key], { body: body, headers: headers }
    end
    alias :put_if_unmodified :put

    #  * required: colleciton, key, json
    #
    def put_if_absent(collection, key, body)
      put collection, key, body, false
    end

    #  * required: collection, key
    #  * optional: ref.  If truthy, will be sent as 'If-Match' header
    #
    def delete(collection, key, ref=nil)
      headers = {}
      headers['If-Match'] = format_ref(ref) if ref
      send_request :delete, [collection, key], { headers: headers }
    end

    #  * required: { collection, key }
    #
    def purge(collection, key)
      send_request :delete, [collection, key], { query: { purge: true } }
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
    def send_request(method, url, opts={})
      if url.is_a?(Hash)
        body = url[:json]
        url = build_url(method, url)
        headers={}
      else
        url = "/v0/#{url.join('/')}"
        query_string = opts.fetch(:query, {})
        body = opts.fetch(:body, '')
        headers = opts.fetch(:headers, {})
      end
      # TODO: move header manipulation into the API method
      response = http.send(method) do |request|
        config.logger.debug "Performing #{method.to_s.upcase} request to \"#{url}\""
        request.url url, query_string
        if method == :put
          headers['Content-Type'] = 'application/json'
          request.body = body
        elsif method == :get
          headers['Accept'] = 'application/json'
        end
        headers.each {|header, value| request[header] = value }
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

      #
      # Formats the provided 'ref' to be quoted per API specification.  If
      # already quoted, does not add additional quotes.
      def format_ref(ref)
        "\"#{ref.gsub(/"/,'')}\""
      end

  end

end
