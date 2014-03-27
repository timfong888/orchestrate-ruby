  require 'rubygems'
  require 'minitest/autorun'
  require 'vcr'

  require 'orchestrate-api'

  require './tests/procedural-event'
  require './tests/procedural-graph'
  require './tests/procedural-key_value'
  require './tests/procedural-list'
  require './tests/procedural-ref'
  require './tests/procedural-search'

  module Test

    def self.output_message(name, msg = nil)
      msg = "START TEST" if msg.blank?
      puts "\n======= #{msg}: #{name} ======="
    end

    VCR.configure do |c|
      # c.allow_http_connections_when_no_cassette = true
      c.hook_into :webmock
      c.cassette_library_dir = 'fixtures/vcr_cassettes'
      default_cassette_options = { :record => :all }
    end

    class VCRTest_OrchestrateAPI_Event < MiniTest::Unit::TestCase
      include Test::ProceduralEvent
    end

    class VCRTest_OrchestrateAPI_Graph < MiniTest::Unit::TestCase
      include Test::ProceduralGraph
    end

    class VCRTest_OrchestrateAPI_KeyValue < MiniTest::Unit::TestCase
      include Test::ProceduralKeyValue
    end

    class VCRTest_OrchestrateAPI_List < MiniTest::Unit::TestCase
      include Test::ProceduralList
    end

    class VCRTest_OrchestrateAPI_Ref < MiniTest::Unit::TestCase
      include Test::ProceduralRef
    end

    class VCRTest_OrchestrateAPI_Search < MiniTest::Unit::TestCase
      include Test::ProceduralSearch
    end

  end

