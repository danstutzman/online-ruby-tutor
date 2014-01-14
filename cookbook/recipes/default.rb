group node['online-ruby-tutor']['group']

user node['online-ruby-tutor']['user'] do
  group node['online-ruby-tutor']['group']
  system true
  shell '/bin/bash'
  supports :manage_home => true
  home "/home/#{node['online-ruby-tutor']['user']}"
end

directory "/home/#{node['online-ruby-tutor']['user']}/.ssh" do
  action :create
  owner  node['online-ruby-tutor']['user']
  group  node['online-ruby-tutor']['group']
  mode   '0700'
end

template "/home/#{node['online-ruby-tutor']['user']}/.ssh/authorized_keys" do
  source 'authorized_keys.erb'
  owner  node['online-ruby-tutor']['user']
  group  node['online-ruby-tutor']['group']
  mode  '0600'
  variables :keys => data_bag_item('users', 'online-ruby-tutor')["ssh_keys"]
end

#file "/home/#{node['online-ruby-tutor']['user']}/.ssh/authorized_keys" do
#  owner  node['online-ruby-tutor']['user']
#  group  node['online-ruby-tutor']['group']
#  mode  '0600'
#  content ::File.open("/home/#{ENV['USER']}/.ssh/authorized_keys").read
#  action :create
#end

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

# Need Git for capistrano deploy
apt_package 'git' do
  action :install
end

%w[
  /var/www/online-ruby-tutor
  /var/www/online-ruby-tutor/shared
  /var/www/online-ruby-tutor/shared/pids
  /var/www/online-ruby-tutor/shared/log
  /var/www/online-ruby-tutor/releases
].each do |path|
  directory path do
    owner node['online-ruby-tutor']['user']
    group node['online-ruby-tutor']['group']
    mode 00755
    action :create
    recursive true
  end
end

template '/var/www/online-ruby-tutor/shared/config.yaml' do
  source 'config.yaml.erb'
  owner node['online-ruby-tutor']['user']
  group node['online-ruby-tutor']['group']
  mode 0644
  variables({
    :google_key =>
      data_bag_item('apps', 'online-ruby-tutor')['google_key'],
    :google_secret =>
      data_bag_item('apps', 'online-ruby-tutor')['google_secret'],
    :cookie_signing_secret =>
      data_bag_item('apps', 'online-ruby-tutor')['cookie_signing_secret'],
    :airbrake_api_key =>
      data_bag_item('apps', 'online-ruby-tutor')['airbrake_api_key']
  })
end

include_recipe 'rbenv'
include_recipe 'rbenv::ruby_build'

rbenv_ruby node['online-ruby-tutor']['ruby_version']

rbenv_gem "bundler" do
  ruby_version node['online-ruby-tutor']['ruby_version']
end

apt_package 'nodejs' do
  action :install
end

rbenv_gem 'thin' do
  ruby_version node['online-ruby-tutor']['ruby_version']
end

execute '/opt/rbenv/versions/1.9.3-p448/bin/thin install' do
end

template "/etc/thin/online-ruby-tutor.yml" do
  source 'thin.yml.erb'
  owner  node['online-ruby-tutor']['user']
  group  node['online-ruby-tutor']['group']
  mode  '0644'
  variables({
    :dir => '/var/www/online-ruby-tutor/current',
    :environment => 'production',
    :port => 3004,
  })
  notifies :restart, 'service[thin]', :delayed
end

execute '/usr/sbin/update-rc.d -f thin defaults' do
end

service 'thin' do
  action :start
end
