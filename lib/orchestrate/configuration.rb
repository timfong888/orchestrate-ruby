require "logger"

module Orchestrate

  #
  # Represents the configuration for the Orchestrate library, including
  # values for the api key, base url and other settings.
  #
  # An instance of this class is always available at Orchestrate.config.
  # You should not
  # instantiate instances of this class, instead, you should configure the
  # library with the Orchestrate.configure method.
  #
  # === Example
  #
  #     Orchestrate.configure do |config|
  #       config.api_key = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  #     end
  #
  class Configuration

    #
    # The api key for your app, from the Orchestrate Dashboard.
    #
    attr_accessor :api_key

    #
    # The url to the Orchestrate API. Defaults to \https://api.orchestrate.io/v0.
    #
    attr_accessor :base_url

    #
    # The logger instances to send messages to. Defaults to +STDOUT+.
    #
    attr_accessor :logger

    #
    # Initialize and return a new instance of Configuration.
    #
    def initialize(options = {}) # :nodoc:
      @api_key = options[:api_key]
      @base_url = options[:base_url] || "https://api.orchestrate.io/v0"
      @logger = options[:logger] || Logger.new(STDOUT)
    end

  end

end
