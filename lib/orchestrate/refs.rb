module Orchestrate
  class RefList

    def initialize(key_value)
      @key_value = key_value
    end

    def [](ref_id)
      response = @key_value.perform(:get, ref_id)
      Ref.new(@key_value.collection, @key_value.key, response)
    end
  end

  class Ref < KeyValue
    def archival?
      true
    end
  end
end
