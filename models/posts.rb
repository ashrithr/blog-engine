require 'time'

# Sessions will be managed in mongodb
class PostsDAO
  attr_accessor :db, :posts

  def initialize(database)
    @db = database
    @posts = database["posts"]
  end

  # inserts blog entry and returns a permalink for the entry
  def insert_entry(title, post, tags_array, author)
    puts "Inserting blog entry with title: #{title} and author: #{author}"

    # fix up the permalink to not include whitespace
    permalink = title.downcase.gsub(/[^a-z0-9]+/, '_')

    # Build a new post
    post = {
      'title' => title,
      'author' => author,
      'body' => post,
      'permalink' => permalink,
      'tags' => tags_array,
      'comments' => [],
      'date' => Time.now.utc
    }

    begin
      @posts.insert(post)
      puts "Inserting the post"
    rescue
      puts "Error inserting post"
      puts "Unexpected Error: #{$!}"
    end

    permalink
  end

  # returns an array of num_posts posts, reverse ordered
  def get_posts(num_posts)
    cursor = []
    cursor = @posts.find.limit(num_posts)

    posts = []

    cursor.each do |post|
      posts << {
        'title' => post['title'],
        'body' => post['body'],
        'post_date' => post['date'],
        'permalink' => post['permalink'],
        'author' => post['author'],
        'tags' => post['tags'],
        'comments' => post['comments']
      }
    end

    posts
  end

  # find a post corresponding to a particular permalink
  def get_post_by_permalink(permalink)
    @posts.find_one({'permalink' => permalink})
  end

  # add a comment to a particular blog post
  def add_comment(permalink, name, email, body)
    comment = {'author' => name, 'body' => body}
    comment['email'] = email unless email.empty?

    begin
      query = {'permalink' => permalink}
      post = @posts.find_one(query)
      comments = post['comments']
      comments << comment
      @posts.save(post)
    rescue
      puts "Could not update the collection, error"
      puts "Unexpected Error, #{$!}"
    end
  end
end