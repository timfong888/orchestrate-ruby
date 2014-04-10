require "test_helper"

class ProceduralGraphTest < MiniTest::Unit::TestCase

  include Test

  # methods: put_graph, get_graph, delete_graph
  #
  def test_procedural_graph

    test_root_name = 'procedural-graph'
    name = 'test_models'
    sleep 1

    # setup
    output_message(test_root_name, "Test setup")

    VCR.use_cassette("#{test_root_name}/setup") do

      response = client.purge_key(collection: name, key: 'instance_1')
      assert response.success? == true
      assert response.header.code == 204

      jdoc = { 'Name' => 'test_1', 'DESC' => 'desc_1'}.to_json
      response = client.put_key(collection: name, key: 'instance_1', json: jdoc)
      assert response.success? == true
      assert response.header.code == 201

      jdoc = { 'Name' => 'test_101', 'DESC' => 'desc_101'}.to_json
      response = client.put_key(collection: name, key: 'instance_101', json: jdoc)
      assert response.success? == true
      assert response.header.code == 201

      jdoc = { 'Name' => 'test_102', 'DESC' => 'desc_102'}.to_json
      response = client.put_key(collection: name, key: 'instance_102', json: jdoc)
      assert response.success? == true
      assert response.header.code == 201
    end

    # test
    output_message(test_root_name, "TEST START")

    VCR.use_cassette("#{test_root_name}/synopsis") do

      response =
        client.get_graph(collection: name, key: 'instance_1', kind: 'add_100_or_more')
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 0

      response =
        client.put_graph(collection: name, key: 'instance_1', kind: 'add_100_or_more',
                         to_collection: name, to_key: 'instance_101')
      assert response.success?
      assert response.header.code == 204

      response =
        client.put_graph(collection: name, key: 'instance_1', kind: 'add_100_or_more',
                         to_collection: name, to_key: 'instance_102')
      assert response.success?
      assert response.header.code == 204

      response =
        client.get_graph(collection: name, key: 'instance_1', kind: 'add_100_or_more')
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 2

      response =
        client.delete_graph(collection: name, key: 'instance_1', kind: 'add_100_or_more',
                            to_collection: name, to_key: 'instance_102')
      assert response.success?
      assert response.header.code == 204

      response =
        client.get_graph(collection: name, key: 'instance_1', kind: 'add_100_or_more')
      assert response.success?
      assert response.header.code == 200
      assert response.body.count == 1

      response = client.purge_key(collection: name, key: 'instance_1')
      assert response.success? == true
      assert response.header.code == 204

      response =
        client.get_graph(collection: name, key: 'instance_1', kind: 'add_100_or_more')
      assert response.success? == false
      assert response.header.code == 404
    end

    # cleanup
    output_message(test_root_name, "Test cleanup")

    VCR.use_cassette("#{test_root_name}/cleanup") do
      [1, 101, 102].each do |num|
        response = client.purge_key(collection: name, key: "instance_#{num}")
        assert response.success? == true
        assert response.header.code == 204
      end
    end
  end
end
