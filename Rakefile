require 'bundler/gem_tasks'

def specs(dir)
  FileList["spec/#{dir}/*_spec.rb"].map{|f| File.absolute_path(f)}.shuffle.join(' ')
end

desc 'Runs all the specs'
task :specs do
  sh "bundle exec bacon #{specs('**')}"
end

task :default => :specs
