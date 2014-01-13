set :stage, :production

set :user, 'root'

role :app, '162.243.221.218'
role :web, '162.243.221.218'
role :db,  '162.243.221.218', primary: true
