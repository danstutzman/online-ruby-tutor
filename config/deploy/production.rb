set :stage, :production

role :app, '162.243.221.218'
role :web, '162.243.221.218'
role :db,  '162.243.221.218', primary: true
