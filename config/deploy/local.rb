set :stage, :local

role :app, 'localhost'
role :web, 'localhost'
role :db,  'localhost', primary: true

set :ssh_options, {
  keys: %w(/Users/daniel/.vagrant.d/insecure_private_key),
  forward_agent: true,
  port: 2222 # vagrant forwards 22 of virtual machine to 2222 on the host
}
