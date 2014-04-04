tests = File.expand_path('..', __FILE__)
$LOAD_PATH.unshift(tests) unless $LOAD_PATH.include?(tests)

  require 'orchestrate-api'

  require 'rubygems'
  require 'minitest/autorun'

  require 'vcr'

  require 'tests/procedural-event'
  require 'tests/procedural-graph'
  require 'tests/procedural-key_value'
  require 'tests/procedural-list'
  require 'tests/procedural-ref'
  require 'tests/procedural-search'

  module Test

    def self.output_message(name, msg = nil)
      msg = "START TEST" if msg.nil? || msg == ''
      puts "\n======= #{msg}: #{name} ======="
    end

    def self.client
      @@client ||=
        Orchestrate::API::Wrapper.new File.join(File.dirname(__FILE__), "lib", "orch_config-demo.json")
    end

    VCR.configure do |c|
      # c.allow_http_connections_when_no_cassette = true
      c.hook_into :webmock
      c.cassette_library_dir = File.join(File.dirname(__FILE__), "fixtures", "vcr_cassettes")
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

