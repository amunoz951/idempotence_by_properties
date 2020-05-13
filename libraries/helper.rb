require 'json'

module IdempotenceByProperties
  module Helper
    def lookup_state(state_path, state_type: nil)
      state_type ||= :attribute
      return lookup_attribute_state(state_path) if state_type == :attribute
      EasyState.read_state(state_path, states_folder: node['idempotence_by_properties']['states_folder'])
    end

    def lookup_attribute_state(state_path)
      state_root_key = state_path.split('/').first
      EasyState.read_state(state_path, previous_state_hash: node['idempotence_by_properties']['states'][state_root_key])
    end

    def add_to_state_hash(state_hash, state_path, state)
      state_keys = state_path.split('/')
      current_path_hash = state_hash
      state_keys.each do |state_key|
        current_path_hash[state_key] = state if state_key == state_keys.last # on the leaf (last key), return the checksum
        current_path_hash[state_key] ||= {}
        current_path_hash = current_path_hash[state_key] # move up one level
      end
      state_hash
    end

    def save_file_state(state_path, state)
      EasyState.save_state(state_path, state, states_folder: node['idempotence_by_properties']['states_folder'])
    end

    def save_to_run_state(state_path, state, state_type)
      node.run_state['idempotence_by_properties'] ||= {}
      node.run_state['idempotence_by_properties']['states'] ||= {}
      state_hash = node.run_state['idempotence_by_properties']['states'][state_type.to_s] || {}
      add_to_state_hash(state_hash, state_path, state)
      node.run_state['idempotence_by_properties']['states'][state_type.to_s] = state_hash
    end

    def self.save_all_states
      node = Chef.run_context.node

      # Save the run_states based on their state_type key
      node.run_state['idempotence_by_properties']['states'].each do |state_type, state_hash|
        case state_type
        when 'attribute'
          next unless state_hash.any? { |root_state_key, state_content| EasyState.state_changed?(root_state_key, state_content, previous_state_hash: node['idempotence_by_properties']['states'][root_state_key]) }
          node.normal['idempotence_by_properties']['states'] = state_hash
        when 'file'
          state_hash.each do |root_state_key, state_content|
            next unless EasyState.state_changed?(root_state_key, state_content, states_folder: node['idempotence_by_properties']['states_folder'])
            EasyState.save_state(root_state_key, state_content, states_folder: node['idempotence_by_properties']['states_folder'], merge_with_existing_states: false, silent: true)
            @state_by_file_changed = true
          end
          next unless state_by_file_changed? # skip the log message unless something changed
        end
        Chef::Log.info "States saved by #{state_type} for idempotence_by_properties resources."
      end
    end

    def self.state_by_file_changed?
      @state_by_file_changed
    end
  end
end

Chef::Resource.send(:include, IdempotenceByProperties::Helper)
Chef::Provider.send(:include, IdempotenceByProperties::Helper)
