# inherit the Conditional class to add :or_if reverse guard without side effects
# see https://github.com/chef/chef/blob/6461450d34b7d4837c6bbfc75113ce1797567e09/lib/chef/resource/conditional.rb for class details
module IdempotenceByProperties
  class ConditionalOr < ::Chef::Resource::Conditional
    def self.or_if(parent_resource, command = nil, command_opts, &block)
      new(:or_if, parent_resource, command, command_opts, &block)
    end

    # overrides the Chef::Resource::Conditional class's `continue?` method to add the :or_if evaluation
    def continue?
      # configure late in case guard_interpreter is specified on the resource after the conditional
      configure

      case @positivity
      when :only_if, :or_if
        evaluate
      when :not_if
        !evaluate
      else
        raise "Cannot evaluate resource conditional of type #{@positivity}"
      end
    end
  end

  module OrIf
    # Use this method to determine whether the resource should be converged. If so, returns true. Implement your own logic based on this value.
    # It can't be included in the typical guard logic because the logic inside the resource must trigger a converge rather than a skip.
    def or_if_continue?
      @or_if ||= []
      @or_if.any?(&:continue?)
    end

    # Define the or_if guard - If customizing your own resource to use this guard (not using the resource or wrapper provided in this
    # cookbook), this must be implemented in the resource by calling new_resource.or_if_continue? and implementing logic to skip accordingly.
    def or_if(command = nil, opts = {}, &block)
      @or_if ||= []
      if command || block_given?
        @or_if << IdempotenceByProperties::ConditionalOr.or_if(self, command, opts, &block)
      end
      @or_if
    end
  end
end

::Chef::Resource.send(:include, IdempotenceByProperties::OrIf)
