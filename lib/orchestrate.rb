require "orchestrate/api"
require "orchestrate/client"
require "orchestrate/configuration"
require "orchestrate/version"

#
# A library for supporting connections to the \Orchestrate API.
#
module Orchestrate

  # Configuration ------------------------------------------------------------

  class << self

    #
    # An instance of Configuration containing the current library
    # configuration options.
    #
    attr_accessor :config

    #
    # Lazily initialize and return the Configuration instance.
    #
    def config # :nodoc:
      @config ||= Configuration.new
    end

    #
    # Configure the Orchestrate library. This method should be called during
    # application or script initialization. At a bare minimum, the Orchestrate
    # library will require that an API key is provided.
    #
    # ==== Example
    #
    #   Orchestrate.configure do |config|
    #     config.api_key = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    #   end
    #
    def configure
      yield config
    end

  end

end
