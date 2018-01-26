# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods_packager.rb'

Gem::Specification.new do |spec|
  spec.name = 'cocoapods-packager'
  spec.version = Pod::Packager::VERSION
  spec.authors = ['Kyle Fuller', 'Boris Bügling']
  spec.summary = 'CocoaPods plugin which allows you to generate a framework or static library from a podspec.'
  spec.homepage = 'https://github.com/CocoaPods/cocoapods-packager'
  spec.license = 'MIT'
  spec.files = `git ls-files`.split($/)
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "cocoapods", '>= 1.1.1', '< 2.0'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
