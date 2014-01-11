group node['online-ruby-tutor']['group']

user node['online-ruby-tutor']['user'] do
  group node['online-ruby-tutor']['group']
  system true
  shell '/bin/bash'
end

include_recipe 'apt'

apt_package 'nginx' do
  action :install
end

cookbook_file '/etc/nginx/nginx.conf' do
  source 'nginx.conf'
  action :create # will replace the file
  notifies :restart, 'service[nginx]', :delayed # will start if not started
end

service 'nginx' do
  action :start
end

apt_package 'libpq-dev' do
  action :install
end

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
