module Bosh::Director
  class Errand::JobManager
    # @param [Bosh::Director::DeploymentPlan::Planner] deployment
    # @param [Bosh::Director::DeploymentPlan::Job] job
    # @param [Bosh::Blobstore::Client] blobstore
    # @param [Bosh::Director::EventLog::Log] event_log
    # @param [Logger] logger
    def initialize(deployment, job, blobstore, event_log, logger)
      @deployment = deployment
      @job = job
      @blobstore = blobstore
      @event_log = event_log
      @logger = logger
    end

    def prepare
      @job.bind_unallocated_vms
      @job.bind_instance_networks
    end

    def create_missing_vms
      instances_with_missing_vms = @job.instances_with_missing_vms
      return @logger.info('No missing vms to create') if instances_with_missing_vms.empty?
      counter = instances_with_missing_vms.length
      ThreadPool.new(max_threads: Config.max_threads, logger: @logger).wrap do |pool|
        instances_with_missing_vms.each do |instance|
          pool.process do
            @event_log.track("#{instance.job.name}/#{instance.index}") do
              with_thread_name("create_missing_vm(#{instance.job.name}, #{instance.index}/#{counter})") do
                @logger.info("Creating missing VM")
                disks = [instance.model.persistent_disk_cid]
                Bosh::Director::VmCreator.create_for_instance(instance,disks)
              end
            end
          end
        end
      end
    end

    # Creates/updates all errand job instances
    # @return [void]
    def update_instances
      dns_binder = DeploymentPlan::DnsBinder.new(@deployment)
      dns_binder.bind_deployment

      job_renderer = JobRenderer.new(@job, @blobstore)
      job_updater = JobUpdater.new(@deployment, @job, job_renderer)
      job_updater.update
    end

    # Deletes all errand job instances
    # @return [void]
    def delete_instances
      instances = @job.instances.map(&:to_instance_deleter_info).compact
      if instances.empty?
        @logger.info('No errand instances to delete')
        return
      end

      @logger.info('Deleting errand instances')
      event_log_stage = @event_log.begin_stage('Deleting errand instances', instances.size, [@job.name])
      instance_deleter = InstanceDeleter.new(@deployment)
      instance_deleter.delete_instances(instances, event_log_stage)
    end
  end
end
