require 'bundler/gem_tasks'

def specs(dir)
  FileList["spec/#{dir}/*_spec.rb"].shuffle.join(' ')
end

namespace :spec do
  desc 'Runs the unit specs'
  task :unit do
    sh "bundle exec bacon #{specs('unit/**')}"
  end

  desc 'Runs the integration specs'
  task :integration do
    sh "bundle exec bacon #{specs('integration/**')}"
  end

  desc 'Runs the command specs'
  task :command do
    sh "bundle exec bacon #{specs('command/**')}"
  end

  desc 'Runs all the specs'
  task :all do
    sh "bundle exec bacon #{specs('**')}"
  end
end

task :default => 'spec:all'
