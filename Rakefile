# frozen_string_literal: true

require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs.push('lib', 'test')

  t.test_files = if ENV['TEST_FILE']
                   FileList["#{ENV['TEST_FILE']}*",
                            "test/**/#{ENV['TEST_FILE']}*"]
                 else
                   FileList['test/**/test_*.rb', 'test/**/*_test.rb']
                 end
  t.verbose = ENV.fetch('VERBOSE', false)
  t.warning = ENV.fetch('WARNING', false)
end

require 'rubocop/rake_task'

RuboCop::RakeTask.new

require 'bump/tasks'

task default: %i[test rubocop]
