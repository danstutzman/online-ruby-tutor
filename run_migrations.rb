require 'active_record'
require 'logger'
require 'yaml'

config_path = File.join(File.dirname(__FILE__), 'config.yaml')
CONFIG = YAML.load_file(config_path)
env = ENV['RACK_ENV'] || 'development'
db_params = CONFIG['DATABASE_PARAMS'][env]
ActiveRecord::Base.establish_connection(db_params)

ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Migration.verbose = true
ActiveRecord::Migrator.migrate("db/migrate")
