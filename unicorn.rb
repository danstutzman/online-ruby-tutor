# set path to app that will be used to configure unicorn, 
# note the trailing slash in this example
@dir = "/home/ubuntu/online-ruby-tutor/"

worker_processes 1
working_directory @dir

timeout 5

# Specify path to socket unicorn listens to, 
# we will use this in our nginx.conf later
listen "#{@dir}tmp/sockets/unicorn.sock", :backlog => 64

# Set process id path
pid "#{@dir}tmp/pids/unicorn.pid"

# Set log file paths
stderr_path "#{@dir}log/unicorn.stderr.log"
stdout_path "#{@dir}log/unicorn.stdout.log"
