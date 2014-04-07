require_relative "../test_helper"

class ProceduralEventTest < MiniTest::Unit::TestCase

  include Test

  # methods: put_event, get_events, purge_key
  #
  def test_procedural_event

    test_root_name = 'procedural-event'
    name = 'test_models'
    key = 'instance_1'
    sleep 1

    # setup
    output_message(test_root_name, "Test setup")

    VCR.use_cassette("#{test_root_name}/setup") do
      response = client.purge_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 204

      jdoc = { 'Name' => 'test_1a', 'DESC' => 'desc_1a'}.to_json
      response = client.put_key(collection: name, key: key, json: jdoc)
      assert response.success? == true
      assert response.header.code == 201
    end

    # test
    output_message(test_root_name, "TEST START")

    VCR.use_cassette("#{test_root_name}/synopsis") do

      response = client.get_events(collection: name, key: key, event_type: 'test_event')
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 0

      jdoc = { name: 'event_1', contents: 'stuff_1' }.to_json
      response =
        client.put_event(collection: name, key: key, event_type: 'test_event', json: jdoc)
      assert response.success?
      assert response.header.code == 204

      jdoc = { name: 'event_2', contents: 'stuff_2' }.to_json
      response =
        client.put_event(collection: name, key: key, event_type: 'test_event', json: jdoc)
      assert response.success?
      assert response.header.code == 204

      response = client.get_events(collection: name, key: key, event_type: 'test_event')
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 2

      t1 = 1395441226763  # get_timestamp() from approx 3:30pm PDT on 03-21-2014
      jdoc = { name: 'name_3', contents: 'stuff_3' }.to_json
      response = client.put_event(collection: name, key: key, event_type: 'test_event',
                                  timestamp: t1, json: jdoc)
      assert response.success?
      assert response.header.code == 204

      t2 = t1 + 100
      jdoc = { name: 'name_4', contents: 'stuff_4' }.to_json
      response = client.put_event(collection: name, key: key, event_type: 'test_event',
                                  timestamp: t2, json: jdoc)
      assert response.success?
      assert response.header.code == 204

      response = client.get_events(collection: name, key: key, event_type: 'test_event')
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 4

      t1_t2 = { :start => t1, :end => t2 + 1 }

      response = client.get_events(collection: name, key: key, event_type: 'test_event',
                                   timestamp: t1_t2)
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 2

      response = client.purge_key(collection: name, key: key)
      assert response.success?
      assert response.header.code == 204

      response = client.get_events(collection: name, key: key, event_type: 'test_event')
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 0
    end

    # # cleanup
    # output_message(test_root_name, "Test cleanup")

    # VCR.use_cassette("#{test_root_name}/cleanup") do
    #   response = client.purge_key(collection: name, key: key)
    #   assert response.success? == true
    #   assert response.header.code == 204
    # end
  end
end
