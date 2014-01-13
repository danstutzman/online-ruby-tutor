set :stage, :production

set :user, 'deployer'
set :use_sudo, false

role :app, '162.243.221.218'
role :web, '162.243.221.218'
role :db,  '162.243.221.218', primary: true
