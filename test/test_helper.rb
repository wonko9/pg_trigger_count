require 'rubygems'
require 'pp'
require 'test/unit'
require 'shoulda'
require 'mocha'
require 'erb'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

# $LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))
require 'pg_trigger_count'

# ActiveRecord::Base.logger = Logger.new(STDERR)
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

class PgtcMigration
  class CreateTables < ActiveRecord::Migration 
    def self.up
      create_table :users do |t|
        t.column :state, :string
      end

      create_table :messages do |t|
        t.integer :sender_id
        t.string :sender_type
      end
    
      create_table :groups do |t|
        t.timestamps
      end      

      create_table :group_memberships do |t|
        t.integer :user_id
        t.integer :group_id
      end      
    end

    def self.down
      drop_table :users
      drop_table :messages
      drop_table :groups
      drop_table :group_memberships
    end
  end

  class CreateUserCounts < ActiveRecord::Migration    
    def self.up
      create_table :user_counts do |t|
        t.column :user_id, :integer
        t.column :messages_count, :integer
      end
    end
  
    def self.down
      drop_table :user_counts
    end
  end


  def method_name
    :migration_name   => "CreatePgTriggerCount#{now}",
    :new_tables       => @generator.new_counts_table_definitions,
    :new_columns      => @generator.new_counts_column_definitions,
    :create_functions => @generator.generate_functions,
    :drop_functions   => @generator.generate_drop_functions,
    :create_triggers  => @generator.generate_missing_triggers,
    :invalidate_cache => @generator.generate_invalidate_cache_function,
    
    
  end


end