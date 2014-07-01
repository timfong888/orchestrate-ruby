require "orchestrate/api"
require "orchestrate/client"
require "orchestrate/application"
require "orchestrate/collection"
require "orchestrate/key_value"
require "orchestrate/version"
#
# A library for supporting connections to the \Orchestrate API.
#
module Orchestrate

  class ResultsNotReady < StandardError; end
end
