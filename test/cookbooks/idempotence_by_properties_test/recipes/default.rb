#
# Cookbook:: idempotence_by_properties_test
# Recipe:: default
#
# Copyright:: 2020, Alex Munoz, All Rights Reserved.

idempotence_by_properties do
  execute 'This is a test' do
    command 'echo This is a test message.'
  end
end
