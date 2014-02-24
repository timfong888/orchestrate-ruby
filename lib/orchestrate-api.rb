module Orchestrate

=begin rdoc
  ==== orchestrate-api

  Ruby gem <tt>orchestrate-api</tt> provides an
  interface to the <b>Orchestrate.io</b> *API*.

  The <b>Wrapper[API/Wrapper.html]</b> class is used to setup the client and make HTTP requests.
=end

  module API

    # require "active_support/core_ext"

    require "orchestrate_api/procedural"
    require "orchestrate_api/wrapper"
    require "orchestrate_api/request"
    require "orchestrate_api/response"

  end
end
