module Orchestrate::API

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

    # Boolean
    attr_accessor  :verbose

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
      uri = URI(url)
      response = Net::HTTP.start(uri.hostname, uri.port,
        :use_ssl => uri.scheme == 'https' ) { |http|
        puts "\n------- #{method.to_s.upcase} \"#{url}\" ------" if verbose?
        http.request(request(uri))
      }
      Response.new(response)
    end

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

      request['Orchestrate-Client'] = "ruby/orchestrate-api/#{Orchestrate::API::VERSION}"
      request.basic_auth @user, nil
      request
    end

    def verbose?
      verbose == true
    end

  end
end

