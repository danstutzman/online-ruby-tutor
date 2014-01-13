require 'active_record'
require 'logger'
require 'yaml'
require 'uri'

namespace "db" do
  task "migrate" do
    config_path = File.join(File.dirname(__FILE__), 'config.yaml')
    if File.exists?(config_path)
      CONFIG = YAML.load_file(config_path)
      env = ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
      db_params = CONFIG['DATABASE_PARAMS'][env]
      ActiveRecord::Base.establish_connection(db_params)
    elsif ENV['DATABASE_URL'] # for Heroku
      db = URI.parse(ENV['DATABASE_URL'])
      ActiveRecord::Base.establish_connection({
        :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
        :host     => db.host,
        :port     => db.port,
        :username => db.user,
        :password => db.password,
        :database => db.path[1..-1],
        :encoding => 'utf8',
      })
    else
      raise "No #{config_path} and no ENV[DATABASE_URL]"
    end
    
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true
    if ARGV[0] == 'rollback'
      ActiveRecord::Migrator.rollback("db/migrate")
    else
      ActiveRecord::Migrator.migrate("db/migrate")
    end
  end
end
