require 'sinatra'
require 'pry'
require 'json'
require 'haml'
require './get_trace_for.rb'

set :port, 4567
set :public_folder, 'public'
set :static_cache_control, [:public, :no_cache]
set :haml, { :format => :html5, :escape_html => true, :ugly => true }

get '/' do
  haml :index
end

post '/' do
  user_code = params['user_code_textarea']
  @trace = JSON.dump(get_trace_for(user_code))
  haml :index
end
