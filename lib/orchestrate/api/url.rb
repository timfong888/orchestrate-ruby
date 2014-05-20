module Orchestrate::API

  # Builds the URL for each HTTP request to the orchestrate.io api.
  #
  class URL
    attr_reader :path
    def initialize(method, base_url, args)
      # Support args[:path] for backward compatibility (until 1.0.0)
      args[:params] = args[:path] if args[:params].blank?

      @path = "/v0/#{args[:collection]}"
      @path << Key.new(args[:key]).path
      @path << Ref.new(method, args[:ref]).path
      @path << Event.new(method, args[:event_type], args[:timestamp]).path
      @path << Graph.new(method, args[:kind], args[:to_collection], args[:to_key]).path
      @path << Params.new(args[:params]).path
    end

    class Key
      attr_reader :path
      def initialize(key)
        @path = key.blank? ? "" : "/#{key}"
      end
    end

    class Ref
      attr_reader :path
      def initialize(method, ref)
        @path = (method == :get && ref.present?) ? "/refs/#{ref.gsub(/"/, '')}" : ""
      end
    end

    class Event
      def initialize(method, event_type, timestamp)
        @method, @event_type, @timestamp = method, event_type, timestamp
      end

      def path
        base_path + timestamp_param_string
      end

      private
        def base_path
          @event_type.blank? ? "" : "/events/#{@event_type}"
        end

        # TODO: convert time objects to integers
        def timestamp_param_string
          return "" if @timestamp.blank?
          return "?timestamp=#{@timestamp}" if (@timestamp.is_a?(Integer) || @timestamp.is_a?(String))
          "?start=#{@timestamp[:start]}&end=#{@timestamp[:end]}"
        end
    end

    class Graph
      def initialize(method, kind, to_collection, to_key)
        @method, @kind = method, kind
        @to_collection, @to_key = to_collection, to_key
      end

      def path
        return "" if @kind.blank?
        return "/relations/#{@kind}" if @method == :get
        "/relation/#{@kind}/#{@to_collection}/#{@to_key}"
      end
    end

    class Params
      attr_reader :path
      def initialize(param_string)
        @path = param_string.blank? ? "" : param_string
      end
    end

  end
end

