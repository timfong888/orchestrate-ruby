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

    #  * required: collection
    #  * optional: { options } which may contain one or more of:
    #           :limit  : integer, number of results to return
    #           :start  : string, start of range, including value
    #           :after  : string, start of range, excluding value
    #           :before : string, end of range, excluding value
    #           :end    : string, end of range, including value
    #
    #   Note, you cannot provide *both* 'start' and 'after', or 'before' and 'end'
    #
    def list(collection, options={})
      # TODO extract to perhaps "camelcase_keys"
      Orchestrate::Helpers.range_keys!('key', options)
      send_request :get, [collection], { query: options }
    end

    #  * required: collection, query
    #  * optional: { limit, offset }
    #
    def search(collection, query, options={})
      send_request :get, [collection], { query: options.merge({query: query})}
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
    #  Events

    #  * required: collection, key, event_type, timestamp, ordinal
    #    The timestamp should be formatted as decribed in the API docs:
    #    http://orchestrate.io/docs/api/?go#events/timestamps
    #
    #    A forthcoming version will auto-convert Ruby DateTime objects.
    #
    def get_event(collection, key, event_type, timestamp, ordinal)
      send_request :get, [collection, key, 'events', event_type, timestamp, ordinal]
    end

    #  * required: collection, key, event_type, body
    #  * optional: timestamp
    #    The timestamp should be formatted as decribed in the API docs:
    #    http://orchestrate.io/docs/api/?go#events/timestamps
    #
    #    A forthcoming version will auto-convert Ruby DateTime objects.
    #
    def post_event(collection, key, event_type, body, timestamp=nil)
      path = [collection, key, 'events', event_type, timestamp].compact
      send_request :post, path, { body: body }
    end

    #  * required: collection, key, event_type, timestamp, ordinal, body
    #  * optional: ref, for If-Match
    #    The timestamp should be formatted as decribed in the API docs:
    #    http://orchestrate.io/docs/api/?go#events/timestamps
    #
    #    A forthcoming version will auto-convert Ruby DateTime objects.
    #
    def put_event(collection, key, event_type, timestamp, ordinal, body, ref=nil)
      path = [collection, key, 'events', event_type, timestamp, ordinal]
      headers = {}
      headers['If-Match'] = format_ref(ref) if ref
      send_request :put, path, { body: body, headers: headers }
    end

    #  * required: collection, key, event_type
    #  * optional: range { start, end, before, after }
    #     Range parameters formatted as ":timestamp/:ordinal"
    #     * timstamps should be formatted as described in the API docs:
    #       http://orchestrate.io/docs/api/?go#events/timestamps
    #       A forthcoming version will auto-convert Ruby DateTime objects
    #     * ordinal is optional
    #
    def list_events(collection, key, event_type, parameters={})
      Orchestrate::Helpers.range_keys!('event', parameters)
      send_request :get, [collection, key, 'events', event_type], { query: parameters }
    end

    # -------------------------------------------------------------------------
    #  Graph

    #  * required: collection, key, kinds...
    #
    def get_graph(collection, key, *kinds)
      path = [collection, key, 'relations'].concat(kinds)
      send_request :get, path
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
        if [:put, :post].include?(method)
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
