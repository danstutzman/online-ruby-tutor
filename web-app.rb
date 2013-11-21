require 'sinatra'
require 'json'
require 'omniauth'
require 'omniauth-google-oauth2'
require 'yaml'
require 'erubis'
require 'tilt'
require 'sass'
require 'haml'
require 'coffee_script'
require 'active_record'
require 'airbrake'
require 'net/http'
require './get_trace_for.rb'

config_path = File.join(File.dirname(__FILE__), 'config.yaml')
if File.exists?(config_path)
  CONFIG = YAML.load_file(config_path)
  env = ENV['RACK_ENV'] || 'development'
  if env == 'production'
    set :static_cache_control, [:public, :max_age => 300]
    set :sass, { :style => :compressed }
    Airbrake.configure do |config|
      config.api_key = CONFIG['AIRBRAKE_API_KEY']
      config.ignore << 'Sinatra::NotFound'
    end
  else
    set :port, 4001
    set :static_cache_control, [:public, :no_cache]
    set :sass, { :style => :compact }
  end
  ActiveRecord::Base.establish_connection(CONFIG['DATABASE_PARAMS'][env])
  ActiveRecord::Base.logger = Logger.new(STDOUT)
else # for Heroku, which doesn't support creating config.yaml
  CONFIG = {}
  missing = []
  %w[GOOGLE_KEY GOOGLE_SECRET COOKIE_SIGNING_SECRET AIRBRAKE_API_KEY].each do
    |key| CONFIG[key] = ENV[key] or missing.push key
  end
  CONFIG['STUDENT_CHECKLIST_HOSTNAME'] = { 'production' => ENV['STUDENT_CHECKLIST_HOSTNAME'] } or missing.push 'STUDENT_CHECKLIST_HOSTNAME'
  if missing.size > 0
    raise "Missing config.yaml and ENV keys #{missing.join(', ')}"
  end

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
end

set :public_folder, 'public'
set :haml, { :format => :html5, :escape_html => true, :ugly => true }

STUDENT_CHECKLIST_HOSTNAME = CONFIG['STUDENT_CHECKLIST_HOSTNAME'][env]

use Rack::Session::Cookie, {
  :key => 'rack.session',
  :secret => CONFIG['COOKIE_SIGNING_SECRET'],
}

use OmniAuth::Builder do
  provider :google_oauth2, CONFIG['GOOGLE_KEY'], CONFIG['GOOGLE_SECRET'], {
    :scope => 'https://www.googleapis.com/auth/plus.me',
    :access_type => 'online',
  }
end

use Airbrake::Sinatra

class User < ActiveRecord::Base
end

class Save < ActiveRecord::Base
end

class RootSave < ActiveRecord::Base
end

class Exercise < ActiveRecord::Base
  if ENV['STUDENT_CHECKLIST_DATABASE_URL'] # Heroku
    db = URI.parse(ENV['STUDENT_CHECKLIST_DATABASE_URL'])
    establish_connection({
      :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
      :host     => db.host,
      :port     => db.port,
      :username => db.user,
      :password => db.password,
      :database => db.path[1..-1],
      :encoding => 'utf8',
    })
  else
    establish_connection(CONFIG['DATABASE_PARAMS'][
      "student_checklist_#{ENV['RACK_ENV'] || 'development'}"])
  end
end

def authenticated?
  if session[:google_plus_user_id]
    @current_user =
      User.find_by_google_plus_user_id(session[:google_plus_user_id])
  else
    @current_user = nil
  end
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

def load_i_have_to_method_indexes(methods)
  word_to_method_indexes = {}
  methods.each_with_index do |method, method_index|
    method['inputs'].split(', ').each do |i_have|
      if word_to_method_indexes[i_have].nil?
        word_to_method_indexes[i_have] = []
      end
      word_to_method_indexes[i_have].push method_index
    end
  end
  word_to_method_indexes
end

def load_i_need_to_method_indexes(methods)
  word_to_method_indexes = {}
  methods.each_with_index do |method, method_index|
    i_need = method['output']
    if word_to_method_indexes[i_need].nil?
      word_to_method_indexes[i_need] = []
    end
    word_to_method_indexes[i_need].push method_index
  end
  word_to_method_indexes
end

helpers do
  def create_javascript_var(var_name, var_value)
    js = "var #{var_name} = {"
    var_value.each do |key, value|
      js += "#{key.inspect}: #{value.inspect},"
    end
    js += "1: 1 };"
    js
  end
end

SAMPLE_CODE =
"def binary_search(haystack, needle)
  mid = haystack.size / 2
  if needle < haystack[mid]
    __return__ = binary_search(haystack[0..(mid - 1)], needle)
  elsif needle > haystack[mid]
    __return__ = (mid + 1) + binary_search(haystack[(mid + 1)..-1], needle)
  else
    __return__ = mid
  end
end
puts binary_search([4, 9, 12, 13, 17, 18], 17)
"

get '/' do
  if session[:root_save_id]
    @user_code = RootSave.find(session[:root_save_id]).code || ''
  end
  if @user_code.nil? || @user_code == ''
    @user_code = SAMPLE_CODE
  end
  @traces = get_trace_for_cases('', @user_code, [{}])
  @methods = load_methods
  @word_to_method_indexes = load_word_to_method_indexes(@methods)
  @i_have_to_method_indexes = load_i_have_to_method_indexes(@methods)
  @i_need_to_method_indexes = load_i_need_to_method_indexes(@methods)
  haml :index
end

post '/' do
  if params['logout']
    session[:google_plus_user_id] = nil
    redirect '/'
  end
  @user_code = params['user_code_textarea']
  if session[:root_save_id]
    RootSave.update_all("is_current = 'f'", { id: session[:root_save_id] })
  end
  new_root_save = RootSave.create({
    :user_id      => @current_user ? @current_user.id : nil,
    :is_current   => true,
    :code         => @user_code,
  })
  session[:root_save_id] = new_root_save.id
  @traces = get_trace_for_cases('', @user_code, [{}])
  @methods = load_methods
  @word_to_method_indexes = load_word_to_method_indexes(@methods)
  @i_have_to_method_indexes = load_i_have_to_method_indexes(@methods)
  @i_need_to_method_indexes = load_i_need_to_method_indexes(@methods)
  haml :index
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
    original_destination = session[:original_destination]
    session[:original_destination] = nil
    redirect original_destination || "/"
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

match '/exercise/:task_id' do |task_id|
  if !authenticated?
    session[:original_destination] = request.path_info
    redirect '/login'
  end

  if params['logout']
    session[:google_plus_user_id] = nil
    redirect '/'
  end

  exercise = Exercise.find_by_task_id(task_id)
  halt(404, 'Exercise not found') if exercise.nil?
  halt(404, 'No code for that exercise') if exercise.yaml.nil?
  begin
    @exercise = YAML.load(exercise.yaml)
  rescue Psych::SyntaxError => e
    halt 500, "#{e.class}: #{e} with #{exercise.yaml}"
  end

  if request.get?
    old_record =
      Save.where({
        :user_id     => @current_user.id,
        :task_id     => task_id,
        :is_current  => true
      }).first
    if old_record
      @user_code = old_record.code
    else
      @user_code = @exercise['starting_code'] || ''
    end
  elsif request.post?
    if params['action'] == 'save'
      @user_code = params['user_code_textarea']
      Save.transaction do
        Save.update_all("is_current = 'f'", {
          :user_id      => @current_user.id,
          :task_id      => task_id,
          :is_current   => true
        })
        Save.create({
          :user_id      => @current_user.id,
          :task_id      => task_id,
          :is_current   => true,
          :code         => @user_code,
        })
      end
    elsif params['action'] == 'restore'
      Save.where({
        :user_id      => @current_user.id,
        :task_id      => task_id,
        :is_current   => true
      }).update_all(:is_current => false)
      redirect "/exercise/#{task_id}"
    end
  end

  cases_given =
    (@exercise['cases'] || [{}]).map { |_case| _case['given'] || {} }
  @traces = get_trace_for_cases('', @user_code, cases_given)

  num_passed = 0
  num_failed = 0
  @traces.each_with_index do |trace, i|
    last = trace['trace'].last || {}
    if last['exception_msg']
      trace['test_status'] = 'ERROR'
    elsif @exercise['cases'].nil? || @exercise['cases'][i].nil?
      # cases don't apply to this exercise
    elsif expected_return = @exercise['cases'][i]['expected_return']
      trace['test_status'] =
        (trace['returned'] == expected_return) ? 'PASSED' : 'FAILED'
    elsif expected_stdout = @exercise['cases'][i]['expected_stdout']
      trace['test_status'] =
        ((last['stdout'] || '').chomp == expected_stdout.chomp) ?
        'PASSED' : 'FAILED'
    end
    num_passed += 1 if trace['test_status'] == 'PASSED'
    num_failed += 1 if trace['test_status'] == 'FAILED' ||
                       trace['test_status'] == 'ERROR'
  end

  if (task_id[0] == 'C' && num_passed > 0 && num_failed == 0) ||
     (task_id[0] == 'D')
    uri = URI.parse("http://#{STUDENT_CHECKLIST_HOSTNAME}/mark_task_complete")
    data = {
      'google_plus_user_id' => @current_user.google_plus_user_id,
      'task_id'             => task_id,
    }
    begin
      Net::HTTP.post_form(uri, data)
    rescue Errno::ECONNREFUSED => e
      # Heroku apparently doesn't allow this
    end
  end

  @methods = load_methods
  @word_to_method_indexes = load_word_to_method_indexes(@methods)
  @i_have_to_method_indexes = load_i_have_to_method_indexes(@methods)
  @i_need_to_method_indexes = load_i_need_to_method_indexes(@methods)

  haml :index
end

get '/css/application.css' do
  sass 'sass/application'.intern
end

get '/js/application.js' do
  coffee 'coffee/application'.intern
end

get '/users' do
  if !authenticated?
    session[:original_destination] = request.path_info
    redirect '/login'
  elsif !@current_user.is_admin
    redirect '/auth/failure?message=You+must+be+an+admin+to+edit+users'
  end

  @users = User.order('id')
  haml :users
end

post '/users' do
  if !authenticated?
    session[:original_destination] = request.path_info
    redirect '/login'
  elsif !@current_user.is_admin
    redirect '/auth/failure?message=You+must+be+an+admin+to+edit+users'
  end

  fields = %w[id first_name last_name google_plus_user_id is_admin email]

  User.transaction do
    User.order('id').each do |user|
      fields.each do |field|
        user[field] = params["#{field}_#{user.id}"]
      end
      user['google_plus_user_id'] = nil if user['google_plus_user_id'] == ''
      user.save!
    end

    if (params["first_name_"] || '') != ''
      user = User.new
      fields.each do |field|
        user[field] = params["#{field}_"]
      end
      user['google_plus_user_id'] = nil if user['google_plus_user_id'] == ''
      user.save!
    end
  end

  redirect '/users'
end

match '/saves/:task_id' do |task_id|
  if !authenticated?
    session[:original_destination] = request.path_info
    redirect '/login'
  end

  @task_id = task_id
  @saves = Save.where(:is_current => true, :task_id => task_id).order(:id)
  haml :saves
end

get '/ping' do
  User.first
  "OK\n"
end

after do
  ActiveRecord::Base.clear_active_connections!
end

# Remove ActiveSupport's monkey-patching of const_missing, because
# otherwise missing-constant errors turn into too-many-instruction errors.
ActiveSupport::Dependencies::ModuleConstMissing.exclude_from(Module)
