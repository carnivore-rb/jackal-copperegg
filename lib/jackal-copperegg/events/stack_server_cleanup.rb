require 'jackal-copperegg'

module Jackal
  module CfnTools

    # Removes servers from revealcloud on stack deletion. Depends
    # on servers being registered with the CFN stack ID tagged on
    # it.
    class CoppereggStackServerCleanup < Jackal::Cfn::Event

      # Validity of message
      #
      # @param message [Carnivore::Message]
      # @return [TrueClass, FalseClass]
      def valid?(message)
        super do |payload|
          payload.get(:data, :cfn_event, :resource_type) == 'AWS::CloudFormation::Stack' &&
            payload.get(:data, :cfn_event, :resource_status) == 'DELETE_COMPLETE'
        end
      end

      # Delete any revealcloud servers
      #
      # @param message [Carnivore::Message]
      def execute(message)
        failure_wrap(message) do |payload|
          event = payload.get(:data, :cfn_event)
          url = URI.parse(
            config.fetch(
              :copperegg,
              :revealcloud_url,
              'https://api.copperegg.com'
            )
          )
          endpoint = http_endpoint(url.host, url.scheme)
          endpoint.username = config.get(:copperegg, :revealcloud_username)
          endpoint.password = config.get(:copperegg, :revealcloud_password)
          endpoint.connect_timeout = 30
          endpoint.timeout = 30
          destroy_revealcloud_servers(event[:stack_id], endpoint)
          completed(payload, message)
        end
      end

      # Search for all revealcloud servers registered
      # with provided stack ID
      #
      # @param stack_id [String]
      # @param endpoint [Patron::Session]
      # @return [Array<Hash>] servers deleted
      # @todo catch HTTP related errors, log and continue on
      def destroy_revealcloud_servers(stack_id, endpoint)
        servers = detect_revealcloud_servers(stack_id, endpoint)
        debug "Number of servers detected to remove from revealcloud: #{servers.count}"
        servers.each do |server|
          info "Removing server instance from revealcloud: #{server[:uuid]}"
          debug "Server instance information: #{server.inspect}"
          endpoint.delete(
            File.join(
              config.fetch(
                :copperegg,
                :revealcloud_delete_path,
                '/v2/revealcloud/uuids'
              ),
              "#{server[:uuid]}.json"
            )
          )
        end
        servers
      end

      # Find all revealcloud servers tagged with stack id
      #
      # @param stack_id [String]
      # @param endpoint [Patron::Session]
      # @return [Array<Hash>] matching servers
      def detect_revealcloud_servers(stack_id, endpoint)
        response = endpoint.get(
          config.fetch(
            :copperegg,
            :revealcloud_index_path,
            '/v2/revealcloud/systems.json?show_hidden=1'
          )
        )
        servers = MultiJson.load(response.body)
        servers.find_all do |server|
          server.fetch('t', []).include?(stack_id)
        end
      end

    end

  end
end
