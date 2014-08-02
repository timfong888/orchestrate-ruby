module Orchestrate
  class EventSource
    def initialize(kv_item)
      @kv_item = kv_item
      @types = {}
    end

    def [](event_type)
      @types[event_type.to_s] ||= EventType.new(@kv_item, event_type)
    end
  end

  class EventType
    attr_reader :kv_item
    attr_reader :type
    def initialize(kv_item, event_type)
      @kv_item = kv_item
      @type = event_type.to_s
    end

    def <<(body)
      Range.new(self).push(body)
    end
    alias :push :<<

    def [](bounds)
      Range.new(self, bounds)
    end

    class Range
      attr_reader :type
      attr_reader :type_name
      attr_reader :kv_item
      def initialize(type, bounds=nil)
        @type = type
        @type_name = type.type
        @kv_item = type.kv_item
        if bounds.kind_of?(Hash)
          @bounds = bounds
        else
          @bounds = {limit: 100}
          @bounds[:start] = bounds
        end
      end

      def perform(api_method, *args)
        kv_item.perform(api_method, type_name, *args)
      end

      def <<(body)
        response = perform(:post_event, body, @bounds[:start])
        Event.from_bodyless_response(type, body, response)
      end
      alias :push :<<

      def [](ordinal)
        begin
          response = perform(:get_event, @bounds[:start], ordinal)
          Event.new(type, response)
        rescue API::NotFound
          nil
        end
      end
    end
  end
end
