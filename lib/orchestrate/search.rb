module Orchestrate
  # Namespace for concerns related to the Orchestrate API
  module Search
  end

end

require_relative 'search/query_builder.rb'
require_relative 'search/aggregate_builder.rb'
require_relative 'search/results.rb'