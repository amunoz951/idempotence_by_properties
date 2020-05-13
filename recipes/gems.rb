#
# Cookbook:: idempotence_by_properties
# Recipe:: gems
#
# Description:: Installs all gems required by this cookbook. This recipe is called by the default recipe.
#               The default recipe should be included before calling any idempotence_by_properties cookbook resources.
#

required_gems = {
  'hashly' => '~> 0.1',
  'easy_json_config' => '~> 0.3',
  'easy_io' => '~> 0.4',
  'easy_state' => '~> 0.1',
}
required_gems.each do |gem_name, gem_version|
  chef_gem gem_name do
    version gem_version
    compile_time true
    action :upgrade
  end
end

require 'easy_state'

EasyIO.logger = Chef::Log
