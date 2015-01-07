require 'forwardable'
require 'webrick'
require 'json' unless defined?(::JSON)

module Orchestrate::API

  # A generic response from the API.
  class Response

    extend Forwardable
    def_delegators :@response, :status, :headers, :success?, :finished?, :on_complete
    # @!attribute [r] status
    #   @return [Integer] The HTTP Status code of the response.
    # @!attribute [r] body
    #   @return [Hash, String] The response body, de-serialized from JSON.
    # @!attribute [r] headers
    #   @return [Hash{String => String}] The response headers
    # @!method success?()
    #   @return [true, false] If the response is 1xx-3xx class response or a 4xx-5xx class response.
    # @!method finished?()
    #   @return [true, false] If the response is finished or not.
    # @!method on_complete()
    #   @yield [block] A block to be called when the response has completed.

    # @return [String] The Orchestrate API Request ID.  For use when troubleshooting.
    attr_reader :request_id

    # @return [Time] The time at which the response was made.
    attr_reader :request_time

    # @return [Orchestrate::Client] The client used to generate the response.
    attr_reader :client

    # @return [String, Hash] The response body from Orchestrate
    attr_reader :body

    # Instantiate a new Respose
    # @param faraday_response [Faraday::Response] The Faraday response object.
    # @param client [Orchestrate::Client] The client used to generate the response.
    def initialize(faraday_response, client)
      @client = client
      @response = faraday_response
      @response.on_complete do
        @request_id = headers['X-Orchestrate-Req-Id'] if headers['X-Orchestrate-Req-Id']
        @request_time = Time.parse(headers['Date']) if headers['Date']
        if headers['Content-Type'] =~ /json/ && !@response.body.strip.empty?
          @body = JSON.parse(@response.body)
        else
          @body = @response.body
        end
        handle_error_response unless success?
      end
    end

    # @!visibility private
    def to_s
      "#<#{self.class.name} status=#{status} request_id=#{request_id}>"
    end
    alias :inspect :to_s

    private
    def handle_error_response
      err_type = if body && body['code']
        ERRORS.find {|err| err.status == status && err.code == body['code'] }
      else
        errors = ERRORS.select {|err| err.status == status}
        errors.length == 1 ? errors.first : nil
      end
      if err_type
        raise err_type.new(self)
      elsif status < 500
        raise RequestError.new(self)
      else
        raise ServiceError.new(self)
      end
    end

  end

  # A generic response for a single entity (K/V, Ref, Event)
  class ItemResponse < Response

    # @return [String] The 'Location' of the item.
    attr_reader :location

    # @return [String] The canonical 'ref' of the item.
    attr_reader :ref

    # (see Orchestrate::API::Response#initialize)
    def initialize(faraday_response, client)
      super(faraday_response, client)
      @response.on_complete do
        @location = headers['Content-Location'] || headers['Location']
        @ref = headers.fetch('Etag','').gsub('"','').sub(/-gzip$/,'')
      end
    end

  end

  # A generic response for a collection of entities (K/V, Refs, Events, Search)
  class CollectionResponse < Response

    # @return [Integer] The number of items in this response
    attr_reader :count

    # @return [Integer, nil] If provided, the number of total items for this collection
    attr_reader :total_count

    # @return [Array] The items in the response.
    attr_reader :results

    # @return [Array] The aggregate items in the response.
    attr_reader :aggregates

    # @return [String] The location for the next page of results
    attr_reader :next_link

    # @return [String] The location for the previous page of results
    attr_reader :prev_link

    # (see Orchestrate::API::Response#initialize)
    def initialize(faraday_response, client)
      super(faraday_response, client)
      @response.on_complete do
        @count = body['count']
        @total_count = body['total_count']
        @results = body['results']
        @aggregates = body['aggregates']
        @next_link = body['next']
        @prev_link = body['prev']
      end
    end

    # Retrieves the next page of results, if available
    # @return [nil, Orchestrate::API::CollectionResponse]
    def next_results
      fire_request(next_link)
    end

    # Retrieves the previous page of results, if available
    # @return [nil, Orchestrate::API::CollectionResponse]
    def previous_results
      fire_request(prev_link)
    end

    private
    def fire_request(link)
      return nil unless link
      uri = URI(link)
      params = WEBrick::HTTPUtils.parse_query(uri.query)
      path = uri.path.split("/")[2..-1]
      @client.send_request(:get, path, { query: params, response: self.class })
    end
  end
end
