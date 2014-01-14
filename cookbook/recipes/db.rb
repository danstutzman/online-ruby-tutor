include_recipe 'postgresql::server'
include_recipe 'database::postgresql'

postgresql_connection_info = {
  :host     => '127.0.0.1',
  :port     => node['postgresql']['config']['port'],
  :username => 'postgres',
  :password => node['postgresql']['password']['postgres']
}

postgresql_database node['online-ruby-tutor']['database']['database'] do
  connection postgresql_connection_info
end

postgresql_database_user node['online-ruby-tutor']['database']['username'] do
  connection    postgresql_connection_info
  password      node['online-ruby-tutor']['database']['password']
  action        :create
end

postgresql_database_user node['online-ruby-tutor']['database']['username'] do
  connection    postgresql_connection_info
  database_name node['online-ruby-tutor']['database']['database']
  password      node['online-ruby-tutor']['database']['password']
  privileges    [:all]
  action        :grant
end
