module Bosh::Director
  module DeploymentPlan
    module Steps
      class UpdateStep
        def initialize(base_job, event_log, resource_pools, deployment_plan, multi_job_updater, cloud, blobstore)
          @base_job = base_job
          @logger = base_job.logger
          @event_log = event_log
          @resource_pools = resource_pools
          @cloud = cloud
          @blobstore = blobstore
          @deployment_plan = deployment_plan
          @multi_job_updater = multi_job_updater
        end


        def perform
          begin
            @logger.info('Updating deployment')
            assemble
            update_jobs
            @logger.info('Committing updates')
            @deployment_plan.persist_updates!
            @logger.info('Finished updating deployment')
          ensure
            @deployment_plan.update_stemcell_references!
          end
        end

        private

        def assemble
          @logger.info('Deleting no longer needed VMs')
          delete_unneeded_vms

          @logger.info('Deleting no longer needed instances')
          delete_unneeded_instances

          @logger.info('Updating resource pools')
          # this just creates vms that don't exist yet for @deployment_plan.jobs_starting_on_deploy
          @resource_pools.update
          @base_job.task_checkpoint

          @logger.info('Binding instance VMs')

          @event_log.begin_stage('Preparing configuration', 1)
        end

        def update_jobs
          @logger.info('Updating jobs')
          @multi_job_updater.run(
            @base_job,
            @deployment_plan,
            @deployment_plan.jobs_starting_on_deploy,
          )
        end

        private

        def delete_unneeded_vms
          unneeded_vms = @deployment_plan.unneeded_vms
          if unneeded_vms.empty?
            @logger.info('No unneeded vms to delete')
            return
          end

          @event_log.begin_stage('Deleting unneeded VMs', unneeded_vms.size)
          ThreadPool.new(max_threads: Config.max_threads, logger: @logger).wrap do |pool|
            unneeded_vms.each do |vm_model,reservations_by_network|
              pool.process do
                @event_log.track(vm_model.cid) do
                  @logger.info("Delete unneeded VM #{vm_model.cid}")
                  @cloud.delete_vm(vm_model.cid)
                  reservations_by_network.each do |network_name,reservation|
                      @deployment_plan.network(network_name).release(reservation)
                  end
                  vm_model.destroy
                end
              end
            end
          end
        end

        def delete_unneeded_instances
          unneeded_instances = @deployment_plan.unneeded_instances
          if unneeded_instances.empty?
            @logger.info('No unneeded instances to delete')
            return
          end
          event_log_stage = @event_log.begin_stage('Deleting unneeded instances', unneeded_instances.size)
          instance_deleter = InstanceDeleter.new(@deployment_plan)
          instance_deleter.delete_instances(unneeded_instances, event_log_stage)
          @logger.info('Deleted no longer needed instances')
        end
      end
    end
  end
end
