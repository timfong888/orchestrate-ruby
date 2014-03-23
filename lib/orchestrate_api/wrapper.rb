module Orchestrate::API

  require "active_support/core_ext"

  # ==== Ruby wrapper for the Orchestrate.io REST *API*.
  #
  # The primary entry point is the <b> #send_request</b> method, which
  # generates a <b> Request</b>, and returns the
  # <b> Response</b> to the caller.
  # <b>{Usage examples for each HTTP request}[Procedural.html]</b>
  # are documented in the <b> Procedural</b> interface module.
  #
  class Wrapper < Object
    include Orchestrate::API::Procedural

    attr_accessor :verbose

    # Loads settings from the configuration file and returns the client
    # handle to be used for subsequent requests.
    #
    #  Example config file: "./lib/orch_config.json"
    #
    #   {
    #     "base_url":"https://api.orchestrate.io/v0",
    #     "user":"<user-key-from-orchestrate.io>",
    #     "verbose":"false"
    #   }
    #
    def initialize(config_file)
      orch_config = ::ActiveSupport::JSON.decode open(config_file).read
      @base_url = orch_config['base_url']
      @user     = orch_config['user']
      @verbose  = orch_config['verbose'] && orch_config['verbose'] == 'true' ? true
                                                                             : false
    end

    # Creates the Request object and sends it via the perform method,
    # which generates and returns the Response object.
    #
    def send_request(method, args)
      request = Orchestrate::API::Request.new(method, build_url(method, args), @user) do |r|
        r.data = args[:json] if args[:json]
        r.ref = args[:ref] if args[:ref]
        r.verbose = verbose
      end
      request.perform
    end

    private

      # Builds the URL for each HTTP request to the orchestrate.io api.
      #
      def build_url(method, args)
        uri = "#{@base_url}/#{args[:collection]}"
        if args[:key]
          uri << "/#{args[:key]}"
          if args[:ref]
            uri << "/refs/#{args[:ref].gsub(/"/, '')}" if method == :get
          elsif args[:event_type]
            uri << "/events/#{args[:event_type]}"
            unless args[:timestamp].blank?
              if method == :get && args[:timestamp][:start]
                uri << "?start=#{args[:timestamp][:start]}&end=#{args[:timestamp][:end]}"
              elsif method == :put
                uri << "?timestamp=#{args[:timestamp]}"
              end
            end
          elsif args[:kind]
            if method == :get
              uri << "/relations/#{args[:kind]}"
            else
              uri << "/relation/#{args[:kind]}/#{args[:to_collection]}/#{args[:to_key]}"
            end
          end
        end
        uri << args[:path] if args[:path]
        uri
      end

  end
end


