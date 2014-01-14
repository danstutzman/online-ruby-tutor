require 'bundler/capistrano'

set :stages, %w(local production)
require 'capistrano/ext/multistage'

set :application, 'online-ruby-tutor'
set :repository, 'https://github.com/danielstutzman/online-ruby-tutor.git'

set :deploy_to, '/var/www/online-ruby-tutor'
set :scm, :git
set :git_enable_submodules, 1

set :rails_env, 'production'

set :normalize_asset_timestamps, false

set :user, 'deployer'
set :use_sudo, false

set :bundle_cmd, '/opt/rbenv/shims/bundle'
#set :bundle_flags, '--deployment --quiet --binstubs --shebang ruby-local-exec'

# cap v3 only?
#set :linked_files, %w{config.yaml}
#set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

#set :deploy_via, :copy
set :deploy_via, :remote_cache

# set :default_env, { path: "/opt/ruby/bin:$PATH" }
# set :keep_releases, 5

#namespace :deploy do
#
#  desc 'Restart application'
#  task :restart do
#    on roles(:app), in: :sequence, wait: 5 do
#      # Your restart mechanism here, for example:
#      # execute :touch, release_path.join('tmp/restart.txt')
#    end
#  end
#
#  after :restart, :clear_cache do
#    on roles(:web), in: :groups, limit: 3, wait: 10 do
#      # Here we can do anything such as:
#      # within release_path do
#      #   execute :rake, 'cache:clear'
#      # end
#    end
#  end
#
#  after :finishing, 'deploy:cleanup'
#
#end

namespace :deploy do
  desc "Start the Thin processes"
  task :start do
    run "sudo service thin start"
  end

  desc "Stop the Thin processes"
  task :stop do
    run "sudo service thin stop"
  end

  desc "Restart the Thin processes"
  task :restart do
    run "sudo service thin stop >/dev/null"
    run "sudo service thin start"
  end
end

after 'deploy:update_code', 'deploy:symlink_config'

namespace :deploy do
  desc "Symlinks the config.yaml"
  task :symlink_config, :roles => :app do
    run "ln -nfs #{deploy_to}/shared/config.yaml #{release_path}/config.yaml"
  end
end
