module Orchestrate
  class RefList

    attr_accessor :key_value

    def initialize(key_value)
      @key_value = key_value
    end

    def [](ref_id)
      response = @key_value.perform(:get, ref_id)
      Ref.new(@key_value.collection, @key_value.key, response)
    end

    # @!group Ref Enumeration

    include Enumerable

    def each(&block)
      Fetcher.new(self).each(&block)
    end

    def lazy
      Fetcher.new(self).lazy
    end

    # @!endgroup
    class Fetcher
      attr_accessor :key_value
      attr_accessor :params

      def initialize(reflist)
        @key_value = reflist.key_value
        @params = { limit: 100 }
      end

      include Enumerable

      def each
        @response ||= key_value.perform(:list_refs, @params)
        return enum_for(:each) unless block_given?
        raise ResultsNotReady.new if key_value.collection.app.inside_parallel?
        loop do
          @response.results.each do |doc|
            yield Ref.from_listing(key_value.collection, doc, @response)
          end
          break unless @response.next_link
          @response = @response.next_results
        end
        @response = nil
      end

      def lazy
        return each.lazy if key_value.collection.app.inside_parallel?
        super
      end

    end
  end

  class Ref < KeyValue
    def archival?
      true
    end
  end
end
