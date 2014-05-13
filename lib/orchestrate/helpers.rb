module Orchestrate
  module Helpers

    extend self

    #  * required: type, params={}
    #
    #  Given a params object such as { start: ..., end: ... } and a type such as 'event',
    #  will return a hash with those parameters formatted for the Orchestrate API, f.e.:
    #  { 'startEvent' => ..., 'endEvent' => ... }
    def range_keys!(type, params)
      type = type.capitalize
      [:start, :end, :before, :after].each do |key|
        if params[key]
          params["#{key}#{type}"] = params[key]
          params.delete(key)
        end
      end
    end

  end
end
