require "test_helper"

class ProceduralTest < MiniTest::Unit::TestCase

  def setup
    @client = Orchestrate::Client.new
  end

  # methods: put_event, get_events, purge_key
  #
  def test_event

    test_root_name = 'procedural-event'
    name = 'test_models'
    key = 'instance_1'
    sleep 1

    # setup
    output_message(test_root_name, "Test setup")

    VCR.use_cassette("#{test_root_name}/setup") do
      response = @client.purge_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 204

      jdoc = { 'Name' => 'test_1a', 'DESC' => 'desc_1a'}.to_json
      response = @client.put_key(collection: name, key: key, json: jdoc)
      assert response.success? == true
      assert response.header.code == 201
    end

    # test
    output_message(test_root_name, "TEST START")

    VCR.use_cassette("#{test_root_name}/synopsis") do

      response = @client.get_events(collection: name, key: key, event_type: 'test_event')
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 0

      jdoc = { name: 'event_1', contents: 'stuff_1' }.to_json
      response =
        @client.put_event(collection: name, key: key, event_type: 'test_event', json: jdoc)
      assert response.success?
      assert response.header.code == 204

      jdoc = { name: 'event_2', contents: 'stuff_2' }.to_json
      response =
        @client.put_event(collection: name, key: key, event_type: 'test_event', json: jdoc)
      assert response.success?
      assert response.header.code == 204

      response = @client.get_events(collection: name, key: key, event_type: 'test_event')
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 2

      t1 = 1395441226763  # get_timestamp() from approx 3:30pm PDT on 03-21-2014
      jdoc = { name: 'name_3', contents: 'stuff_3' }.to_json
      response = @client.put_event(collection: name, key: key, event_type: 'test_event',
                                  timestamp: t1, json: jdoc)
      assert response.success?
      assert response.header.code == 204

      t2 = t1 + 100
      jdoc = { name: 'name_4', contents: 'stuff_4' }.to_json
      response = @client.put_event(collection: name, key: key, event_type: 'test_event',
                                  timestamp: t2, json: jdoc)
      assert response.success?
      assert response.header.code == 204

      response = @client.get_events(collection: name, key: key, event_type: 'test_event')
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 4

      t1_t2 = { :start => t1, :end => t2 + 1 }

      response = @client.get_events(collection: name, key: key, event_type: 'test_event',
                                   timestamp: t1_t2)
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 2

      response = @client.purge_key(collection: name, key: key)
      assert response.success?
      assert response.header.code == 204

      response = @client.get_events(collection: name, key: key, event_type: 'test_event')
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 0
    end

    # # cleanup
    # output_message(test_root_name, "Test cleanup")

    # VCR.use_cassette("#{test_root_name}/cleanup") do
    #   response = @client.purge_key(collection: name, key: key)
    #   assert response.success? == true
    #   assert response.header.code == 204
    # end
  end

  # methods: put_graph, get_graph, delete_graph
  #
  def test_graph

    test_root_name = 'procedural-graph'
    name = 'test_models'
    sleep 1

    # setup
    output_message(test_root_name, "Test setup")

    VCR.use_cassette("#{test_root_name}/setup") do

      response = @client.purge_key(collection: name, key: 'instance_1')
      assert response.success? == true
      assert response.header.code == 204

      jdoc = { 'Name' => 'test_1', 'DESC' => 'desc_1'}.to_json
      response = @client.put_key(collection: name, key: 'instance_1', json: jdoc)
      assert response.success? == true
      assert response.header.code == 201

      jdoc = { 'Name' => 'test_101', 'DESC' => 'desc_101'}.to_json
      response = @client.put_key(collection: name, key: 'instance_101', json: jdoc)
      assert response.success? == true
      assert response.header.code == 201

      jdoc = { 'Name' => 'test_102', 'DESC' => 'desc_102'}.to_json
      response = @client.put_key(collection: name, key: 'instance_102', json: jdoc)
      assert response.success? == true
      assert response.header.code == 201
    end

    # test
    output_message(test_root_name, "TEST START")

    VCR.use_cassette("#{test_root_name}/synopsis") do

      response =
        @client.get_graph(collection: name, key: 'instance_1', kind: 'add_100_or_more')
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 0

      response =
        @client.put_graph(collection: name, key: 'instance_1', kind: 'add_100_or_more',
                         to_collection: name, to_key: 'instance_101')
      assert response.success?
      assert response.header.code == 204

      response =
        @client.put_graph(collection: name, key: 'instance_1', kind: 'add_100_or_more',
                         to_collection: name, to_key: 'instance_102')
      assert response.success?
      assert response.header.code == 204

      response =
        @client.get_graph(collection: name, key: 'instance_1', kind: 'add_100_or_more')
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 2

      response =
        @client.delete_graph(collection: name, key: 'instance_1', kind: 'add_100_or_more',
                            to_collection: name, to_key: 'instance_102')
      assert response.success?
      assert response.header.code == 204

      response =
        @client.get_graph(collection: name, key: 'instance_1', kind: 'add_100_or_more')
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 1

      response = @client.purge_key(collection: name, key: 'instance_1')
      assert response.success? == true
      assert response.header.code == 204

      response =
        @client.get_graph(collection: name, key: 'instance_1', kind: 'add_100_or_more')
      assert response.success? == false
      assert response.header.code == 404
    end

    # cleanup
    output_message(test_root_name, "Test cleanup")

    VCR.use_cassette("#{test_root_name}/cleanup") do
      [1, 101, 102].each do |num|
        response = @client.purge_key(collection: name, key: "instance_#{num}")
        assert response.success? == true
        assert response.header.code == 204
      end
    end
  end

  # methods: put_key, get_key, delete_key
  #
  def test_key_value

    test_root_name = 'procedural-key_value'
    name = 'test_models'
    key = 'instance_1'
    sleep 1

    # # setup
    # output_message(test_root_name, "Test setup")
    # VCR.use_cassette("#{test_root_name}/setup") do
    # end

    # test
    output_message(test_root_name, "TEST START")

    VCR.use_cassette("#{test_root_name}/synopsis") do

      jdoc = { 'Name' => 'test_1a', 'DESC' => 'desc_1a'}.to_json
      response = @client.put_key(collection: name, key: key, json: jdoc)
      assert response.success? == true
      assert response.header.code == 201

      response = @client.get_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 200

      jdoc = { 'Name' => 'test_1b', 'DESC' => 'desc_1b'}.to_json
      response = @client.put_key(collection: name, key: key, json: jdoc)
      assert response.success? == true
      assert response.header.code == 201

      response = @client.get_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 200
      assert response.body.to_hash['Name'] == 'test_1b'

      response = @client.delete_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 204

      response = @client.get_key(collection: name, key: key)
      assert response.success? == false
      assert response.header.code == 404
    end

    # cleanup
    output_message(test_root_name, "Test cleanup")

    VCR.use_cassette("#{test_root_name}/cleanup") do
      response = @client.purge_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 204
    end
  end

  # methods: list, delete_collection
  #
  def test_list

    test_root_name = 'procedural-list'
    name = 'test_models'
    sleep 1

    # setup
    output_message(test_root_name, "Test setup")

    VCR.use_cassette("#{test_root_name}/setup") do

      (1..3).each do |num|
        response = @client.purge_key(collection: name, key: "instance_#{num}")
        assert response.success? == true
        assert response.header.code == 204

        jdoc = { 'Name' => "test_#{num}", 'DESC' => "desc_#{num}"}.to_json
        response = @client.put_key(collection: name, key: "instance_#{num}", json: jdoc)
        assert response.success? == true
        assert response.header.code == 201
      end
    end

    # test
    output_message(test_root_name, "TEST START")

    VCR.use_cassette("#{test_root_name}/synopsis") do

      response = @client.list(collection: name)
      assert response.body.count == 3
      assert response.body.to_hash['results'].first['value']['Name'] == 'test_1'
      assert response.body.to_hash['results'].last['value']['Name'] == 'test_3'

      qparams = "?limit=2"
      response = @client.list(collection: name, path: qparams)
      assert response.body.count == 2
      assert response.body.to_hash['results'].last['value']['Name'] == 'test_2'

      max = 100
      qparams = "?limit=#{max}&startKey=instance_2"
      response = @client.list(collection: name, path: qparams)
      assert response.body.count == 2

      qparams = "?limit=#{max}&startKey=instance_3"
      response = @client.list(collection: name, path: qparams)
      assert response.body.count == 1

      qparams = "?limit=1&afterKey=instance_1"
      response = @client.list(collection: name, path: qparams)
      assert response.body.count == 1

      qparams = "?limit=#{max}&afterKey=instance_2"
      response = @client.list(collection: name, path: qparams)
      assert response.body.count == 1

      qparams = "?limit=#{max}&afterKey=instance_3"
      response = @client.list(collection: name, path: qparams)
      assert response.body.count == 0

      response = @client.delete_collection(collection: name)
      assert response.success? == true
      assert response.header.code == 204
    end

    # cleanup
    output_message(test_root_name, "Test cleanup")

    VCR.use_cassette("#{test_root_name}/cleanup") do
      (1..3).each do |num|
        response = @client.purge_key(collection: name, key: "instance_#{num}")
        assert response.success? == true
        assert response.header.code == 204
      end
    end
  end

  # methods: put_key_if_match, put_key_if_none_match, get_by_ref, purge_key
  #
  def test_ref

    test_root_name = 'procedural-ref'
    name = 'test_models'
    key = 'instance_1'

    # setup
    sleep 1
    output_message(test_root_name, "Test setup")

    VCR.use_cassette("#{test_root_name}/setup") do
      response = @client.delete_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 204
    end

    # test
    output_message(test_root_name, "TEST START")

    VCR.use_cassette("#{test_root_name}/synopsis") do

      jdoc = { 'Name' => 'test_1a', 'DESC' => 'desc_1a'}.to_json
      response = @client.put_key_if_none_match(collection: name, key: key, json: jdoc)
      assert response.success? == true
      assert response.header.code == 201

      etag_1a = response.header.etag

      jdoc = { 'Name' => 'test_1b', 'DESC' => 'desc_1b'}.to_json
      response = @client.put_key_if_none_match(collection: name, key: key, json: jdoc)
      assert response.success? == false
      assert response.header.code == 412

      jdoc = { 'Name' => 'test_1c', 'DESC' => 'desc_1c'}.to_json
      response =
        @client.put_key_if_match(collection: name, key: key, ref: etag_1a, json: jdoc)
      assert response.success? == true
      assert response.header.code == 201

      jdoc = { 'Name' => 'test_1d', 'DESC' => 'desc_1d'}.to_json
      response =
        @client.put_key_if_match(collection: name, key: key, ref: 'bogus', json: jdoc)
      assert response.success? == false
      assert response.header.code == 400

      response = @client.get_by_ref(collection: name, key: key, ref: etag_1a)
      assert response.success? == true
      assert response.header.code == 200
      assert response.body.to_hash['Name'] == 'test_1a'

      response = @client.get_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 200
      assert response.body.to_hash['Name'] == 'test_1c'

      response = @client.delete_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 204

      response = @client.get_key(collection: name, key: key)
      assert response.success? == false
      assert response.header.code == 404

      response = @client.get_by_ref(collection: name, key: key, ref: etag_1a)
      assert response.success? == true
      assert response.header.code == 200
      assert response.body.to_hash['Name'] == 'test_1a'

      response = @client.purge_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 204

      response = @client.get_by_ref(collection: name, key: key, ref: etag_1a)
      assert response.success? == false
      assert response.header.code == 404

    end

    # # cleanup
    # output_message(test_root_name, "Test cleanup")
    # VCR.use_cassette("#{test_root_name}/cleanup") do
    # end
  end

  # methods: list, delete_collection
  #
  def test_search

    test_root_name = 'procedural-search'
    name = 'test_models'
    key = 'instance_1'

    # setup
    output_message(test_root_name, "Test setup")

    VCR.use_cassette("#{test_root_name}/setup") do
      (1..3).each do |num|
        jdoc = { 'Name' => "test_#{num}", 'DESC' => "desc_#{num}"}.to_json
        response = @client.put_key(collection: name, key: "instance_#{num}", json: jdoc)
        assert response.success? == true
        assert response.header.code == 201
      end
      sleep 1
    end

    # test
    output_message(test_root_name, "TEST START")

    VCR.use_cassette("#{test_root_name}/synopsis") do

      response = @client.search(collection: name, query: "*")
      assert response.body.count == 3

      response = @client.search(collection: name, query: "*&offset=1")
      assert response.body.count == 2

      response = @client.search(collection: name, query: "*&offset=3")
      assert response.body.count == 0

      response = @client.search(collection: name, query: "Name:TEsT_2")
      assert response.body.count == 1

      response = @client.search(collection: name, query: "DESC:desc_*")
      assert response.body.count == 3
    end

    # cleanup
    output_message(test_root_name, "Test cleanup")

    VCR.use_cassette("#{test_root_name}/cleanup") do
      (1..3).each do |num|
        response = @client.purge_key(collection: name, key: "instance_#{num}")
        assert response.success? == true
        assert response.header.code == 204
      end

      response = @client.delete_collection(collection: name)
      assert response.success? == true
      assert response.header.code == 204
    end
  end

end
