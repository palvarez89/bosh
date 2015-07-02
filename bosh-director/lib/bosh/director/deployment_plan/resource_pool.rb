# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module DeploymentPlan
    class ResourcePool
      include ValidationHelper

      # @return [String] Resource pool name
      attr_reader :name

      # @return [DeploymentPlan] Deployment plan
      attr_reader :deployment_plan

      # @return [DeploymentPlan::Stemcell] Stemcell spec
      attr_reader :stemcell

      # @return [DeploymentPlan::Network] Network spec
      attr_reader :network

      # @return [Hash] Cloud properties
      attr_reader :cloud_properties

      # @return [Hash] Resource pool environment
      attr_reader :env

      # @param [DeploymentPlan] deployment_plan Deployment plan
      # @param [Hash] spec Raw resource pool spec from the deployment manifest
      # @param [Logger] logger Director logger
      def initialize(deployment_plan, spec, logger)
        @deployment_plan = deployment_plan

        @logger = logger

        @name = safe_property(spec, "name", class: String)

        @cloud_properties =
          safe_property(spec, "cloud_properties", class: Hash, default: {})

        stemcell_spec = safe_property(spec, "stemcell", class: Hash)
        @stemcell = Stemcell.new(self, stemcell_spec)

        network_name = safe_property(spec, "network", class: String)
        @network = @deployment_plan.network(network_name)

        if @network.nil?
          raise ResourcePoolUnknownNetwork,
                "Resource pool `#{@name}' references " +
                "an unknown network `#{network_name}'"
        end

        @env = safe_property(spec, "env", class: Hash, default: {})
      end

      # Returns resource pools spec as Hash (usually for agent to serialize)
      # @return [Hash] Resource pool spec
      def spec
        {
          "name" => @name,
          "cloud_properties" => @cloud_properties,
          "stemcell" => @stemcell.spec
        }
      end
    end
  end
end
