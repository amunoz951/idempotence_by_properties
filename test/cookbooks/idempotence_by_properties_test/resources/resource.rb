# Description:
#   Tests idempotence_by_properties wrapper and resource
provides :idempotence_by_properties_test_resource
unified_mode true if respond_to?(:unified_mode)

default_action :run

action :run do
  # Test the preferred implementation (using the wrapper) from within a custom resource
  idempotence_by_properties do
    execute 'This is a test inside a resource' do
      command 'echo This is a test message inside a resource.'
    end
  end

  # Test the resource implementation from within a custom resource
  idempotence_by_properties_resource 'This is a resource test inside a resource' do
    type :execute
    resource_properties({
      command: 'echo This is a resource test message inside a resource.',
    })
  end
end
