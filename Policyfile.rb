name 'kitchen_idempotence_by_properties'

default_source :supermarket, 'https://supermarket.chef.io'

run_list 'idempotence_by_properties_test::default'

# which cookbooks to use
cookbook 'idempotence_by_properties', path: '.'
cookbook 'idempotence_by_properties_test', path: 'test/cookbooks/idempotence_by_properties_test'
