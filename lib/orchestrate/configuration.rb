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
  #       config.verbose = true
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
    # Controlers whether verbose output is enabled. Default +false+.
    #
    # TODO Replace this with logger with log levels
    #
    attr_accessor :verbose

    #
    # Initialize and return a new instance of Configuration.
    #
    def initialize(options = {}) # :nodoc:
      @api_key = options[:api_key]
      @base_url = options[:base_url] || "https://api.orchestrate.io/v0"
      @verbose = options[:verbose].nil? ? false : options[:verbose]
    end

  end

end
