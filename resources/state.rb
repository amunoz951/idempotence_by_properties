resource_name :idempotence_by_properties_state

# Common properties
property :state_path, String, name_property: true # A path separated by forward slashes specifying where to store the state, much like Hashicorp Vault paths. It is NOT a filesystem path - EG: 'myproject/environment/sql_credentials'
property :state, [Hash, Array, String], required: true # A hash, array, or string with data or checksums to be saved.
property :take_checksum, [TrueClass, FalseClass], default: false # If true, uses a checksum of the object provided in the state property instead of saving the value
property :state_type, Symbol, default: :attribute # Stores the states as attributes. Use :file to save them to a file instead (Saves state on successful resource completion as opposed to after successful chef-client converge like :attribute)

default_action :save

state_content = nil

load_current_value do |desired_resource|
  raise "#{desired_resource.state_type} is not a supported state_type!" unless [:attribute, :file].include?(desired_resource.state_type)
  previous_state_content = IdempotenceByProperties::Helper.lookup_state(desired_resource.state_path, state_type: desired_resource.state_type)
  state_content = desired_resource.take_checksum ? EasyState.object_state(desired_resource.state) : desired_resource.state
  state state_content == previous_state_content ? desired_resource.state : { state_changed: true }
  state_type desired_resource.state_type # Don't need to know if storage type changed
end

action :save do
  new_resource.sensitive = true if new_resource.take_checksum

  # Save the state to the run_state. At the end of the run, the handler will save all states
  # collected this run to a node.normal attribute. This ensures that stale states don't pile up.
  IdempotenceByProperties::Helper.save_to_run_state(new_resource.state_path, new_resource.state, new_resource.state_type)

  converge_if_changed do
    case new_resource.state_type
    when :attribute
      break # No action needed. State was already saved to the run_state.
    when :file
      IdempotenceByProperties::Helper.save_file_state(new_resource.state_path, state_content)
    end
  end
end
