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

    def perform(api_method, *args)
      kv_item.perform(api_method, type, *args)
    end

    def <<(body)
      Range.new(self).push(body)
    end
    alias :push :<<

    def [](bounds)
      Range.new(self, bounds)
    end

    include Enumerable

    def each(&block)
      Range.new(self).each(&block)
    end

    def lazy
      Range.new(self).lazy
    end

    def take(count)
      Range.new(self).take(count)
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
          @bounds[:start] = bounds if bounds
        end
      end

      def perform(api_method, *args)
        type.perform(api_method, *args)
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

      include Enumerable

      def each(&block)
        @response = perform(:list_events, @bounds)
        return enum_for(:each) unless block_given?
        raise ResultsNotReady.new if type.kv_item.collection.app.inside_parallel?
        loop do
          @response.results.each do |listing|
            yield Event.from_listing(type, listing, @response)
          end
          break unless @response.next_link
          @response = @response.next_results
        end
        @response = nil
      end

      def lazy
        return each.lazy if type.kv_item.collection.app.inside_parallel?
        super
      end

      def take(count)
        count = 1 if count < 1
        @bounds[:limit] = count > 100 ? 100 : count
        super(count)
      end
    end
  end
end
