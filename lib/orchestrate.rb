require "orchestrate/api"
require "orchestrate/client"
require "orchestrate/application"
require "orchestrate/collection"
require "orchestrate/search"
require "orchestrate/key_value"
require "orchestrate/refs"
require "orchestrate/event"
require "orchestrate/event_source"
require "orchestrate/graph"
require "orchestrate/version"
#
# A library for supporting connections to the \Orchestrate API.
#
module Orchestrate

  # If you attempt to enumerate over results in an in_parallel block
  class ResultsNotReady < StandardError; end
end
