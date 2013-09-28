require 'sinatra'

require File.join(File.dirname(__FILE__) + '/models/sessions')
require File.join(File.dirname(__FILE__) + '/models/users')
require File.join(File.dirname(__FILE__) + '/models/posts')

class App < Sinatra::Base

  before do
    # Mongo Connection
    connection = MongoClient.new("localhost", 27017)
    database = connection.db("blog")

    # Models
    @users = UserDAO.new(database)
    @sessions = SessionDAO.new(database)
    @posts = PostsDAO.new(database)

    # Session Timeout
    @@expiration_date = Time.now + (60 * 2)
  end

  get '/' do
    cookie = request.cookies['user_session'] || nil
    username = @sessions.get_username(cookie)
    # even if there is no user logged in, we can show the blog
    posts = @posts.get_posts(10)

    erb :index, :locals => {:username => username, :posts => posts}
  end

  get '/post/:permalink' do |permalink|
    cookie = request.cookies['user_session']
    username = @sessions.get_username(cookie)
    puts "about to query on permalink = #{permalink}"
    post = @posts.get_post_by_permalink(permalink)
    if post
      erb :entry_template,
          :layout => :layout_post,
          :locals => {
            :post => post,
            :username => username, 
            :errors => ""
          }
    else
      redirect '/post_not_found'  
    end
  end

  post '/newcomment' do
    name = params[:commentName]
    email = params[:commentEmail]
    body = params[:commentBody]
    permalink = params[:permalink]

    post = @posts.get_post_by_permalink(permalink)
    cookie = request.cookies['user_session']
    username = @sessions.get_username(cookie)

    unless post
      redirect '/post_not_found'
    end

    if name == '' or body == ''
      errors = "Post must contain your name and an acutal comment"
      return erb  :entry_template, 
                  :layout => :layout_post,
                  :locals => {
                    :post => post,
                    :username => username,
                    :errors => errors
                  }
    else
      @posts.add_comment(permalink, name, email, body)
      redirect "/post/#{permalink}"
    end
  end

  get '/newpost' do
    cookie = request.cookies['user_session']
    username = @sessions.get_username(cookie)

    unless username
      redirect '/login'
    end

    erb :newpost, 
        :locals => {
          :username => username,
          :errors => ''
        }
  end

  post '/newpost' do
    title = params[:subject]
    post = params[:body]
    tags = params[:tags]

    cookie = request.cookies['user_session']
    username = @sessions.get_username(cookie)

    unless username
      redirect '/login'
    end

    if title == '' or post == ''
      errors = "Post must contain a title and blog entry"
      return erb  :newpost,
                  :locals => {
                    :username => username,
                    :errors => errors
                  }
    else
      tags_array = tags.split(',')
      permalink = @posts.insert_entry(title, post, tags_array, username)
      redirect "/post/#{permalink}"
    end

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
          # :expires => @@expiration_date,
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

  get '/post_not_found' do
    "Error: Sorry, post not found"
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
          # :expires => @@expiration_date,
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