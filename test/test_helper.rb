require 'rubygems'
require 'pp'
require 'test/unit'
require 'shoulda'
require 'mocha'

$LOAD_PATH.unshift(File.dirname(__FILE__))
# $LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))
require 'pg_trigger_count'
require "#{File.dirname(__FILE__)}/../generators/pg_trigger_count/pg_trigger_count_generator"


ActiveRecord::Base.establish_connection(
  :adapter  => "postgresql",
  :host     => "localhost",
  :username => "postgres",
  :database => "pg_trigger_count_test"
)

ActiveRecord::Base.connection.client_min_messages = 'panic'
ActiveRecord::Migration.verbose = false


class User < ActiveRecord::Base
  has_many :messages, :as => :sender
  has_many :group_memberships
  has_many :groups, :through => :group_memberships
end

class Message < ActiveRecord::Base
  belongs_to  :sender, :polymorphic => true
end

class Group < ActiveRecord::Base
  has_many :group_memberships
  has_many :users, :through => :group_memberships
end

class GroupMembership < ActiveRecord::Base
  belongs_to :user
  belongs_to :group
end

class Test::Unit::TestCase
  
  def fake_rails_root
    File.dirname(__FILE__) + '/../tmp/rails_root'
  end

  def file_list
    Dir.glob(File.join(fake_rails_root, "*"))
  end
  
end
