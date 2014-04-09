#
# A library for supporting connections to the \Orchestrate API.
#
module Orchestrate

  # Configuration ------------------------------------------------------------

  require "orchestrate/configuration"

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

  #
  # Ruby gem +orchestrate-api+ provides an interface to the
  # [Orchestrate](http://orchestrate.io) API.
  #
  # The API::Wrapper class is used to setup the client and make HTTP requests.
  #
  module API

    require "orchestrate/api/procedural"
    require "orchestrate/api/wrapper"
    require "orchestrate/api/request"
    require "orchestrate/api/response"
    require "orchestrate/api/url"
    require "orchestrate/api/version"
    require "orchestrate/api/extensions"

  end

end
