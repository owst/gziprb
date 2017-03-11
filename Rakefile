# frozen_string_literal: true
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--config', '.rubocop.yaml', '--display-cop-names']
end

BATS_PATH = './node_modules/bats/libexec/bats'

desc 'Run integration tests, (requires gzip/gunzip to be available)'
task :integration_test do
  puts 'Running integration shell tests...'

  if system("#{BATS_PATH} --version &>/dev/null")
    system("#{BATS_PATH} spec/integration_tests.bats")
  else
    STDERR.puts(<<-WARN)
WARNING: failed to execute #{BATS_PATH}!
Use `npm install` to attempt install bats and required libraries. Alternatively, just run the unit
tests with `bundle exec rake spec`.
WARN

    exit(1)
  end
end

desc 'Run spec and integration tests'
task :test do
  Rake::Task['integration_test'].execute
  Rake::Task['spec'].execute
end

task default: :test
