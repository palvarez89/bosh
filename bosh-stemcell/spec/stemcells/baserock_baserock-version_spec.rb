require 'spec_helper'

describe 'Baserock baserock-version stemcell', stemcell_image: true do
  it_behaves_like 'All Stemcells'

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/operating_system') do
      it { should contain('baserock') }
    end
  end

  context 'installed by bosh_openstack_agent_settings', {
    exclude_on_aws: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      it { should contain('"CreatePartitionIfNoEphemeralDisk": true') }
      it { should contain('"Type": "ConfigDrive"') }
      it { should contain('"Type": "HTTP"') }
    end
  end
end

