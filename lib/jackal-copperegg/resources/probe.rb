require 'base64'
require 'jackal-copperegg'

module Jackal
  module CfnTools
    # Add or remove probes from a stack
    #
    # Expected resource:
    #   {
    #     "Type": "Custom::CoppereggProbe",
    #     "Properties": {
    #       "Parameters": {
    #         "Probes": [
    #           {
    #             ## required
    #             "ProbeDesc": "A description",
    #             "Type": "GET", # or POST, TCP, IMCP
    #             "ProbeDest": "http://localhost",
    #             ## optional
    #             "CheckContents": "match", # or nomatch
    #             "ContentMatch": "StringForComparison",
    #             "Frequency": 30,
    #             "Timeout": 10000,
    #             "Retries": 3,
    #             "Tags": "comma,delimited,tags",
    #             "Stations": ["LON"]
    #           }
    #         ]
    #       }
    #     }
    #   }
    # @see http://dev.copperegg.com/revealuptime/probes.html
    class CoppereggProbe < Jackal::Cfn::Resource

      # Process probe related action
      #
      # @param message [Carnivore::Message]
      def execute(message)
        failure_wrap(message) do |payload|
          cfn_resource = rekey_hash(payload.get(:data, :cfn_resource))
          properties = rekey_hash(cfn_resource[:resource_properties])
          parameters = rekey_hash(properties[:parameters])
          cfn_response = build_response(cfn_resource)
          case cfn_resource[:request_type].to_sym
          when :create
            create_probes(
              :probes => [parameters[:probes]].flatten,
              :response => cfn_response
            )
          when :update
            error 'Update requested but not supported!'
            cfn_response['Status'] = 'FAILED'
            cfn_response['Reason'] = 'Updates are not supported on this resource'
          when :delete
            delete_probes(
              :physical_resource_id => cfn_resource[:physical_resource_id],
              :response => cfn_response
            )
          else
            error "Unknown request type received: #{payload[:request_type]}"
            cfn_response['Status'] = 'FAILED'
            cfn_response['Reason'] = 'Unknown request type received'
          end
          respond_to_stack(cfn_response, cfn_resource[:response_url])
          completed(payload, message)
        end
      end

      # Create new probes
      #
      # @param args [Hash]
      # @option args [Array<Hash>] :probes probes to create
      # @option args [Hash] :response cfn response message
      # @return [TrueClass]
      def create_probes(args={})
        endpoint = generate_endpoint
        results = []
        args[:probes].each do |probe|
          probe_data = MultiJson.dump(rekey_hash(probe))
          debug "Attempting probe creation (#{probe_data.inspect})"
          results.push(
            endpoint.post(
              config.fetch(
                :copperegg,
                :revealuptime_create_path,
                '/v2/revealuptime/probes.json'
              ),
              probe_data,
              'Content-Type' => 'application/json'
            )
          )
        end
        errors = results.find_all do |result|
          result.status != 200
        end
        results -= errors
        results.map! do |result|
          MultiJson.load(result.body)['id']
        end
        if(errors.empty?)
          debug "Probes created: #{results.inspect}"
          args[:response]['PhysicalResourceId'] = Base64.urlsafe_encode64(
            MultiJson.dump(results)
          )
          args[:response]['Status'] = 'SUCCESS'
          args[:response]['Data']['Reason'] = "New copperegg probes added: #{results.size}"
        else
          probe_deletion(*results)
          args[:response]['Status'] = 'FAILED'
          args[:response]['Reason'] = "Probe creation failed: #{errors.map(&:body).map(&:strip).join(', ')}"
        end
        true
      end

      # Call API to delete probes
      #
      # @param ids [String] probe id list
      # @return [Array<Patron::Response>]
      def probe_deletion(*ids)
        endpoint = generate_endpoint
        ids.map do |probe_id|
          debug "Copperegg probe deletion ID: #{probe_id}"
          if(probe_id.to_s.strip.empty?)
            error 'Encountered an empty probe ID. Skipping.'
            nil
          else
            delete_path = File.join(
              config.fetch(
                :copperegg,
                :revealuptime_delete_path,
                '/v2/revealuptime/probes'
              ),
              "#{probe_id}.json"
            )
            endpoint.delete(delete_path)
          end
        end.compact
      end

      # Delete probes
      #
      # @param args [Hash]
      # @option args [String] :physical_resource_id probes to delete
      # @option args [Hash] :response cfn response message
      # @return [TrueClass]
      def delete_probes(args={})
        begin
          ids = MultiJson.load(
            Base64.urlsafe_decode64(
              args[:physical_resource_id]
            )
          )
          results = probe_deletion(*ids)
          errors = results.find_all do |r|
            r.status != 200 && r.status != 404
          end
          results -= errors
          if(errors.empty?)
            args[:response]['Status'] = 'SUCCESS'
            args[:response]['Data']['Reason'] = "Probes removed (#{ids.count})"
          else
            args[:response]['Status'] = 'FAILED'
            args[:response]['Reason'] = "Probe deletion failed: #{errors.map(&:body).map(&:strip).join(', ')}"
          end
        rescue ArgumentError, MultiJson::ParseError
          args[:response]['Status'] = 'SUCCESS'
          args[:response]['Data']['Reason'] = 'No probes to delete!'
        end
        true
      end

      # @return [Patron::Session]
      def generate_endpoint
        url = URI.parse(
          config.fetch(
            :copperegg,
            :revealuptime_url,
            'https://api.copperegg.com'
          )
        )
        endpoint = http_endpoint(url.host, url.scheme)
        endpoint.username = config.get(:copperegg, :revealuptime_username)
        endpoint.password = config.get(:copperegg, :revealuptime_password)
        endpoint
      end

    end

  end
end
