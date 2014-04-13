require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, ENV['RACK_ENV'].to_sym)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require './web-app.rb'

run App
