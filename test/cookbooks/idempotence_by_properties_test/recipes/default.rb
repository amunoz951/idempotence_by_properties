#
# Cookbook:: idempotence_by_properties_test
# Recipe:: default
#
# Copyright:: 2020, Alex Munoz, All Rights Reserved.

# Test the wrapper - preferred implementation
idempotence_by_properties do
  execute 'This is a test' do
    command 'echo This is a test message.'
  end
end

# Test the resource implementation
idempotence_by_properties_resource 'This is a resource test' do
  type :execute
  resource_properties({
    command: 'echo This is a resource test message.',
  })
end
