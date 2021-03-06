require 'carrierwave/mongoid'

class User
  include Mongoid::Document
  include Mongoid::Timestamps

  PRIVATE_FIELDS = [:password_salt, :password_hash]

  PROTECTED_FIELDS = []

  PUBLIC_FIELD = [:username, :realname, :email, :password, :avatar, :bio, :url, :location,
    :setting_privacy_jot, :setting_privacy_location, :setting_privacy_kudos, :setting_auto_shorten_url,
    :setting_auto_complete, :connection_facebook_user_id, :connection_facebook_user_name]

  NON_PUBLIC_FIELDS = PRIVATE_FIELDS

  UPDATEABLE_FIELDS = PROTECTED_FIELDS + PUBLIC_FIELD

  RELATION_PUBLIC = [:connections]

  RELATION_PUBLIC_DETAIL = []

  attr_accessor :password

  field :realname, type: String
  field :username, type: String
  field :email, type: String
  field :password_salt, :type => String
  field :password_hash, :type => String
  field :avatar, :type => String
  field :token, type: String
  field :bio, type: String, :default => ''
  field :url, type: String, :default => ''
  field :location, type: String, :default => ''
  
  field :facebook_id, :type => String
  field :twitter_id, :type => String

  field :setting_privacy_jot, :type => String, :default => 'everyone'
  field :setting_privacy_location, :type => String, :default => 'everyone'
  field :setting_privacy_kudos, :type => String, :default => 'everyone'
  field :setting_auto_shorten_url, :type => String, :default => 'always'
  field :setting_auto_complete, :type => String, :default => 'always'
  
  mount_uploader :avatar, AvatarUploader, :mount_on => :avatar

  has_many :jots
  has_and_belongs_to_many :tags
  has_and_belongs_to_many :jot_favorites, :class_name => "Jot", :inverse_of => :user_favorites
  has_and_belongs_to_many :jot_thumbsup, :class_name => "Jot", :inverse_of => :user_thumbsup
  has_and_belongs_to_many :jot_thumbsdown, :class_name => "Jot", :inverse_of => :user_thumbsdown
  has_and_belongs_to_many :jot_mentioned, :class_name => "Jot", :inverse_of => :user_mentioned
  has_many :message_sent, :class_name => "Message", :inverse_of => :sender
  has_many :message_received, :class_name => "Message", :inverse_of => :receiver
  has_many :comments
  has_many :connections
  has_many :nests
  has_many :clips
  has_and_belongs_to_many :disfollowed_jots, :class_name => "Jot"

  validates_format_of :url, :with => URI::regexp(%w(http https)), :allow_nil => true, :allow_blank => true
  validates_format_of :email, :with => /\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b/
  validates_format_of :username, :with => /^[A-Za-z0-9.\d_]+$/, :message => "can only be alphanumeric, dot and number with no spaces"
  validates_presence_of :realname, :username, :email
  validates_length_of :username, :minimum => 5
  validates_length_of :password, :minimum => 6, :allow_nil => true
  validates_uniqueness_of :username, :email, :case_sensitive => false

  validates_inclusion_of :setting_privacy_jot, :in => ["everyone", "friends", "hide"], :allow_nil => true
  validates_inclusion_of :setting_privacy_location, :in => ["everyone", "friends", "hide"], :allow_nil => true
  validates_inclusion_of :setting_privacy_kudos, :in => ["everyone", "friends", "hide"], :allow_nil => true
  validates_inclusion_of :setting_auto_shorten_url, :in => ["always", "ask", "never"], :allow_nil => true
  validates_inclusion_of :setting_auto_complete, :in => ["always", "ask", "never"], :allow_nil => true

  before_save :set_secure_password

  def self.get(parameters = {})
    parameters = parameters.to_hash rescue {}
    
    if parameters[:id].present?
      data = self.find parameters[:id]
    else
      data = self.all
    end

    JsonizeHelper.format({:content => data}, {
        :except => NON_PUBLIC_FIELDS + Connection::NON_PUBLIC_FIELDS,
        :include => RELATION_PUBLIC
      })
  rescue
    JsonizeHelper.format :failed => true, :error => 'User not found'
  end

  def get_my_attributes

    JsonizeHelper.format({:content => self}, {
        :except => NON_PUBLIC_FIELDS,
        :include => RELATION_PUBLIC
      })
  end

  def set_my_attributes(parameters)
    parameters.keep_if {|key, value| UPDATEABLE_FIELDS.include? key }

    if self.update_attributes parameters
      self.reload
      self.get_my_attributes
    else
      self.reload
      return JsonizeHelper.format :failed => true, :error => "Update was not made", :errors => self.errors.to_a
    end
  end

  def current_user_set_jot(parameters)
    parameters.keep_if {|key, value| Jot::UPDATEABLE_FIELDS.include? key }
    
    jot_data = self.jots.new parameters
    jot_data.save

    if jot_data.errors.any?
      return JsonizeHelper.format :failed => true, :error => "Jot was not made", :errors => jot_data.errors.to_a
    else
      return JsonizeHelper.format({:notice => "Jot Successfully Made", :content => jot_data}, {
          :except => Jot::NON_PUBLIC_FIELDS,
          :include => Jot::RELATION_PUBLIC
        })
    end
  end

  def current_user_unset_jot(jot_id, user_id)
    jot = Jot.find(jot_id)

    if jot.user_id == user_id
      jot.destroy
      JsonizeHelper.format :notice => "Jot is deleted"
    else
      JsonizeHelper.format :failed => true, :error => "You are not authorized to delete this jot"
    end

  rescue
    JsonizeHelper.format :failed => true, :error => "Jot doesn't exist"
  end

  def current_user_subcribe_tags(string)
    data = Twitter::Extractor.extract_hashtags(string)
    
    new_tags = []

    data.uniq.each do |tag|
      new_tags.push Tag.find_or_create_by({:name => tag.downcase})
    end

    self.tags.concat new_tags
    self.reload

    new_tags
  end

  def current_user_get_jot(parameters)

    if parameters[:timestamp] == 'now'
      params_timestamp = Time.now()
    else
      params_timestamp = Time.iso8601(parameters[:timestamp])
    end
   
    data = Jot.before_the_time(params_timestamp, parameters[:per_page]).disclude_these_jots(self.disfollowed_jot_ids).order_by_default

    JsonizeHelper.format({
        :content => data
      },
      {
        :except => Jot::NON_PUBLIC_FIELDS,
        :include => Jot::RELATION_PUBLIC
      }
    )
  rescue
    JsonizeHelper.format :failed => true, :error => 'Jot not found'
  end

  def current_user_get_favorite_jot(limit)
    jot = self.jot_favorites
    jot = jot.limit(limit.to_i) if limit.present?

    JsonizeHelper.format(
      {:content => jot},
      {:except => Jot::NON_PUBLIC_FIELDS, :include => Jot::RELATION_PUBLIC}
    )
  rescue
    return JsonizeHelper.format :failed => true, :error => "Jot was not found"
  end

  def current_user_set_favorite_jot(jot_id)
    jot = Jot.find(jot_id)

    unless jot.user_favorites.include? self
      jot.user_favorites.push self

      jot.tags.each do |tag|
        tag.update_attribute 'meta_favorites', tag.meta_favorites + 1
      end
    else
      jot.user_favorites.delete self

      jot.tags.each do |tag|
        tag.update_attribute 'meta_favorites', tag.meta_favorites - 1
      end
    end

    jot.reload

    JsonizeHelper.format(
      {:content => jot},
      {:except => Jot::NON_PUBLIC_FIELDS, :include => Jot::RELATION_PUBLIC}
    )
  rescue
    return JsonizeHelper.format :failed => true, :error => "Jot was not found"
  end

  def current_user_set_thumbs_up_jot(jot_id)
    jot = Jot.find(jot_id)

    unless jot.user_thumbsup.include? self
      jot.user_thumbsup.push self

      jot.tags.each do |tag|
        tag.update_attribute 'meta_thumbups', tag.meta_thumbups + 1
      end
    end

    if jot.user_thumbsdown.include? self
      jot.user_thumbsdown.delete self

      jot.tags.each do |tag|
        tag.update_attribute 'meta_thumbdowns', tag.meta_thumbdowns - 1
      end
    end
    
    jot.reload

    JsonizeHelper.format(
      {
        :notice => "Jot was thumbed up",
        :content => jot
      },
      {:except => Jot::NON_PUBLIC_FIELDS, :include => Jot::RELATION_PUBLIC}
    )    
  rescue
    JsonizeHelper.format :failed => true, :error => "Jot was not found"
  end

  def current_user_set_thumbs_down_jot(jot_id)
    jot = Jot.find(jot_id)  

    unless  jot.user_thumbsdown.include? self
      jot.user_thumbsdown.push self
      
      jot.tags.each do |tag|
        tag.update_attribute 'meta_thumbdowns', tag.meta_thumbdowns + 1
      end
    end

    if jot.user_thumbsup.include? self
      jot.user_thumbsup.delete self

      jot.tags.each do |tag|
        tag.update_attribute 'meta_thumbups', tag.meta_thumbups - 1
      end
    end

    jot.reload

    JsonizeHelper.format(
      {
        :notice => "Jot was thumbed down",
        :content => jot
      },
      {:except => Jot::NON_PUBLIC_FIELDS, :include => Jot::RELATION_PUBLIC}
    )
  rescue
    JsonizeHelper.format :failed => true, :error => "Jot was not found"
  end

  def current_user_set_rejot(jot_id)
    jot = Jot.find(jot_id)

    rejot = jot.clone
    rejot.user = self
    rejot.save

    jot.rejots.push rejot

    JsonizeHelper.format :content => rejot
  rescue
    JsonizeHelper.format :failed => true, :error => "Jot was not found"
  end

  def current_user_set_jot_comments(jot_id, parameters)

    parameters.keep_if {|key, value| Comment::UPDATEABLE_FIELDS.include? key }

    data = Jot.find(jot_id)
    data_comment = data.comments.new parameters
    data_comment.user = self
    
    if data_comment.save
      JsonizeHelper.format({:content => data_comment, :query => {:total => data.comments.length}}, {:except => Comment::NON_PUBLIC_FIELDS, :include => Comment::RELATION_PUBLIC})
    else
      JsonizeHelper.format :failed => true, :error => "Comment was not made", :errors => data.errors.to_a
    end
  rescue
    JsonizeHelper.format :failed => true, :error => "Jot was not found"
  end

  def current_user_set_connections(parameters)
    parameters.keep_if {|key, value| Connection::UPDATEABLE_FIELDS.include? key }

    conn = nil;

    if parameters[:provider] == 'twitter'

      Connection.auth_twitter parameters[:provider_user_token], parameters[:provider_user_secret] do |success, data|
        
        if success === true
          conn = self.set_conn_by_twitter(data['id'], parameters[:provider_user_token], parameters[:provider_user_secret], data['screen_name'])
        else
          return JsonizeHelper.format(:error => "aw hell no, can\'t connect to twitter", :failed => true)
        end
      end
    elsif parameters[:provider] == 'facebook'

      Connection.auth_facebook parameters[:provider_user_token] do |success, data|

        if success === true
          conn = self.set_conn_by_facebook(data['id'], parameters[:provider_user_token], data['username'])
        else
          return JsonizeHelper.format(:error => "aw hell no, can\'t connect to facebook", :failed => true)
        end
      end
    end

    if conn.present? and conn.errors.any?
      return JsonizeHelper.format :failed => true, :error => "Connections was not made", :errors => conn.errors.to_a
    elsif not conn.nil? or not conn.errors.any?
      return JsonizeHelper.format({:notice => 'Data Connected', :content => conn}, {:except => Connection::NON_PUBLIC_FIELDS, :include => Connection::RELATION_PUBLIC})
    end
  end

  def current_user_unset_connections(id)
    data = Connection.find(id).destroy
    JsonizeHelper.format({:content => data}, {:except => Connection::NON_PUBLIC_FIELDS, :include => Connection::RELATION_PUBLIC})
  rescue
    JsonizeHelper.format :failed => true, :error => "Connection was not found"
  end

  def current_user_connections(parameters)
    data = self.connections.order_by_default
    
    if parameters[:provider].present? and parameters[:allowed].present?
      data = data.find_by_provider(parameters[:provider]).find_allowed
    elsif parameters[:provider].present?
      data = data.find_by_provider(parameters[:provider])
    end

    JsonizeHelper.format({:content => data}, {:except => Connection::NON_PUBLIC_FIELDS, :include => Connection::RELATION_PUBLIC})
  end

  def current_user_reset_connections(id, parameters)
    parameters.keep_if {|key, value| Connection::UPDATEABLE_FIELDS.include? key }

    data = Connection.find id

    data.update_attributes parameters
    data.reload
    JsonizeHelper.format({:content => data}, {:except => Connection::NON_PUBLIC_FIELDS, :include => Connection::RELATION_PUBLIC})
  rescue
    JsonizeHelper.format :failed => true, :error => "Connection was not found"
  end

  def set_nest(parameters)
    parameters.keep_if {|key, value| Nest::UPDATEABLE_FIELDS.include? key }

    data = self.nests.new parameters

    if data.save
      return JsonizeHelper.format({:notice => "Nest Successfully Made", :content => data}, {
          :except => Nest::NON_PUBLIC_FIELDS,
          :include => Nest::RELATION_PUBLIC
        })
    else
      return JsonizeHelper.format :failed => true, :error => "Nest was not made", :errors => data.errors.to_a
    end
  end

  def get_nest(parameters)
    data = self.nests.order_by_default

    return JsonizeHelper.format({:content => data}, {
        :except => Nest::NON_PUBLIC_FIELDS,
        :include => Nest::RELATION_PUBLIC
      })
  end

  def unset_nest(nest_id)
    data = self.nests.find(nest_id).destroy

    return JsonizeHelper.format :notice => "Nest Successfully Deleted"
  rescue
    JsonizeHelper.format :failed => true, :error => "Nest was not found"
  end

  def reset_nest(nest_id, parameters)
    parameters.keep_if {|key, value| Nest::UPDATEABLE_FIELDS.include? key }

    data = self.nests.find nest_id

    data.update_attributes parameters

    if data.errors.any?
      JsonizeHelper.format :failed => true, :error => "Nest was not made", :errors => data.errors.to_a
    else
      data.reload
      JsonizeHelper.format :content => data
    end

  rescue
    JsonizeHelper.format :failed => true, :error => "Nest was not found"
  end


  def set_nest_item(parameters)
    
    parameters.keep_if {|key, value| NestItem::UPDATEABLE_FIELDS.include? key }

    data = self.nests.find parameters[:nest_id]
    data_item = data.nest_items.new :name => parameters[:name]

    data_item.tag_ids.concat parameters[:tags].flatten.uniq if parameters[:tags].present?

    data_item.save

    if data_item.errors.any?
      JsonizeHelper.format :failed => true, :error => data_item.errors.to_a
    else
      JsonizeHelper.format :content => data_item
    end
  rescue
    JsonizeHelper.format :failed => true, :error => "Nest was not found"
  end

  def current_user_get_message
    message = Message.any_of({ :sender_id => self.id }, { :receiver_id => self.id }).desc(:updated_at)

    JsonizeHelper.format :content => message
  end

  def current_user_set_message(receiver, subject, content)
    user_receiver = User.where(:username => receiver).first

    if user_receiver.present? and receiver != self.username
      self.message_sent.create! :receiver => user_receiver, :subject => subject, :content => content
      JsonizeHelper.format :notice => "Your message have been sent"
    else
      error_message = receiver == self.username ? "You can't send message to yourself" : "The user doesn't exist"
      JsonizeHelper.format :failed => true, :error => error_message
    end

  rescue
    JsonizeHelper.format :failed => true, :error => "Your message cannot be sent, please try again"
  end

  def current_user_set_message_mark_read(message_id)
    message = Message.find(message_id)

    message.update_attributes :read => true

    JsonizeHelper.format :notice => "Your message is marked"
  rescue
    JsonizeHelper.format :failed => true, :error => "Your message cannot be found"
  end

  def current_user_unset_message(message_id)
    message = Message.find(message_id)

    message.destroy

    JsonizeHelper.format :notice => "Your message is deleted"

  rescue
    JsonizeHelper.format :failed => true, :error => "Your message could not be found"
  end

  def current_user_set_message_reply(message_id, content)
    message = Message.find(message_id)

    parameters = {:subject => "Re: #{message.subject}",
      :from => self.username,
      :to => message.to,
      :content => content,
      :original_message => message}

    message.replies.create! parameters
    message.update_attributes :updated_at => Time.now, :read => false

    JsonizeHelper.format :notice => "You have replied"
  rescue
    JsonizeHelper.format :failed => true, :error => "Something went wrong, please try again"
  end

  def current_user_get_message_reply(message_id)
    messages = Message.find(message_id).replies.asc(:created_at)

    JsonizeHelper.format :content => messages
  rescue
    JsonizeHelper.format :failed => true, :error => "Message not found, please try again"
  end

  def set_clip(parameters)
    parameters.keep_if {|key, value| Clip::UPDATEABLE_FIELDS.include? key }

    data = self.clips.new parameters
    data.save
    JsonizeHelper.format :content => data
  end

  def current_user_set_disfollowed_jot(parameters)
    self.disfollowed_jots.push Jot.find(parameters[:disfollowed_jot_id])
    self.reload

    JsonizeHelper.format({:content => self}, {
        :except => NON_PUBLIC_FIELDS,
        :include => RELATION_PUBLIC
      })
  rescue
    JsonizeHelper.format :failed => true, :error => "Jot not found, please try again"
  end

  def set_conn_by_facebook(fb_userid, fb_user_token, fb_username = nil)
    data = self.connections.new :provider => Connection::FACEBOOK_FLAG, :provider_user_id => fb_userid,  :provider_user_name => fb_username || fb_userid,
      :provider_user_token => fb_user_token
    data.save
  end

  def set_conn_by_twitter(tw_userid, tw_user_token, tw_user_secret, tw_username = nil)
    data = self.connections.new :provider => Connection::TWITTER_FLAG, :provider_user_id => tw_userid, :provider_user_name => tw_username || tw_userid,
      :provider_user_token => tw_user_token,
      :provider_user_secret => tw_user_secret
    data.save
  end

  def self.find_by_twitter_conn(tw_user_id)
    conn = Connection.where(:provider => Connection::TWITTER_FLAG, :provider_user_id => tw_user_id).first
    conn.user if conn.present?
  end

  def self.find_by_facebook_conn(fb_user_id)
    conn = Connection.where(:provider => Connection::FACEBOOK_FLAG, :provider_user_id => fb_user_id).first
    conn.user if conn.present?
  end

  protected

  def set_secure_password
    if self.password.present?
      encrypted_string_data = EncryptStringHelper.encrypt_string(password)
      self.password_salt = encrypted_string_data[:salt]
      self.password_hash = encrypted_string_data[:hash]
    end
  end
end
