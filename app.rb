require 'sinatra'

require File.join(File.dirname(__FILE__) + '/models/sessions')
require File.join(File.dirname(__FILE__) + '/models/users')

class App < Sinatra::Base

  before do
    # Mongo Connection
    connection = MongoClient.new("localhost", 27017)
    database = connection.db("blog")

    # Models
    @users = UserDAO.new(database)
    @sessions = SessionDAO.new(database)

    # Session Timeout
    @@expiration_date = Time.now + (60 * 2)
  end

  get '/' do
    cookie = request.cookies['user_session'] || nil
    @username = @sessions.get_username(cookie)
    erb :index
  end

  get '/signup' do
    erb :signup
  end

  get '/login' do
    erb :login, :locals => {:login_error => ''}
  end

  post '/login' do
    username = params[:username]
    password = params[:password]
    puts "user submitted #{username} with pass: #{password}"
    user_record = @users.validate_login(username, password)

    if user_record
      session_id = @sessions.start_session(user_record['_id'])
      redirect '/internal_error' unless session_id
      cookie = session_id
      response.set_cookie(
          'user_session', 
          :value => cookie, 
          :expires => @@expiration_date,
          :path => '/'
        )
      redirect '/welcome'
    else
      erb :login, :locals => {:login_error => 'Invalid Login'}
    end
  end

  get '/internal_error' do
    "Error: System has encounterd a DB error"
  end

  get '/logout' do
    cookie = request.cookies['user_session']
    @sessions.end_session(cookie)
    session.clear # clear the cookies on user logout
    redirect '/'

    "You are now logged out"
  end

  post '/signup' do
    username = params[:username]
    password = params[:password]
    email = params[:email]
    verify = params[:verify]
    @errors = {
      'username' => username, 
      'email' => email,
      'username_error' => '',
      'password_error' => '',
      'verify_error' => '',
      'email_error' => ''
    }
    if validate_signup(username, password, verify, email, @errors)
      unless @users.add_user(username, password, email)
        @errors['username_error'] = 'Username already exists, please choose another'
        return erb :signup # with errors
      end
      session_id = @sessions.start_session(username)
      response.set_cookie(
          'user_session', 
          :value => session_id, 
          :expires => @@expiration_date,
          :path => '/'
        )
      redirect '/welcome'
    else
      puts "user validation failed"
      erb :signup # with errors
    end
  end

  get '/welcome' do
    cookie = request.cookies['user_session']
    username = @sessions.get_username(cookie)
    if ! username
      puts "welcome: can't identify user...redirecting to signup"
      redirect '/'
    end
    erb :welcome, :locals => {:username => username}
  end

  def validate_signup(username, password, verify, email, errors)
    user_re = /^[a-zA-Z0-9_-]{3,20}$/
    pass_re = /^.{3,20}$/
    email_re = /^[\S]+@[\S]+\.[\S]+$/

    if ! user_re.match(username)
      errors['username_error'] = "invalid username. try just letters and numbers"
      return false
    end
    if ! pass_re.match(password)
      errors['password_error'] = "invalid password."
      return false
    end
    if password != verify
      errors['verify_error'] = "password must match"
      return false
    end
    if email != ''
      if ! email_re.match(email)
        errors['email_error'] = "invalid email address"
        return false        
      end
    end
    return true
  end
end