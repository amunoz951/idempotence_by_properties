#
# Cookbook:: idempotence_by_properties
# Recipe:: gems
#
# Description:: Installs all gems required by this cookbook. This recipe is called by the default recipe.
#               The default recipe should be included before calling any idempotence_by_properties cookbook resources.
#

required_gems = {
  'os' => '1.1.0',
  'hashly' => '0.1.0', # dependency of easy_json_config
  'easy_json_config' => '0.3.0', # dependency of easy_io
  'logger' => '1.4.2', # dependency of easy_io
  'open3' => '0.1.0', # dependency of easy_io
  'easy_format' => '0.2.0', # dependency of easy_io gem
  'easy_io' => '0.4.1', # dependency of zipr gem
  'easy_state' => '0.1.0',
}
required_gems.each do |gem_name, gem_version|
  chef_gem gem_name do
    version gem_version
    compile_time true
    action :install
  end
end

require 'easy_state'

EasyIO.logger = Chef::Log
