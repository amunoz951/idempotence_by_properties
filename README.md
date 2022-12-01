# idempotence_by_properties Cookbook

[![Cookbook Version](https://img.shields.io/badge/cookbook-0.2.1-green.svg)](https://supermarket.chef.io/cookbooks/idempotence_by_properties)

Provides idempotent resources for property states that cannot be loaded/detected, such as passwords.

Simplest implementation allows for wrapping the resource with the idempotence_by_properties method. Example:

```ruby
idempotence_by_properties do
  powershell_script "Assign #{service_name} service credentials" do
    code assign_credentials_script
    or_if { current_loaded_username != service_username }
  end
end
```

Note the addition of the `or_if` "reverse" guard in the example above. In this example, even if the properties of the resource haven't changed from the last chef-client run, a change in username outside of Chef will cause the resource to update.

## Contents

- [Attributes](#attributes)
- [Methods](#methods)

  - [idempotence_by_properties](#idempotence_by_properties) (preferred)
    * Wraps any resource to allow idempotence by desired properties state compared to the state of the previous chef-client run.
- [Resources](#resources)

  - [idempotence_by_properties_resource](#idempotence_by_properties_resource)
    * Allows idempotency based on comparing checksums of the resource's properties with the previous converge.
  - [idempotence_by_properties_state](#idempotence_by_properties_state)
    * Saves a state that can be retrieved on the subsequent converge using the read_state helper method.

- [Usage](#usage)
  * Preferred usage is to use the idempotence_by_properties method.

- [Recipes](#recipes)

  - [default](#default)
  - [gems](#gems)

- [License and Author](#license-and-author)

## Requirements

### Platforms

- Windows Server 2012 (R2)+
- Centos

### Chef

- Chef 13+

### Cookbooks

- no cookbook dependencies

## Attributes

This attribute defines where state files will be kept when the selected `state_type` is `:file`. This attribute is ignored when the `state_type` is `:attribute` (default).
`default['idempotence_by_properties']['states_folder'] = "#{Chef::Config[:file_cache_path]}/idempotence_by_properties/states"`

## Methods
Mixed in methods:
___
### idempotence_by_properties ###
    Description: Wraps a resource in order to make it idempotent by its properties. All parameters are optional but a block (the resource) must be given.
### Named Parameters: ###
1. idempotent_properties: An array of the properties to be checked for changes in values. Default: All properties.
2. state_type: A symbol representing how to store states. `:attribute` or `:file`. Default: `:attribute` (Saves states in the node's normal attribute space)
3. current_loaded_values: A Hash representing property names and their values that were loaded from the system. Default: `{}`. This is similar to using `load_current_value` except that it will only compare the keys provided. This is useful for checking values that may have changed in between Chef-client runs.
4. excluded_properties: An array of properties that should not be included in these checks.
### Block: ###
A resource block as you would normally declare a resource should be provided.

Examples:
```ruby
idempotence_by_properties do
  powershell_script "Assign #{service_name} service credentials" do
    sensitive true
    code assign_credentials_script
    or_if { current_loaded_username != desired_service_username }
  end
end
```

```ruby
current_loaded_values = { username: current_loaded_username }
idempotence_by_properties(current_loaded_values: current_loaded_values, excluded_properties: [:sensitive]) do
  some_custom_resource "Assign #{service_name} service credentials" do
    sensitive true
    username desired_service_username
    password desired_service_password
  end
end
```

## Resources

### idempotence_by_properties_resource

Same concept as the idempotence_by_properties method except that it is implemented as a custom resource.
Allows idempotence based on comparing checksums of the resource's properties with the previous converge.

#### Actions

default action: `:create`

- `:create` - creates the desired resource with idempotence based on the value of properties compared to the previous run.

#### Properties

- `name` - String, name property, The name of the resource which also gets passed down to the desired resource
- `type` - String or Symbol, required property, The name of the resource type, such as `cookbook_file`.
- `resource_action` - Array of Symbols or Symbol, The action or actions to pass to the specified resource, default: specified resource's default action
- `resource_properties` - Hash, A hash with keys being the property names of the resource and values being their respective values, default: specified resource's default property values
- `excluded_properties` - Array, Array of properties not to be included for idempotency, default: none (empty array)
- `state_type` - Symbol, Defines where to store the states; `:attribute` for saving to node.normal attributes; `:file` to save them to a file instead (Saves state on successful resource completion as opposed to after successful chef-client converge like `:attribute` does), default: `:attribute`
- `current_loaded_values` - This property is similar to the load_current_value method. Provide a hash with keys being the property names that we want to check, such as 'username', and the values being the corresponding values loaded from the system. An example might be reading the current username for a service. Keys omitted from this property will only be compared to the previous run's value. This only affects idempotency.

#### Examples

```ruby
idempotence_by_properties_resource "Assign #{service_name} service credentials" do
  type :powershell_script
  resource_properties ({
    code: assign_credentials_script
  })
  or_if { current_loaded_username != desired_service_username }
end
```

```ruby
idempotence_by_properties_resource "Assign #{service_name} service credentials" do
  type :some_custom_resource
  resource_action :configure
  resource_properties ({
    sensitive: true,
    username: desired_service_username,
    password: desired_service_password,
  })
  current_loaded_values ({
    username: current_loaded_username,
  })
  state_type: :file
end
```

### idempotence_by_properties_state

Saves the provided state to an attribute or file

#### Actions

default action: `:save`

- `:save` - save the state to an attribute or file

#### Properties

- `state_path` - String, name property, A path separated by forward slashes specifying where to store the state, much like Hashicorp Vault paths. It is NOT a filesystem path - EG: 'myproject/environment/sql_credentials'
- `state` - Hash, Array or String, required property, A hash, array, or string with data or checksums to be saved.
- `take_checksum` - true or false, If true, uses a checksum of the object provided in the state property instead of saving the value, default: false
- `state_type` - Symbol, Defines where to store the states; `:attribute` for saving to node.normal attributes; `:file` to save them to a file instead (Saves state on successful resource completion as opposed to after successful chef-client converge like `:attribute` does), default: `:attribute`

#### Examples

```ruby
idempotence_by_properties_state "State of #{service_name} credentials" do
  action :save
  state_path "myproject/some_recipe/#{service_name}/credentials"
  state credentials
  take_checksum true
end
```

## Recipes

### default

`Includes the gems recipe and adds the handler for saving states`

### gems

`Installs required gems`

## License and Author

- Author:: Alex Munoz ([amunoz951@gmail.com](mailto:amunoz951@gmail.com))

```text
Copyright 2020-2020, Alex Munoz.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
