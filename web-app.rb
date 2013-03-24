require 'sinatra'
require 'pry'
require 'json'
require 'haml'
require 'omniauth'
require 'omniauth-google-oauth2'
require 'yaml'
require './get_trace_for.rb'

config_path = File.join(File.dirname(__FILE__), 'config.yaml')
CONFIG = YAML.load_file(config_path)

use Rack::Session::Cookie, {
  :key => 'rack.session',
  :secret => CONFIG['COOKIE_SIGNING_SECRET'],
}

set :port, 4567
set :public_folder, 'public'
set :static_cache_control, [:public, :no_cache]
set :haml, { :format => :html5, :escape_html => true, :ugly => true }

def authenticated?
  user_id = session[:google_plus_user_id]
  user_id && CONFIG['AUTHORIZED_GOOGLE_PLUS_UIDS'].include?(user_id)
end

get '/' do
  if authenticated?
    haml :index
  else
    haml :login
  end
end

post '/' do
  user_code = params['user_code_textarea']
  @trace = get_trace_for(user_code)
  haml :index
end

use OmniAuth::Builder do
  provider :google_oauth2, CONFIG['GOOGLE_KEY'], CONFIG['GOOGLE_SECRET'], {
    :scope => 'https://www.googleapis.com/auth/plus.me',
    :access_type => 'online',
  }
end

# Example callback:
#
# {"provider"=>"google_oauth2",
#  "uid"=>"112826277336975923063",
#  "info"=>{},
#  "credentials"=>
#   {"token"=>"ya29.AHES6ZRDLUipo8HB5wLy7MoO81vjath9i7Wx-4nI-duhXyE",
#    "expires_at"=>1363146592,
#    "expires"=>true},
#  "extra"=>{"raw_info"=>{"id"=>"112826277336975923063"}}}
#
get '/auth/google_oauth2/callback' do
  response = request.env['omniauth.auth']
  uid = response['uid']
  if CONFIG['AUTHORIZED_GOOGLE_PLUS_UIDS'].include?(uid)
    session[:google_plus_user_id] = uid
    redirect "/"
  else
    redirect "/auth/failure?message=Sorry,+you're+not+on+the+list.+Contact+dtstutz@gmail.com+to+be+added."
  end
end

get '/auth/failure' do
  @auth_failure_message = params['message']
  haml :login
end

# http://localhost:4567/auth/google_oauth2
