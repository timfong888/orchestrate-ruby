require_relative "../test_helper"

class ProceduralKeyValueTest < MiniTest::Unit::TestCase

  include Test

  # methods: put_key, get_key, delete_key
  #
  def test_procedural_key_value

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
      response = client.put_key(collection: name, key: key, json: jdoc)
      assert response.success? == true
      assert response.header.code == 201

      response = client.get_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 200

      jdoc = { 'Name' => 'test_1b', 'DESC' => 'desc_1b'}.to_json
      response = client.put_key(collection: name, key: key, json: jdoc)
      assert response.success? == true
      assert response.header.code == 201

      response = client.get_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 200
      assert response.body.to_hash['Name'] == 'test_1b'

      response = client.delete_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 204

      response = client.get_key(collection: name, key: key)
      assert response.success? == false
      assert response.header.code == 404
    end

    # cleanup
    output_message(test_root_name, "Test cleanup")

    VCR.use_cassette("#{test_root_name}/cleanup") do
      response = client.purge_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 204
    end
  end
end
