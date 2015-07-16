require 'spec_helper'

describe 'Baserock OS image', os_image: true do
  it_behaves_like 'every OS image'
  it_behaves_like 'a systemd-based OS image'
  it_behaves_like 'a Linux kernel 3.x based OS image'


end
