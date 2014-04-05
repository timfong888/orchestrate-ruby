module Orchestrate

=begin rdoc
  ==== orchestrate-api

  Ruby gem <tt>orchestrate-api</tt> provides an
  interface to the <b>Orchestrate.io</b> *API*.

  The <b>Wrapper[API/Wrapper.html]</b> class is used to setup the client and make HTTP requests.
=end

  module API

    require "orchestrate/api/procedural"
    require "orchestrate/api/wrapper"
    require "orchestrate/api/request"
    require "orchestrate/api/response"

  end
end
