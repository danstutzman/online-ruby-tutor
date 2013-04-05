require 'sinatra'
require 'pry'
require 'json'
require 'haml'
require 'omniauth'
require 'omniauth-google-oauth2'
require 'yaml'
require 'erubis'
require 'tilt'
require './get_trace_for.rb'

config_path = File.join(File.dirname(__FILE__), 'config.yaml')
CONFIG = YAML.load_file(config_path)

exercises_path = File.join(File.dirname(__FILE__), 'exercises.yaml')
EXERCISES = YAML.load_file(exercises_path)

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

get '/' do
  user_code = ''
  @traces = get_trace_for_cases(user_code, [{}])
  @methods = load_methods
  @word_to_method_indexes = load_word_to_method_indexes(@methods)
  haml :index
end

post '/' do
  user_code = params['user_code_textarea']
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

match '/exercise/:exercise_num' do
  if authenticated?
    @exercise = EXERCISES[params['exercise_num'].to_i]
    halt(404, 'Exercise not found') if @exercise.nil?

    user_code = params['user_code_textarea'] || ''
    cases_given = @exercise['cases'].map { |_case| _case['given'] || {} }
    @traces = get_trace_for_cases(user_code, cases_given)
    @methods = load_methods
    @word_to_method_indexes = load_word_to_method_indexes(@methods)
    haml :index
  else
    haml :login
  end
end
