module Orchestrate::API

  require 'net/http'

  class Request < Object

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

    def verbose?
      verbose == true
    end

    # Sends the HTTP request and returns a Response object.
    def perform

      uri = URI(url)

      response = Net::HTTP.start(uri.hostname, uri.port,
        :use_ssl => uri.scheme == 'https' ) { |http|
        puts "\n------- #{method.to_s.upcase} \"#{url}\" ------" if verbose?
        http.request(request(uri))
      }

      # Response expects an HTTParty response, so just fake it - for now... JMC
      # See below for more details...
      Response.new(
        FakePartayResponse.new(
          response.to_hash,
          response.code.to_i,
          response.message,
          response.body,
          response['Etag']
        )
      )
    end

    # Assembles the Net::HTTP request.
    #
    def request(uri)
      case
      when method == :get
        request = Net::HTTP::Get.new(uri)
      when method == :put
        request = Net::HTTP::Put.new(uri)
        request['Content-Type'] = 'application/json'
        # request['Accept'] = 'application/json'
        if ref
          header = ref == '"*"' ? 'If-None-Match' : 'If-Match'
          request[header] = ref
        end
        request.body = data
      when method == :delete
        request = Net::HTTP::Delete.new(uri)
      end

      # request['Accept'] = 'application/json'
      # request['Content-Type'] = 'application/json'
      request['Orchestrate-Client'] = "ruby/orchestrate-api/#{Orchestrate::API::VERSION}"
      request.basic_auth @user, nil
      request
    end
  end

  # Just fake the HTTParty response - for now... JMC
  #
  # This is also a convenient place to stash the *very temporary* hack to work
  # around the mysterious disappearance of the Etag header when using Net::HTTP.
  #
  class FakePartayResponse

    attr_accessor :headers, :code, :msg, :body

    def initialize(headers, code, msg, body, etag)
      @headers, @code, @msg, @body = headers, code, msg, body

      if code == 200 && headers['etag']
        @headers['etag'] = headers['etag'].first.sub(/\-gzip/, '')
      elsif code == 201 && @headers['location']
        @headers['etag'] = "\"#{@headers['location'].first.split('/').last}\""
      end
    end

    def success?
      [200, 201, 204].include? code
    end
  end

end

