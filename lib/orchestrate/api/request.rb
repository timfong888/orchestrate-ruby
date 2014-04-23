module Orchestrate::API

  require 'faraday'
  require 'faraday_middleware'
  require 'net/http'

  class Request

    # The HTTP method - must be one of: [ :get, :put, :delete ].
    attr_accessor :method

    # The url for the HTTP request.
    attr_accessor  :url

    # The api key for HTTP Basic Authentication over SSL.
    attr_accessor :user

    # The json document for creating or updating a key.
    attr_accessor  :data

    # The ref value associated with a key.
    attr_accessor  :ref

    # Sets the universal attributes from the params; any additional
    # attributes are set from the block.
    #
    def initialize(method, url, user)
      @method, @url, @user = method, url, user
      @data = ''
      yield self if block_given?
    end

    # Sends the HTTP request and returns a Response object.
    def perform
      # TODO store the Faraday 'connection' in the config, 
      # investigate if that's a good idea.
      conn = Faraday.new(Orchestrate.config.base_url) do |faraday|
        if adapter = Orchestrate.config.faraday_adapter
          faraday.adapter(*adapter)
        else
          faraday.adapter Faraday.default_adapter
        end
        faraday.request :basic_auth, @user, ''
        # faraday seems to want you do specify these twice.
        faraday.basic_auth @user, ''

        # parses JSON responses
        # faraday.response :json, :content_type => /\bjson$/
      end
      response = conn.send(method) do |request|
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
        request.headers['Orchestrate-Client'] = "ruby/orchestrate/#{Orchestrate::VERSION}"
      end
      Response.new(response)
    end

    # TODO remove this
    # Creates the Net::HTTP request.
    #
    def request(uri)
      case
      when method == :get
        request = Net::HTTP::Get.new(uri)
      when method == :put
        request = Net::HTTP::Put.new(uri)
        request['Content-Type'] = 'application/json'
        if ref
          header = ref == '"*"' ? 'If-None-Match' : 'If-Match'
          request[header] = ref
        end
        request.body = data
      when method == :delete
        request = Net::HTTP::Delete.new(uri)
      end

      request['Orchestrate-Client'] = "ruby/orchestrate-api/#{Orchestrate::VERSION}"
      request.basic_auth @user, nil
      request
    end

  end
end

