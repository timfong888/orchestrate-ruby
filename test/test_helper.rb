require "minitest/autorun"
require "vcr"

require "orchestrate-api"

# Configure Orchestrate API Client -------------------------------------------

module Test
  def client
    @@client ||= Orchestrate::API::Wrapper.new File.join(File.dirname(__FILE__), "lib", "orch_config-demo.json")
  end
end

# Configure VCR --------------------------------------------------------------

VCR.configure do |c|
  # c.allow_http_connections_when_no_cassette = true
  c.hook_into :webmock
  c.cassette_library_dir = File.join(File.dirname(__FILE__), "fixtures", "vcr_cassettes")
  default_cassette_options = { :record => :all }
end

# Test Helpers ---------------------------------------------------------------

def output_message(name, msg = nil)
  msg = "START TEST" if msg.blank?
  puts "\n======= #{msg}: #{name} ======="
end
