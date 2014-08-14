$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'jackal-copperegg/version'
Gem::Specification.new do |s|
  s.name = 'jackal-copperegg'
  s.version = Jackal::Copperegg::VERSION.version
  s.summary = 'Message processing helper'
  s.author = 'Chris Roberts'
  s.email = 'code@chrisroberts.org'
  s.homepage = 'https://github.com/carnivore-rb/jackal-copperegg'
  s.description = 'Copperegg callback helpers'
  s.require_path = 'lib'
  s.license = 'Apache 2.0'
  s.add_dependency 'jackal'
  s.add_dependency 'jackal-cfn'
  s.add_dependency 'patron'
  s.files = Dir['lib/**/*'] + %w(jackal-copperegg.gemspec README.md CHANGELOG.md CONTRIBUTING.md LICENSE)
end
