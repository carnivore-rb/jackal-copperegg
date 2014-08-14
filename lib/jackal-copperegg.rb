require 'jackal-cfn'
require 'jackal-copperegg/version'

module Jackal
  module CfnTools
    autoload :CoppereggProbe, 'jackal-copperegg/resources/probe'
    autoload :CoppereggStackServerCleanup, 'jackal-copperegg/events/stack_server_cleanup'
  end
end
