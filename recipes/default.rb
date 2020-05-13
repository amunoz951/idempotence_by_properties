#
# Cookbook:: idempotence_by_properties
# Recipe:: default
#

# Install required gems
include_recipe 'idempotence_by_properties::gems'

# Register an event handler to kick off at the end of the converge. This handler
# saves all states to their corresponding storage type. This is necessary to keep
# stale states from piling up since states can only be merged while converging.
Chef.event_handler do
  on :converge_complete do
    IdempotenceByProperties::Helper.save_all_states
  end
end
