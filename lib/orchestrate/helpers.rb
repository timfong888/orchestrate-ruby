module Orchestrate
  module Helpers

    extend self

    # will suffix a params hash for range bounds with the given type
    # @param suffix [String] the suffix for the range keys
    # @param params [Hash{Symbol=>Value}]
    # @option params :start The inclusive start of the range
    # @option params :after The exclusive start of the range
    # @option params :before The exclusive end of the range
    # @option params :end The inclusive end of the range
    # @return [Hash{Symbol=>Value}]
    # @example Transforming an Event Range
    #   Orchestrate::Helpers.range_keys!('event', { start: Value }) #=> { startEvent: Value }
    def range_keys!(suffix, params)
      suffix = suffix.capitalize
      [:start, :end, :before, :after].each do |key|
        if params[key]
          params["#{key}#{suffix}"] = params[key]
          params.delete(key)
        end
      end
    end

    # call-seq:
    #   Orchestrate::Helpers.timestamp(time) -> Integer
    #
    # Returns the Milliseconds since Unix Epoch if given a Time, or Date object.
    # Otherwise, returns value called with.
    def timestamp(time)
      time = time.to_time if time.kind_of?(Date)
      time = (time.getutc.to_f * 1000).to_i if time.kind_of?(Time)
      time
    end

  end
end
