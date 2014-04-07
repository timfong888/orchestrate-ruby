module Orchestrate::API

  require 'httparty'

  #  Uses HTTParty to make the HTTP calls,
  #  and returns a Response object.
  #
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
      @data = {}
      yield self if block_given?
    end

    # Sends the HTTP request and returns a Response object.
    def perform
      puts "\n------- #{method.to_s.upcase} \"#{url}\" ------" if verbose?
      Response.new HTTParty.send(method, url, options)
    end

    private

      # Sets up the HTTParty options hash.
      def options
        options = { basic_auth: { username: user, password: nil }}
        headers = { 'Content-Type' => 'application/json',
                    'Orchestrate-Client' => "ruby/orchestrate-api/#{Orchestrate::API::VERSION}" }
        if method == :put
          if ref
            header = ref == '"*"' ? 'If-None-Match' : 'If-Match'
            headers.merge!(header => ref)
          end
        end
        options.merge(headers: headers, body: data)
      end

      def verbose?
        verbose == true
      end
  end
end
