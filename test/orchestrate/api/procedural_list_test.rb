require "test_helper"

class ProceduralListTest < MiniTest::Unit::TestCase

  include Test

  # methods: list, delete_collection
  #
  def test_procedural_list

    test_root_name = 'procedural-list'
    name = 'test_models'
    sleep 1

    # setup
    output_message(test_root_name, "Test setup")

    VCR.use_cassette("#{test_root_name}/setup") do

      (1..3).each do |num|
        response = client.purge_key(collection: name, key: "instance_#{num}")
        assert response.success? == true
        assert response.header.code == 204

        jdoc = { 'Name' => "test_#{num}", 'DESC' => "desc_#{num}"}.to_json
        response = client.put_key(collection: name, key: "instance_#{num}", json: jdoc)
        assert response.success? == true
        assert response.header.code == 201
      end
    end

    # test
    output_message(test_root_name, "TEST START")

    VCR.use_cassette("#{test_root_name}/synopsis") do

      response = client.list(collection: name)
      assert response.body.count == 3
      assert response.body.to_hash['results'].first['value']['Name'] == 'test_1'
      assert response.body.to_hash['results'].last['value']['Name'] == 'test_3'

      qparams = "?limit=2"
      response = client.list(collection: name, path: qparams)
      assert response.body.count == 2
      assert response.body.to_hash['results'].last['value']['Name'] == 'test_2'

      max = 100
      qparams = "?limit=#{max}&startKey=instance_2"
      response = client.list(collection: name, path: qparams)
      assert response.body.count == 2

      qparams = "?limit=#{max}&startKey=instance_3"
      response = client.list(collection: name, path: qparams)
      assert response.body.count == 1

      qparams = "?limit=1&afterKey=instance_1"
      response = client.list(collection: name, path: qparams)
      assert response.body.count == 1

      qparams = "?limit=#{max}&afterKey=instance_2"
      response = client.list(collection: name, path: qparams)
      assert response.body.count == 1

      qparams = "?limit=#{max}&afterKey=instance_3"
      response = client.list(collection: name, path: qparams)
      assert response.body.count == 0

      response = client.delete_collection(collection: name)
      assert response.success? == true
      assert response.header.code == 204
    end

    # cleanup
    output_message(test_root_name, "Test cleanup")

    VCR.use_cassette("#{test_root_name}/cleanup") do
      (1..3).each do |num|
        response = client.purge_key(collection: name, key: "instance_#{num}")
        assert response.success? == true
        assert response.header.code == 204
      end
    end
  end
end
