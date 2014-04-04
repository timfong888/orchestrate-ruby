require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "lib/orchestrate-api"
  t.test_files = ["test/test-api.rb"]
  t.verbose = true
end

task default: :test
