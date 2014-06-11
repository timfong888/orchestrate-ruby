require 'faraday'
require 'faraday_middleware'

module Orchestrate

  class Client

    # Orchestrate::Configuration instance for the client.  If not explicitly
    # provided during initialization, will default to Orchestrate.config
    attr_accessor :config

    # The Faraday HTTP "connection" for the client.
    attr_accessor :http

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
        faraday.response :json, :content_type => /\bjson$/
      end
    end

    # Sends a 'Ping' request to the API to test authentication:
    # http://orchestrate.io/docs/api/#authentication/ping
    # @return Orchestrate::API::Response
    # @raise Orchestrate::Error::Unauthorized if the client could not authenticate.
    def ping
      send_request :get, []
    end

    # -------------------------------------------------------------------------
    #  collection

    # Performs a [Key/Value List query](http://orchestrate.io/docs/api/#key/value/list) against the collection.
    # Orchestrate sorts results lexicographically by key name.
    # @param collection [#to_s] The name of the collection
    # @param options [Hash] Parameters for the query
    # @option options [Integer] :limit (10) The number of results to return. Maximum 100.
    # @option options [String] :start The inclusive start key of the query range.
    # @option options [String] :after The exclusive start key of the query range.
    # @option options [String] :before The exclusive end key of the query range.
    # @option options [String] :end The inclusive end key of the query range.
    # @note The Orchestrate API may return an error if you include both the
    #   :start/:after or :before/:end keys.  The client will not stop you from doing this.
    # @note To include all keys in a collection, do not include any :start/:after/:before/:end parameters.
    # @return Orchestrate::API::CollectionResponse
    # @raise Orchestrate::API::InvalidSearchParam The :limit value is not valid.
    def list(collection, options={})
      Orchestrate::Helpers.range_keys!('key', options)
      send_request :get, [collection], { query: options, response: API::CollectionResponse }
    end

    # Performs a [Search query](http://orchestrate.io/docs/api/#search) against the collection.
    # @param collection [#to_s] The name of the collection
    # @param query [String] The [Lucene Query String][lucene] to query the collection with.
    #   [lucene]: http://lucene.apache.org/core/4_3_0/queryparser/org/apache/lucene/queryparser/classic/package-summary.html#Overview
    # @param options [Hash] Parameters for the query
    # @option options [Integer] :limit (10) The number of results to return. Maximum 100.
    # @option options [Integer] :offset (0) The starting position of the results.
    # @return Orchestrate::API::CollectionResponse
    # @raise Orchestrate::API::InvalidSearchParam The :limit/:offset values are not valid.
    # @raise Orchestrate::API::SearchQueryMalformed if query isn't a valid Lucene query.
    def search(collection, query, options={})
      send_request :get, [collection], { query: options.merge({query: query}),
                                         response: API::CollectionResponse }
    end

    # Performs a [Delete Collection request](http://orchestrate.io/docs/api/#collections/delete).
    # @param collection [#to_s] The name of the collection
    # @return Orchestrate::API::Response
    # @note The Orchestrate API will return succesfully regardless of if the collection exists or not.
    def delete_collection(collection)
      send_request :delete, [collection], { query: {force:true} }
    end

    #  -------------------------------------------------------------------------
    #  Key/Value

    # Returns a value assigned to a key.  If the `ref` is omitted, returns the latest value.
    # When a ref is provided, performs a [Refs Get query](http://orchestrate.io/docs/api/#refs/get14).
    # When the ref is omitted, performs a [Key/Value Get query](http://orchestrate.io/docs/api/#key/value/get).
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param ref [#to_s] The opaque version identifier of the ref to return.
    # @return Orchestrate::API::ItemResponse
    # @raise Orchestrate::Error::NotFound If the key or ref doesn't exist.
    # @raise Orchestrate::Error::MalformedRef If the ref provided is not a valid ref.
    def get(collection, key, ref=nil)
      path = [collection, key]
      path.concat(['refs', ref]) if ref
      send_request :get, path, { response: API::ItemResponse }
    end

    # Performs a [Refs List query](http://orchestrate.io/docs/api/#refs/list15).
    # Returns a paginated, time-ordered, newest-to-oldest list of refs
    # ("versions") of the object for the specified key in the collection.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param options [Hash] Parameters for the query.
    # @option options [Integer] :limit (10) The number of results to return. Maximum 100.
    # @option options [Integer] :offset (0) The starting position of the results.
    # @option options [true, false] :values (false) Whether to return the value
    #   for each ref.  Refs with no content (for example, deleted with `#delete`) will not have
    #   a value, but marked with a `'tombstone' => true` key.
    # @return Orchestrate::API::CollectionResponse
    # @raise Orchestrate::Error::NotFound If there are no values for the provided key/collection.
    # @raise Orchestrate::API::InvalidSearchParam The :limit/:offset values are not valid.
    # @raise Orchestrate::Error::MalformedRef If the ref provided is not a valid ref.
    def list_refs(collection, key, options={})
      send_request :get, [collection, key, :refs], { query: options, response: API::CollectionResponse }
    end

    # Performs a [Key/Value Put](http://orchestrate.io/docs/api/#key/value/put-\(create/update\)) request.
    # Creates or updates the value at the provided collection/key.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param body [#to_json] The value for the key.
    # @param condition [String, false, nil] Conditions for setting the value. 
    #   If `String`, value used as `If-Match`, value will only be updated if key's current value's ref matches.
    #   If `false`, uses `If-None-Match` the value will only be set if there is no existent value for the key.
    #   If `nil` (default), value is set regardless.
    # @return Orchestrate::API::ItemResponse
    # @raise Orchestrate::Error::BadRequest the body is not valid JSON.
    # @raise Orchestrate::Error::IndexingConflict One of the value's keys
    #   contains a value of a different type than the schema that exists for
    #   the collection.
    # @see Orchestrate::Error::IndexingConflict
    # @raise Orchestrate::Error::VersionMismatch A ref was provided, but it does not match the ref for the current value.
    # @raise Orchestrate::Error::AlreadyPresent the `false` condition was given, but a value already exists for this collection/key combo.
    def put(collection, key, body, condition=nil)
      headers={}
      if condition.is_a?(String)
        headers['If-Match'] = format_ref(condition)
      elsif condition == false
        headers['If-None-Match'] = '*'
      end
      send_request :put, [collection, key], { body: body, headers: headers, response: API::ItemResponse }
    end
    # @!method put_if_unmodified(collection, key, body, condition)
    #   Performs a [Key/Value Put If-Match](http://orchestrate.io/docs/api/#key/value/put-\(create/update\)) request.
    #   (see #put)
    alias :put_if_unmodified :put

    # Performs a [Key/Value Put If-None-Match](http://orchestrate.io/docs/api/#key/value/put-\(create/update\)) request.
    # (see #put)
    def put_if_absent(collection, key, body)
      put collection, key, body, false
    end

    # Performs a [Key/Value delete](http://orchestrate.io/docs/api/#key/value/delete11) request.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param ref [#to_s] The If-Match ref to delete.
    # @return Orchestrate::API::Response
    # @raise Orchestrate::Error::VersionMismatch if the provided ref is not the ref for the current value.
    # @note previous versions of the values at this key are still available via #list_refs and #get.
    def delete(collection, key, ref=nil)
      headers = {}
      headers['If-Match'] = format_ref(ref) if ref
      send_request :delete, [collection, key], { headers: headers }
    end

    # Performs a [Key/Value purge](http://orchestrate.io/docs/api/#key/value/delete11) request.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @return Orchestrate::API::Response
    def purge(collection, key)
      send_request :delete, [collection, key], { query: { purge: true } }
    end

    # -------------------------------------------------------------------------
    #  Events

    # Performs a [Events Get](http://orchestrate.io/docs/api/#events/get19) request.
    # Retrieves an individual event.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param event_type [#to_s] The category for the event.
    # @param timestamp [Time, Date, Integer, String] The timestamp for the event.
    #   If a String, must match the [Timestamp specification](http://orchestrate.io/docs/api/#events/timestamps)
    #   and include the milliseconds portion.
    # @param ordinal [Integer, #to_s] The ordinal for the event in the given timestamp.
    # @return Orchestrate::API::ItemResponse
    # @raise Orchestrate::API::NotFound If the requested event doesn't exist.
    def get_event(collection, key, event_type, timestamp, ordinal)
      timestamp = Helpers.timestamp(timestamp)
      path = [collection, key, 'events', event_type, timestamp, ordinal]
      send_request :get, path, { response: API::ItemResponse }
    end

    # Performs a [Events Post](http://orchestrate.io/docs/api/#events/post-\(create\)) request.
    # Creates an event.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param event_type [#to_s] The category for the event.
    # @param body [#to_json] The value for the event.
    # @param timestamp [Time, Date, Integer, String, nil] The timestamp for the event.
    #   If omitted, the timestamp is created by Orchestrate.
    #   If a String, must match the [Timestamp specification](http://orchestrate.io/docs/api/#events/timestamps).
    # @return Orchestrate::API::ItemResponse
    # @raise Orchestrate::API::BadRequest If the body is not valid JSON.
    def post_event(collection, key, event_type, body, timestamp=nil)
      timestamp = Helpers.timestamp(timestamp)
      path = [collection, key, 'events', event_type, timestamp].compact
      send_request :post, path, { body: body, response: API::ItemResponse }
    end

    # Performs a [Events Put](http://orchestrate.io/docs/api/#events/put-\(update\)) request.
    # Updates an existing event.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param event_type [#to_s] The category for the event.
    # @param timestamp [Time, Date, Integer, String, nil] The timestamp for the event.
    #   If a String, must match the [Timestamp specification](http://orchestrate.io/docs/api/#events/timestamps)
    #   and include the milliseconds portion.
    # @param ordinal [Integer, #to_s] The ordinal for the event in the given timestamp.
    # @param body [#to_json] The value for the event.
    # @param ref [nil, #to_s] If provided, used as `If-Match`, and event will
    #   only update if its current value has the provided ref.  If omitted,
    #   updates the event regardless.
    # @return Orchestrate::API::ItemResponse
    # @raise Orchestrate::API::NotFound The specified event doesn't exist.
    # @raise Orchestrate::API::BadRequest If the body is not valid JSON.
    # @raise Orchestrate::API::VersionMismatch The event's current value has a ref that does not match the provided ref.
    # @raise Orchestrate::Error::MalformedRef If the ref provided is not a valid ref.
    def put_event(collection, key, event_type, timestamp, ordinal, body, ref=nil)
      timestamp = Helpers.timestamp(timestamp)
      path = [collection, key, 'events', event_type, timestamp, ordinal]
      headers = {}
      headers['If-Match'] = format_ref(ref) if ref
      send_request :put, path, { body: body, headers: headers, response: API::ItemResponse }
    end

    # Performs a [Events Delete](http://orchestrate.io/docs/api/#events/delete22) request.
    # Deletes an existing event.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param event_type [#to_s] The category for the event.
    # @param timestamp [Time, Date, Integer, String, nil] The timestamp for the event.
    #   If a String, must match the [Timestamp specification](http://orchestrate.io/docs/api/#events/timestamps)
    #   and include the milliseconds portion.
    # @param ordinal [Integer, #to_s] The ordinal for the event in the given timestamp.
    # @param ref [nil, #to_s] If provided, used as `If-Match`, and event will
    #   only update if its current value has the provided ref.  If omitted,
    #   updates the event regardless.
    # @return Orchestrate::API::Response
    # @raise Orchestrate::API::VersionMismatch The event's current value has a ref that does not match the provided ref.
    # @raise Orchestrate::Error::MalformedRef If the ref provided is not a valid ref.
    def purge_event(collection, key, event_type, timestamp, ordinal, ref=nil)
      timestamp = Helpers.timestamp(timestamp)
      path = [collection, key, 'events', event_type, timestamp, ordinal]
      headers = {}
      headers['If-Match'] = format_ref(ref) if ref
      send_request :delete, path, { query: { purge: true }, headers: headers }
    end

    # Performs a [Events List](http://orchestrate.io/docs/api/#events/list23) request.
    # Retrieves a list of events for the provided collection/key/event_type.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param event_type [#to_s] The category for the event.
    # @param options [Hash] The parameters for the query.
    # @option options [Integer] :limit (10) The number of results to return.  Default 100.
    # @option options [Date, Time, String, Integer] :start The inclusive start of the range.
    # @option options [Date, Time, String, Integer] :after The exclusive start of the range.
    # @option options [Date, Time, String, Integer] :before The exclusive end of the range.
    # @option options [Date, Time, String, Integer] :end The inclusive end of the range.
    # @return Orchestrate::API::CollectionResponse
    # @raise Orchestrate::Error::NotFound If the provided collection/key doesn't exist.
    def list_events(collection, key, event_type, options={})
      (options.keys & [:start, :after, :before, :end]).each do |param|
        options[param] = Helpers.timestamp(options[param])
      end
      Orchestrate::Helpers.range_keys!('event', options)
      path = [collection, key, 'events', event_type]
      send_request :get, path, { query: options, response: API::CollectionResponse }
    end

    # -------------------------------------------------------------------------
    #  Graph

    # Performs a [Graph Get](http://orchestrate.io/docs/api/#graph/get26) request.
    # Retrieves a relation's collection, key, ref and values.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param kinds [#to_s] The relationship kinds and depth to query.
    # @example Retrieves the friend's of John's family
    #   client.get_relations(:users, 'john', :family, :friends)
    # @example If the relation facets exist in an array, use:
    #   relations = [:family, :friends]
    #   client.get_relations(:users, 'john', *relations)
    # @return Orchestrate::API::CollectionResponse
    # @raise Orchestrate::Error::NotFound If the given collection/key doesn't exist.
    def get_relations(collection, key, *kinds)
      path = [collection, key, 'relations'].concat(kinds)
      send_request :get, path, {response: API::CollectionResponse}
    end

    # Performs a [Graph Put](http://orchestrate.io/docs/api/#graph/put) request.
    # Creates a relationship between two Key/Value objects.  Relations can span collections.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param kind [#to_s] The kind of relationship to create.
    # @param to_collection [#to_s] The name of the collection to relate to.
    # @param to_key [#to_s] The name of the key to relate to.
    # @return Orchestrate::API::Response
    # @raise Orchestrate::Error::NotFound If either end of the relation doesn't exist.
    def put_relation(collection, key, kind, to_collection, to_key)
      send_request :put, [collection, key, 'relation', kind, to_collection, to_key]
    end

    # Performs a [Graph Delete](http://orchestrate.io/docs/api/#graph/delete28) request.
    # Deletes a relationship between two objects.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param kind [#to_s] The kind of relationship to delete.
    # @param to_collection [#to_s] The name of the collection to relate to.
    # @param to_key [#to_s] The name of the key to relate to.
    # @return Orchestrate::API::Response
    def delete_relation(collection, key, kind, to_collection, to_key)
      path = [collection, key, 'relation', kind, to_collection, to_key]
      send_request :delete, path, { query: {purge: true} }
    end

    # Performs requests in parallel.  Requires using a Faraday adapter that supports parallel requests.
    # @yieldparam accumulator [Hash] A place to store the results of the parallel responses.
    # @example Performing three requests at once
    #   responses = client.in_parallel do |r|
    #     r[:some_items] = client.list(:site_globals)
    #     r[:user] = client.get(:users, current_user_key)
    #     r[:user_feed] = client.list_events(:users, current_user_key, :notices)
    #   end
    def in_parallel(&block)
      accumulator = {}
      http.in_parallel do
        block.call(accumulator)
      end
      accumulator
    end

    # Performs an HTTP request against the Orchestrate API
    # @param method [Symbol] The HTTP method - :get, :post, :put, :delete
    # @param url [Array<string>] Path segments for the request's URI.  Prepended by 'v0'.
    # @param options [Hash] extra parameters
    # @option options [Hash] :query ({}) Query String parameters.
    # @option options [#to_json] :body ('') The request body.
    # @option options [Hash] :headers ({}) Extra request headers.
    # @option options [Class] :response (Orchestrate::API::Response) A subclass of Orchestrate::API::Response to instantiate and return
    # @return API::Response
    # @see Orchestrate::Error The full list of exceptions that may be raised by accessing the API
    def send_request(method, url, options={})
      url = ['/v0'].concat(url).join('/')
      query_string = options.fetch(:query, {})
      body = options.fetch(:body, '')
      headers = options.fetch(:headers, {})
      headers['User-Agent'] = "ruby/orchestrate/#{Orchestrate::VERSION}"
      headers['Accept'] = 'application/json' if method == :get

      response = http.send(method) do |request|
        request.url url, query_string
        if [:put, :post].include?(method)
          headers['Content-Type'] = 'application/json'
          request.body = body.to_json
        end
        headers.each {|header, value| request[header] = value }
      end

      Error.handle_response(response) if (!response.success?)
      response_class = options.fetch(:response, API::Response)
      response_class.new(response, self)
    end

    # ------------------------------------------------------------------------

    private

      # Formats the provided 'ref' to be quoted per API specification.  If
      # already quoted, does not add additional quotes.
      def format_ref(ref)
        "\"#{ref.gsub(/"/,'')}\""
      end

  end

end
