module Orchestrate::API

  # ==== *Procedural* interface methods (optional).
  #
  # This file serves as useful documentation for the <b>Orchestrate.io REST</b> *API*.
  # Each method illustrates an example for the corresponding HTTP request,
  # and documents the required keys for the send_request argument hash.
  #
  module Procedural

    # -------------------------------------------------------------------------
    #  collection

    #  * required: { collection }
    #  * optional: { path }, which should have been called <em>params</em>
    #
    def list(args)
      send_request :get, args
    end

    #  * required: { collection, query }
    #
    def search(args)
      # TODO
      # don't clobber anything in existing path parameter
      send_request :get, args.merge(path: "?query=#{args[:query].gsub(/\s/, '%20')}")
    end

    #  * required: { collection }
    #
    def delete_collection(args)
      send_request :delete, args.merge(path: "?force=true")
    end

    # -------------------------------------------------------------------------
    #  collection/key

    #  * required: { collection, key }
    #
    def get_key(args)
      send_request :get, args
    end

    #  * required: { collection, key, json }
    #
    def put_key(args)
      send_request :put, args
    end

    #  * required: { collection, key }
    #
    def delete_key(args)
      send_request :delete, args
    end

    #  * required: { collection, key }
    #
    def purge_key(args)
      send_request :delete, args.merge(path: "?purge=true")
    end

    # -------------------------------------------------------------------------
    #  collection/key/ref

    #   * required: { collection, key, ref }
    #
    def get_by_ref(args)
      send_request :get, args
    end

    #  * required: { collection, key, json, ref }
    #
    def put_key_if_match(args)
      send_request :put, args
    end

    # * required: { collection, key, json }
    #
    def put_key_if_none_match(args)
      send_request :put, args.merge(ref: '"*"')
    end

    # -------------------------------------------------------------------------
    #  collection/key/events

    #  * required: { collection, key, event_type }
    #  * optional: { timestamp }, where timestamp = { :start => start, :end => end }
    #
    def get_events(args)
      send_request :get, args
    end

    #  * required: { collection, key, event_type, json }
    #  * optional: { timestamp }, where timestamp is a scalar value
    #
    def put_event(args)
      send_request :put, args
    end

    # -------------------------------------------------------------------------
    #  collection/key/graph

    #  * required: { collection, key, kind }
    #
    def get_graph(args)
      send_request :get, args
    end

    #  * required: { collection, key, kind, to_collection, to_key }
    #
    def put_graph(args)
      send_request :put, args
    end

    #  * required: { collection, key, kind, to_collection, to_key }
    #
    def delete_graph(args)
      send_request :delete, args.merge(path: "?purge=true")
    end

  end
end
