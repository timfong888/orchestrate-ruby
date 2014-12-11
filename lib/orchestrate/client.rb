require 'faraday'
require 'uri'

module Orchestrate

  # The "method client": A single entry point to an Orchestrate Application,
  # with methods for accessing each API endpoint.
  class Client

    # @return [String] The API key provided
    attr_reader :api_key

    # @return [String] The Orchestrate data center URL
    attr_reader :host

    # @return [Faraday::Connection] The Faraday HTTP connection.
    attr_reader :http

    # @return [Proc] The block used to configure faraday.
    attr_reader :faraday_configuration

    # Instantiate a new Client for an Orchestrate application.
    # @param api_key [#to_s] The API Key for your Orchestrate application.
    # @param host [#to_s] The host datacenter for your Orchestrate application.
    # @yieldparam [Faraday::Connection] The setup for the faraday connection.
    # @return Orchestrate::Client
    # @todo api_key -> app_url, parse api_key from auth section of url
    def initialize(api_key, host="https://api.orchestrate.io", &block)
      @api_key = api_key
      @host = host
      @faraday_configuration = block
      @http = Faraday.new(@host) do |faraday|
        block = lambda{|f| f.adapter :net_http_persistent } unless block
        block.call faraday

        # faraday seems to want you do specify these twice.
        faraday.request :basic_auth, api_key, ''
        faraday.basic_auth api_key, ''
      end
    end

    # @!visibility private
    def to_s
      "#<Orchestrate::Client api_key=#{api_key[0..7]}... >"
    end
    alias :inspect :to_s

    # @!visibility private
    def dup
      self.class.new(api_key, &faraday_configuration)
    end

    # Tests authentication with Orchestrate.
    # @return Orchestrate::API::Response
    # @raise Orchestrate::API::Unauthorized if the client could not authenticate.
    def ping
      send_request :head, []
    end

    # @!group Collections

    # [Search the items in
    # a collection](http://orchestrate.io/docs/api/#search) using a Lucene
    # Query Syntax.
    # @param collection [#to_s] The name of the collection
    # @param query [String] The [Lucene Query String][lucene] to query the collection with.
    #   [lucene]: http://lucene.apache.org/core/4_3_0/queryparser/org/apache/lucene/queryparser/classic/package-summary.html#Overview
    # @param options [Hash] Parameters for the query
    # @option options [Integer] :limit (10) The number of results to return. Maximum 100.
    # @option options [Integer] :offset (0) The starting position of the results.
    # @option options [String]  :sort The field and direction to sort by. Ex: `value.name:asc`
    # @return Orchestrate::API::CollectionResponse
    # @raise Orchestrate::API::InvalidSearchParam The :limit/:offset values are not valid.
    # @raise Orchestrate::API::SearchQueryMalformed if query isn't a valid Lucene query.
    def search(collection, query, options={})
      send_request :get, [collection], { query: options.merge({query: query}),
                                         response: API::CollectionResponse }
    end

    # [Deletes an entire collection](http://orchestrate.io/docs/api/#collections/delete)
    # @param collection [#to_s] The name of the collection
    # @return Orchestrate::API::Response
    # @note The Orchestrate API will return succesfully regardless of if the collection exists or not.
    def delete_collection(collection)
      send_request :delete, [collection], { query: {force:true} }
    end

    # @!endgroup
    # @!group Key/Value

    # [Retrieves the value assigned to a key](http://orchestrate.io/docs/api/#key/value/get).
    # If a `ref` parameter is provided, [retrieves a historical value for the
    # key](http://orchestrate.io/docs/api/#refs/get14)
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param ref [#to_s] The opaque version identifier of the ref to return, if a historical value is desired.
    # @return Orchestrate::API::ItemResponse
    # @raise Orchestrate::API::NotFound If the key or ref doesn't exist.
    # @raise Orchestrate::API::MalformedRef If the ref provided is not a valid ref.
    def get(collection, key, ref=nil)
      path = [collection, key]
      path.concat(['refs', ref]) if ref
      send_request :get, path, { response: API::ItemResponse }
    end

    # [List historical refs for values of a key](http://orchestrate.io/docs/api/#refs/list15).
    # Results are time-ordered newest-to-oldest and paginated.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param options [Hash] Parameters for the query.
    # @option options [Integer] :limit (10) The number of results to return. Maximum 100.
    # @option options [Integer] :offset (0) The starting position of the results.
    # @option options [true, false] :values (false) Whether to return the value
    #   for each ref.  Refs with no content (for example, deleted with `#delete`) will not have
    #   a value, but marked with a `'tombstone' => true` key.
    # @return Orchestrate::API::CollectionResponse
    # @raise Orchestrate::API::NotFound If there are no values for the provided key/collection.
    # @raise Orchestrate::API::InvalidSearchParam The :limit/:offset values are not valid.
    # @raise Orchestrate::API::MalformedRef If the ref provided is not a valid ref.
    def list_refs(collection, key, options={})
      send_request :get, [collection, key, :refs], { query: options, response: API::CollectionResponse }
    end

    # [Creates a value at an auto-generated
    # key](https://orchestrate.io/docs/api/?shell#key/value/post-\(create-&-generate-key\)).
    # @param collection [#to_s] The name of the collection.
    # @param body [#to_json] The value to store.
    # @return Orchestrate::API::ItemResponse
    def post(collection, body)
      send_request :post, [collection], { body: body, response: API::ItemResponse }
    end

    # [Updates the value associated with
    # a key](http://orchestrate.io/docs/api/#key/value/put-\(create/update\)).
    # If the key does not currently have a value, will create the value.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param body [#to_json] The value for the key.
    # @param condition [String, false, nil] Conditions for setting the value.
    #   If `String`, value used as `If-Match`, value will only be updated if key's current value's ref matches.
    #   If `false`, uses `If-None-Match` the value will only be set if there is no existent value for the key.
    #   If `nil` (default), value is set regardless.
    # @return Orchestrate::API::ItemResponse
    # @raise Orchestrate::API::BadRequest the body is not valid JSON.
    # @raise Orchestrate::API::IndexingConflict One of the value's keys
    #   contains a value of a different type than the schema that exists for
    #   the collection.
    # @see Orchestrate::API::IndexingConflict
    # @raise Orchestrate::API::VersionMismatch A ref was provided, but it does not match the ref for the current value.
    # @raise Orchestrate::API::AlreadyPresent the `false` condition was given, but a value already exists for this collection/key combo.
    def put(collection, key, body, condition=nil)
      headers={}
      if condition.is_a?(String)
        headers['If-Match'] = API::Helpers.format_ref(condition)
      elsif condition == false
        headers['If-None-Match'] = '"*"'
      end
      send_request :put, [collection, key], { body: body, headers: headers, response: API::ItemResponse }
    end
    alias :put_if_unmodified :put

    # [Creates the value for a key if none
    # exists](http://orchestrate.io/docs/api/#key/value/put-\(create/update\)).
    # @see #put
    def put_if_absent(collection, key, body)
      put collection, key, body, false
    end

    # Manipulate values associated with a key, without retrieving the key object.
    # Array of operations passed as body, will execute operations on the key sequentially.
    # [Patch](http://orchestrate.io/docs/apiref#keyvalue-patch).
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param body [#to_json] The value for the key.
    # @param condition [String, false, nil] Conditions for setting the value.
    #   If `String`, value used as `If-Match`, value will only be updated if key's current value's ref matches.
    #   If `nil` (default), value is set regardless.
    # @return Orchestrate::API::ItemResponse
    # @raise Orchestrate::API::BadRequest the body is not valid JSON.
    # @raise Orchestrate::API::AlreadyPresent the `false` condition was given, but a value already exists for this collection/key combo.
    def patch(collection, key, body, condition=nil)
      headers = {'Content-Type' => 'application/json-patch+json'}
      if condition.is_a?(String)
        headers['If-Match'] = API::Helpers.format_ref(condition)
      end
      send_request :patch, [collection, key], { body: body, headers: headers, response: API::ItemResponse }
    end

    # Merge field/value pairs into existing key, without retrieving the key object.
    # [Patch](http://orchestrate.io/docs/apiref#keyvalue-patch-merge).
    # If a given field's value is nil, will remove field from existing key on merge.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param body [#to_json] The value for the key.
    # @param condition [String, false, nil] Conditions for setting the value.
    #   If `String`, value used as `If-Match`, value will only be updated if key's current value's ref matches.
    #   If `nil` (default), value is set regardless.
    # @return Orchestrate::API::ItemResponse
    # @raise Orchestrate::API::BadRequest the body is not valid JSON.
    # @raise Orchestrate::API::AlreadyPresent the `false` condition was given, but a value already exists for this collection/key combo.
    def patch_merge(collection, key, body, condition=nil)
      headers = {'Content-Type' => 'application/merge-patch+json'}
      if condition.is_a?(String)
        headers['If-Match'] = API::Helpers.format_ref(condition)
      end
      send_request :patch, [collection, key], { body: body, headers: headers, response: API::ItemResponse }
    end

    # [Sets the current value of a key to a null
    # object](http://orchestrate.io/docs/api/#key/value/delete11).
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param ref [#to_s] If specified, deletes the ref only if the current value's ref matches.
    # @return Orchestrate::API::Response
    # @raise Orchestrate::API::VersionMismatch if the provided ref is not the ref for the current value.
    # @note previous versions of the values at this key are still available via #list_refs and #get.
    def delete(collection, key, ref=nil)
      headers = {}
      headers['If-Match'] = API::Helpers.format_ref(ref) if ref
      send_request :delete, [collection, key], { headers: headers }
    end

    # [Purges the current value and ref history associated with the
    # key](http://orchestrate.io/docs/api/#key/value/delete11).
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param ref [#to_s] If specified, purges the ref only if the current value's ref matches.
    # @return Orchestrate::API::Response
    def purge(collection, key, ref=nil)
      headers = {}
      headers['If-Match'] = API::Helpers.format_ref(ref) if ref
      send_request :delete, [collection, key], { query: { purge: true }, headers: headers }
    end

    # [List the KeyValue items in a collection](http://orchestrate.io/docs/api/#key/value/list).
    # Results are sorted results lexicographically by key name and paginated.
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
      API::Helpers.range_keys!('key', options)
      send_request :get, [collection], { query: options, response: API::CollectionResponse }
    end

    # @!endgroup
    # @!group Events

    # [Retrieves an individual event](http://orchestrate.io/docs/api/#events/get19).
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
      timestamp = API::Helpers.timestamp(timestamp)
      path = [collection, key, 'events', event_type, timestamp, ordinal]
      send_request :get, path, { response: API::ItemResponse }
    end

    # [Creates an event](http://orchestrate.io/docs/api/#events/post-\(create\)).
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
      timestamp = API::Helpers.timestamp(timestamp)
      path = [collection, key, 'events', event_type, timestamp].compact
      send_request :post, path, { body: body, response: API::ItemResponse }
    end

    # [Updates an existing event](http://orchestrate.io/docs/api/#events/put-\(update\)).
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
    # @raise Orchestrate::API::MalformedRef If the ref provided is not a valid ref.
    def put_event(collection, key, event_type, timestamp, ordinal, body, ref=nil)
      timestamp = API::Helpers.timestamp(timestamp)
      path = [collection, key, 'events', event_type, timestamp, ordinal]
      headers = {}
      headers['If-Match'] = API::Helpers.format_ref(ref) if ref
      send_request :put, path, { body: body, headers: headers, response: API::ItemResponse }
    end

    # [Deletes an existing event](http://orchestrate.io/docs/api/#events/delete22).
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
    # @raise Orchestrate::API::MalformedRef If the ref provided is not a valid ref.
    def purge_event(collection, key, event_type, timestamp, ordinal, ref=nil)
      timestamp = API::Helpers.timestamp(timestamp)
      path = [collection, key, 'events', event_type, timestamp, ordinal]
      headers = {}
      headers['If-Match'] = API::Helpers.format_ref(ref) if ref
      send_request :delete, path, { query: { purge: true }, headers: headers }
    end

    # [Lists events associated with a key](http://orchestrate.io/docs/api/#events/list23).
    # Results are time-ordered in reverse-chronological order, and paginated.
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
    # @raise Orchestrate::API::NotFound If the provided collection/key doesn't exist.
    def list_events(collection, key, event_type, options={})
      (options.keys & [:start, :after, :before, :end]).each do |param|
        options[param] = API::Helpers.timestamp(options[param])
      end
      API::Helpers.range_keys!('event', options)
      path = [collection, key, 'events', event_type]
      send_request :get, path, { query: options, response: API::CollectionResponse }
    end

    # @!endgroup
    # @!group Graphs / Relations

    # [Retrieves a relation's associated objects](http://orchestrate.io/docs/api/#graph/get26).
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param kinds [#to_s] The relationship kinds and depth to query.
    # @example Retrieves the friend's of John's family
    #   client.get_relations(:users, 'john', :family, :friends)
    # @example If the relation facets exist in an array, use:
    #   relations = [:family, :friends]
    #   client.get_relations(:users, 'john', *relations)
    # @return Orchestrate::API::CollectionResponse
    # @raise Orchestrate::API::NotFound If the given collection/key doesn't exist.
    def get_relations(collection, key, *kinds)
      path = [collection, key, 'relations'].concat(kinds)
      send_request :get, path, {response: API::CollectionResponse}
    end

    # [Creates a relationship between two Key/Value objects](http://orchestrate.io/docs/api/#graph/put).
    # Relations can span collections.
    # @param collection [#to_s] The name of the collection.
    # @param key [#to_s] The name of the key.
    # @param kind [#to_s] The kind of relationship to create.
    # @param to_collection [#to_s] The name of the collection to relate to.
    # @param to_key [#to_s] The name of the key to relate to.
    # @return Orchestrate::API::Response
    # @raise Orchestrate::API::NotFound If either end of the relation doesn't exist.
    def put_relation(collection, key, kind, to_collection, to_key)
      send_request :put, [collection, key, 'relation', kind, to_collection, to_key]
    end

    # [Deletes a relationship between two objects](http://orchestrate.io/docs/api/#graph/delete28).
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

    # @!endgroup

    # Performs requests in parallel.  Requires using a Faraday adapter that supports parallel requests.
    # @yieldparam accumulator [Hash] A place to store the results of the parallel responses.
    # @example Performing three requests at once
    #   responses = client.in_parallel do |r|
    #     r[:some_items] = client.list(:site_globals)
    #     r[:user] = client.get(:users, current_user_key)
    #     r[:user_feed] = client.list_events(:users, current_user_key, :notices)
    #   end
    # @see README See the Readme for more examples.
    # @note This method is not Thread-safe.  Requests generated from the same
    #   client in different threads while #in_parallel is running will behave
    #   unpredictably.  Use `#dup` to create per-thread clients.
    def in_parallel(&block)
      accumulator = {}
      http.in_parallel do
        block.call(accumulator)
      end
      accumulator
    end

    # Performs an HTTP request against the Orchestrate API
    # @param method [Symbol] The HTTP method - :get, :post, :put, :delete
    # @param path [Array<#to_s>] Path segments for the request's URI.  Prepended by 'v0'.
    # @param options [Hash] extra parameters
    # @option options [Hash] :query ({}) Query String parameters.
    # @option options [#to_json] :body ('') The request body.
    # @option options [Hash] :headers ({}) Extra request headers.
    # @option options [Class] :response (Orchestrate::API::Response) A subclass of Orchestrate::API::Response to instantiate and return
    # @return API::Response
    # @raise [Orchestrate::API::RequestError, Orchestrate::API::ServiceError] see http://orchestrate.io/docs/api/#errors
    def send_request(method, path, options={})
      path = ['/v0'].concat(path.map{|s| URI.escape(s.to_s).gsub('/','%2F') }).join('/')
      query_string = options.fetch(:query, {})
      body = options.fetch(:body, '')
      headers = options.fetch(:headers, {})
      headers['User-Agent'] = "ruby/orchestrate/#{Orchestrate::VERSION}"
      headers['Accept'] = 'application/json' if method == :get

      http_response = http.send(method) do |request|
        request.url path, query_string
        if [:put, :post].include?(method)
          headers['Content-Type'] = 'application/json'
          request.body = body.to_json
        elsif [:patch].include?(method)
          request.body = body.to_json    
        end
        headers.each {|header, value| request[header] = value }
      end

      response_class = options.fetch(:response, API::Response)
      response_class.new(http_response, self)
    end
  end

end
