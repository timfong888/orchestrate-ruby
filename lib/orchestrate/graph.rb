module Orchestrate
  class Graph

    def initialize(kv_item)
      @kv_item = kv_item
      @types = {}
    end

    def [](relation_type)
      @types[relation_type.to_s] || RelationStem.new(@kv_item, relation_type.to_s)
    end

    class RelationStem
      attr_accessor :kv_item
      attr_accessor :type

      def initialize(kv_item, type_name)
        @kv_item = kv_item
        @client = kv_item.collection.app.client
        @type = type_name
      end

      def <<(other_item_or_collection_name, other_key=nil)
        coll, key = get_collection_and_key(kv_item, nil)
        other_collection, other_key = get_collection_and_key(other_item_or_collection_name, other_key)
        @client.put_relation(coll, key, type, other_collection, other_key)
      end
      alias :push :<<

      def delete(other_item_or_collection_name, other_key=nil)
        coll, key = get_collection_and_key(kv_item, nil)
        other_collection, other_key = get_collection_and_key(other_item_or_collection_name, other_key)
        @client.delete_relation(coll, key, type, other_collection, other_key)
      end

      include Enumerable
      def each(&block)
        return enum_for(:each) unless block
        response = @client.get_relations(kv_item.collection_name, kv_item.key, type)
        raise ResultsNotReady.new if @client.http.parallel_manager
        response.results.each do |listing|
          other_collection = listing['path']['collection']
          yield KeyValue.new(kv_item.collection.app[other_collection], listing, response.request_time)
        end
      end

      private
      def get_collection_and_key(item_or_collection, key)
        if item_or_collection.kind_of?(KeyValue)
          collection = item_or_collection.collection_name
          key = item_or_collection.key
        else
          collection = item_or_collection
        end
        [collection, key]
      end
    end

  end
end

