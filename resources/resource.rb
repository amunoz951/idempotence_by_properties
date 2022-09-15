# Description:
#   Wraps resources, making non-idempotent resources idempotent based on the resource's property values from the previous chef-client converge.
#   This is particularly useful for sensitive properties like passwords that cannot be compared with an existing value.
# Caveats:
#   Cannot natively tell if something was changed outside of Chef. Use the `or_if` guard to load available property values and trigger an update if changed.
provides :idempotence_by_properties_resource
unified_mode true if respond_to?(:unified_mode)

### Special guard added for this resource!
#   The `or_if` guard functions just like nof_if/only_if, except that it relates to the property states.
#   If `or_if` evaluates to true, then the resource specified will be executed, even if the desired state is the same as the state during the last converge.
#   This is so that if something that can be looked up was changed outside of chef, like a username, the resource can converge to correct it.
#   Consider it a `force_converge` flag.
# Defined in IdempotenceByProperties::OrIf module in ../libraries/conditional_or.rb

# :name property for the idempotence_by_properties_resource is passed on to the child resource
property :type, [String, Symbol], required: true # The name of the resource, such as `cookbook_file`
property :resource_action, [Array, Symbol] # The action or actions to use for the specified resource
property :resource_properties, Hash # A hash with keys being the property names of the resource and values being their respective values
property :excluded_properties, [String, Array], default: [] # Array of properties not to be included for idempotency
property :state_type, Symbol, default: :attribute # Where to store the states; :attribute for node.normal attributes; :file to save them to a file instead (Saves state on successful resource completion as opposed to after successful chef-client converge like :attribute)

# The property below is similar to the load_current_value method. Provide a hash with keys being the field names that we want to check, such
# as 'username', and the values being the corresponding values loaded from the system. An example might be reading the current username for
# a service. Only keys included in this property will be compared. This only affects idempotency.
property :current_loaded_values, Hash, default: {}

default_action :create

action :create do
  standardize_properties(new_resource)

  # Ensure the default recipe has been included to setup gems and handler
  ::Chef.run_context.include_recipe 'idempotence_by_properties::default'

  # Identify selected properties
  properties_to_check = new_resource.resource_properties.reject { |property, _value| new_resource.excluded_properties.include?(property) }

  # Determine where to store/read state
  resource_key = "#{new_resource.resource_action}-#{properties_to_check}" # To differentiate identically named resources
  resource_checksum = EasyState.object_state(resource_key) # To hide any sensitive properties
  source_relative_path = new_resource.source_line_file.split('cookbooks/', 2).last # To differentiate identical resources from different code files
  state_path = "#{new_resource.cookbook_name}/#{source_relative_path}/#{new_resource.type}/#{new_resource.identity}/#{resource_checksum}/properties"
  state_path.sub!("#{new_resource.cookbook_name}/#{new_resource.cookbook_name}", new_resource.cookbook_name) # Remove duplicate key

  # Get desired and previous states
  previous_properties_state = IdempotenceByProperties::Helper.lookup_state(state_path, state_type: new_resource.state_type)
  new_properties_state = EasyState.hash_state(properties_to_check) # Get state by property for more granular data

  # Determine idempotency
  changed_properties = EasyState.changed_keys(previous_properties_state, new_properties_state)
  changed_properties.each { |changed_property| Chef::Log.info "Property :#{changed_property} has changed..." }
  changed_desired_values = Hashly.deep_diff(properties_to_check, new_resource.current_loaded_values)
  update_target_resource = new_resource.or_if_continue? || !changed_properties.empty? || !changed_desired_values.empty?

  # Create the intended resource
  send(new_resource.type, new_resource.name) do
    action new_resource.resource_action unless new_resource.resource_action.nil?
    new_resource.resource_properties.each { |property, value| send(property, value) }
    not_if { !update_target_resource }
  end

  # If nothing has changed, save the state to the run_state and exit the resource "Up to date".
  # At the end of the run, the handler will save all states if any have changed. This ensures that stale states don't pile up.
  unless update_target_resource
    IdempotenceByProperties::Helper.save_to_run_state(state_path, new_properties_state, new_resource.state_type)
    return
  end

  # Save the state of the resource
  idempotence_by_properties_state new_resource.name do
    action :save
    state_path state_path
    state new_properties_state
    state_type new_resource.state_type
  end
end

def standardize_properties(new_resource)
  new_resource.excluded_properties = [new_resource.excluded_properties] if new_resource.excluded_properties.is_a?(String)
  new_resource.resource_properties = [] if new_resource.resource_properties.nil?
end
