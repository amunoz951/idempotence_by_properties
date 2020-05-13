module IdempotenceByProperties
  module ResourceWrapper
    def idempotence_by_properties(idempotent_properties: nil, state_type: :attribute, current_loaded_values: nil, excluded_properties: nil)
      # Ensure the default recipe has been included to setup gems and handler
      ::Chef.run_context.include_recipe 'idempotence_by_properties::default'

      # Defaults
      idempotent_properties ||= []
      state_type ||= :attribute
      current_loaded_values ||= {}
      excluded_properties ||= []

      # Create the intended resource
      target_resource = yield

      # Identify selected properties
      resource_properties = target_resource.state_for_resource_reporter
      resource_properties = resource_properties.select { |property, _value| idempotent_properties.include?(property) } unless idempotent_properties.empty?
      properties_to_check = resource_properties.reject { |property, _value| excluded_properties.include?(property) }

      # Determine where to store/read state
      resource_key = "#{target_resource.action}-#{properties_to_check.keys}" # To differentiate identically identified resources
      resource_checksum = EasyState.object_state(resource_key) # To hide any sensitive properties
      source_relative_path = target_resource.source_line_file.split('cookbooks/', 2).last # To differentiate identical resources from different code files
      state_path = "#{target_resource.cookbook_name}/#{source_relative_path}/#{target_resource.resource_name}/#{target_resource.identity}/#{resource_checksum}/properties"
      state_path.sub!("#{target_resource.cookbook_name}/#{target_resource.cookbook_name}", target_resource.cookbook_name) # Remove duplicate key

      # Get desired and previous states
      desired_properties_state = EasyState.hash_state(properties_to_check) # Get state by property for more granular data
      previous_properties_state = lookup_state(state_path, state_type: state_type)

      # Determine idempotency
      changed_properties = EasyState.changed_keys(previous_properties_state, desired_properties_state)
      changed_properties.keys.each { |changed_property| Chef::Log.info "Property :#{changed_property} has changed..." }
      changed_desired_values = Hashly.deep_diff(properties_to_check, current_loaded_values)
      update_target_resource = target_resource.or_if_continue? || !changed_properties.empty? || !changed_desired_values.empty?

      # If nothing has changed, save the state to the run_state and prevent a resource update (Show as "Up to date").
      # At the end of the run, the handler will save all states if any have changed. This ensures that stale states don't pile up.
      unless update_target_resource
        save_to_run_state(state_path, desired_properties_state, state_type)
        target_resource.not_if { true } # Don't update the resource
        return
      end

      # Save the state of the resource
      idempotence_by_properties_state target_resource.name do
        action :save
        state_path state_path
        state desired_properties_state
        state_type state_type
      end
    end
  end
end

Chef::Resource.send(:include, IdempotenceByProperties::ResourceWrapper)
Chef::Provider.send(:include, IdempotenceByProperties::ResourceWrapper)
Chef::Recipe.send(:include, IdempotenceByProperties::ResourceWrapper)
