module Orchestrate::API

  require 'faraday'
  require 'faraday_middleware'
  require 'net/http'

  class Request

    # The HTTP method - must be one of: [ :get, :put, :delete ].
    attr_accessor :method

    # The url for the HTTP request.
    attr_accessor  :url

    # The json document for creating or updating a key.
    attr_accessor  :data

    # The ref value associated with a key.
    attr_accessor  :ref

    # the http client associated with the client
    attr_accessor :http

    # Sets the universal attributes from the params; any additional
    # attributes are set from the block.
    #
    def initialize(http, method, url)
      @http, @method, @url = http, method, url
      @data = ''
      yield self if block_given?
    end

    # Sends the HTTP request and returns a Response object.
    def perform
      response = http.send(method) do |request|
        Orchestrate.config.logger.debug "Performing #{method.to_s.upcase} request to \"#{url}\""
        request.url url
        if method == :put
          request.headers['Content-Type'] = 'application/json'
          # TODO abstract this out
          if ref == "*"
            request['If-None-Match'] = ref
          elsif ref
            request['If-Match'] = ref
          end
          request.body = data
        elsif method == :delete && ref != "*"
          request['If-Match'] = ref
        elsif method == :get
          request['Accept'] = 'application/json'
        end
        request.headers['User-Agent'] = "ruby/orchestrate/#{Orchestrate::VERSION}"
      end
      Response.new(response)
    end

  end
end

