require "test_helper"

class ProceduralRefTest < MiniTest::Unit::TestCase

  include Test

  # methods: put_key_if_match, put_key_if_none_match, get_by_ref, purge_key
  #
  def test_procedural_ref

    test_root_name = 'procedural-ref'
    name = 'test_models'
    key = 'instance_1'

    # setup
    sleep 1
    output_message(test_root_name, "Test setup")

    VCR.use_cassette("#{test_root_name}/setup") do
      response = client.delete_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 204
    end

    # test
    output_message(test_root_name, "TEST START")

    VCR.use_cassette("#{test_root_name}/synopsis") do

      jdoc = { 'Name' => 'test_1a', 'DESC' => 'desc_1a'}.to_json
      response = client.put_key_if_none_match(collection: name, key: key, json: jdoc)
      assert response.success? == true
      assert response.header.code == 201

      etag_1a = response.header.etag

      jdoc = { 'Name' => 'test_1b', 'DESC' => 'desc_1b'}.to_json
      response = client.put_key_if_none_match(collection: name, key: key, json: jdoc)
      assert response.success? == false
      assert response.header.code == 412

      jdoc = { 'Name' => 'test_1c', 'DESC' => 'desc_1c'}.to_json
      response =
        client.put_key_if_match(collection: name, key: key, ref: etag_1a, json: jdoc)
      assert response.success? == true
      assert response.header.code == 201

      jdoc = { 'Name' => 'test_1d', 'DESC' => 'desc_1d'}.to_json
      response =
        client.put_key_if_match(collection: name, key: key, ref: 'bogus', json: jdoc)
      assert response.success? == false
      assert response.header.code == 400

      response = client.get_by_ref(collection: name, key: key, ref: etag_1a)
      assert response.success? == true
      assert response.header.code == 200
      assert response.body.to_hash['Name'] == 'test_1a'

      response = client.get_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 200
      assert response.body.to_hash['Name'] == 'test_1c'

      response = client.delete_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 204

      response = client.get_key(collection: name, key: key)
      assert response.success? == false
      assert response.header.code == 404

      response = client.get_by_ref(collection: name, key: key, ref: etag_1a)
      assert response.success? == true
      assert response.header.code == 200
      assert response.body.to_hash['Name'] == 'test_1a'

      response = client.purge_key(collection: name, key: key)
      assert response.success? == true
      assert response.header.code == 204

      response = client.get_by_ref(collection: name, key: key, ref: etag_1a)
      assert response.success? == false
      assert response.header.code == 404

    end

    # # cleanup
    # output_message(test_root_name, "Test cleanup")
    # VCR.use_cassette("#{test_root_name}/cleanup") do
    # end
  end
end
