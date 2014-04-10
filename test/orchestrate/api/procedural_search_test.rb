require "test_helper"

class ProceduralSearchTest < MiniTest::Unit::TestCase

  include Test

  # methods: list, delete_collection
  #
  def test_procedural_search

    test_root_name = 'procedural-search'
    name = 'test_models'
    key = 'instance_1'

    # setup
    output_message(test_root_name, "Test setup")

    VCR.use_cassette("#{test_root_name}/setup") do
      (1..3).each do |num|
        jdoc = { 'Name' => "test_#{num}", 'DESC' => "desc_#{num}"}.to_json
        response = client.put_key(collection: name, key: "instance_#{num}", json: jdoc)
        assert response.success? == true
        assert response.header.code == 201
      end
      sleep 1
    end

    # test
    output_message(test_root_name, "TEST START")

    VCR.use_cassette("#{test_root_name}/synopsis") do

      response = client.search(collection: name, query: "*")
      assert response.body.count == 3

      response = client.search(collection: name, query: "*&offset=1")
      assert response.body.count == 2

      response = client.search(collection: name, query: "*&offset=3")
      assert response.body.count == 0

      response = client.search(collection: name, query: "Name:TEsT_2")
      assert response.body.count == 1

      response = client.search(collection: name, query: "DESC:desc_*")
      assert response.body.count == 3
    end

    # cleanup
    output_message(test_root_name, "Test cleanup")

    VCR.use_cassette("#{test_root_name}/cleanup") do
      (1..3).each do |num|
        response = client.purge_key(collection: name, key: "instance_#{num}")
        assert response.success? == true
        assert response.header.code == 204
      end

      response = client.delete_collection(collection: name)
      assert response.success? == true
      assert response.header.code == 204
    end
  end
end
