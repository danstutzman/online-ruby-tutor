set :stage, :local

role :app, '192.168.33.10'
role :web, '192.168.33.10'
role :db,  '192.168.33.10', primary: true

set :ssh_options, {
  keys: %w(/Users/daniel/.vagrant.d/insecure_private_key),
  forward_agent: true,
}
