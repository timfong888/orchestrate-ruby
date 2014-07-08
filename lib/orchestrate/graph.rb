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
        if other_item_or_collection_name.kind_of?(KeyValue)
          other_collection = other_item_or_collection_name.collection_name
          other_key = other_item_or_collection_name.key
        else
          other_collection = other_item_or_collection_name
        end
        @client.put_relation(kv_item.collection_name, kv_item.key, type, other_collection, other_key)
      end
      alias :push :<<
    end

  end
end

