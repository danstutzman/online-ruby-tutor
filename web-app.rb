require 'sinatra'
require 'pry'
require 'json'
require 'haml'
require 'omniauth'
require 'omniauth-google-oauth2'
require 'yaml'
require 'erubis'
require 'tilt'
require 'active_record'
require './get_trace_for.rb'

config_path = File.join(File.dirname(__FILE__), 'config.yaml')
CONFIG = YAML.load_file(config_path)
env = ENV['RACK_ENV'] || 'development'
if env == 'development'
  db_params = CONFIG['DATABASE_PARAMS'][env]
  ActiveRecord::Base.establish_connection(db_params)
else
  # load it in unicorn.rb
end
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.formatter = proc { |sev, time, prog, msg| "#{msg}\n" }

exercises_path = File.join(File.dirname(__FILE__), 'exercises.yaml')
EXERCISES = YAML.load_file(exercises_path)

class User < ActiveRecord::Base
end

class Save < ActiveRecord::Base
end

use Rack::Session::Cookie, {
  :key => 'rack.session',
  :secret => CONFIG['COOKIE_SIGNING_SECRET'],
}

set :port, 4567
set :public_folder, 'public'
set :static_cache_control, [:public, :no_cache]
set :haml, { :format => :html5, :escape_html => true, :ugly => true }

def authenticated?
  @current_user =
    User.find_by_google_plus_user_id(session[:google_plus_user_id])
end

def match(path, opts={}, &block)
  get(path, opts, &block)
  post(path, opts, &block)
end

def load_methods
  YAML::load_file('ruby_composer.yaml')
end

def load_word_to_method_indexes(methods)
  word_to_method_indexes = {}
  methods.each_with_index do |method, method_index|
    words = method.values.inject { |a, b| a += " #{b}" }.split(/[^a-z+=_*\/]/).reject { |s| s == '' }.sort.uniq
    words.each { |word|
      if word_to_method_indexes[word].nil?
        word_to_method_indexes[word] = []
      end
      word_to_method_indexes[word].push method_index
    }
  end
  word_to_method_indexes
end

before do
  if ['/auth/google_oauth2/callback', '/auth/failure', '/login'].include?(request.path_info)
    pass
  elsif !authenticated?
    redirect '/login'
  end
end

get '/' do
  @user_code = ''
  @traces = get_trace_for_cases(user_code, [{}])
  @methods = load_methods
  @word_to_method_indexes = load_word_to_method_indexes(@methods)
  haml :index
end

post '/' do
  @user_code = params['user_code_textarea']
  @traces = get_trace_for_cases(user_code, [{}])
  @methods = load_methods
  @word_to_method_indexes = load_word_to_method_indexes(@methods)
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
  session[:google_plus_user_id] = uid
  if authenticated?
    redirect "/"
  else
    session[:google_plus_user_id] = nil
    redirect "/auth/failure?message=Sorry,+you're+not+on+the+list.+Contact+dtstutz@gmail.com+to+be+added."
  end
end

get '/auth/failure' do
  @auth_failure_message = params['message']
  haml :login
end

get '/login' do
  haml :login
end

match '/exercise/:exercise_num' do
  @exercise = EXERCISES[params['exercise_num'].to_i]
  halt(404, 'Exercise not found') if @exercise.nil?

  if request.get?
    old_record =
      Save.where(:user_id => @current_user.id, :is_current => true).first
    @user_code = (old_record || Save.new).code || ''
  elsif request.post?
    @user_code = params['user_code_textarea']
    Save.transaction do
      Save.update_all("is_current = 'f'",
        { :user_id => @current_user.id, :is_current => true })
      Save.create({
        :user_id      => @current_user.id,
        :exercise_num => params['exercise_num'],
        :is_current   => true,
        :code         => @user_code,
      })
    end
  end

  cases_given = @exercise['cases'].map { |_case| _case['given'] || {} }
  @traces = get_trace_for_cases(@user_code, cases_given)
  @methods = load_methods
  @word_to_method_indexes = load_word_to_method_indexes(@methods)
  haml :index
end

post '/logout' do
  session[:google_plus_user_id] = nil
  redirect '/'
end

after do
  ActiveRecord::Base.clear_active_connections!
end
