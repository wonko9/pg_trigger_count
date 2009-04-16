require 'rubygems'
require 'pp'
require 'test/unit'
require 'shoulda'
require 'mocha'
require 'erb'
require 'ostruct'

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

# ActiveRecord::Base.logger = Logger.new(STDERR)

ActiveRecord::Base.connection.client_min_messages = 'panic'
ActiveRecord::Migration.verbose = false


class Message < ActiveRecord::Base
  belongs_to  :network
  belongs_to  :sender, :polymorphic => true
end

class Network < ActiveRecord::Base
  has_many :users
  has_many :groups
  has_many :messages     
end

class User < ActiveRecord::Base
  has_many   :messages, :as => :sender
  has_many   :group_memberships
  has_many   :groups, :through => :group_memberships
  belongs_to :network
end


class Group < ActiveRecord::Base
  has_many   :group_memberships
  has_many   :users, :through => :group_memberships
  belongs_to :network
end

class GroupMembership < ActiveRecord::Base
  belongs_to :user
  belongs_to :group
end

Network.pg_trigger_count :users, :scope => {:state => :active}
Network.pg_trigger_count :messages  
User.pg_trigger_count    :messages, :as => :sender


class PgtcMigration
  
  def self.generate_migration
    @generator ||= PgTriggerCount.generator
    vars = @generator.migration_vars("CreatePgTriggerCount")
    b = binding
    vars.each { |k,v| eval "#{k} = vars[:#{k}]", b }
    ERB.new(File.read(File.dirname(__FILE__) +"/../generators/pg_trigger_count/templates/migration.rb"),nil,'-').result(b)
  end
  

  class CreateTables < ActiveRecord::Migration
    def self.up
      
      begin
        create_table :logs do |t|
          t.column :log, :string, :limit => 2000
          t.timestamps
        end
      rescue ActiveRecord::StatementInvalid
      end
      
      create_table :networks do |t|
        t.timestamps
      end

      create_table :users do |t|
        t.integer :network_id
        t.string  :state
        t.timestamps
      end

      create_table :messages do |t|
        t.integer :network_id
        t.integer :sender_id
        t.string  :sender_type
        t.timestamps
      end

      create_table :groups do |t|
        t.integer :network_id
        t.string  :state
        t.timestamps
      end

      create_table :group_memberships do |t|
        t.integer :user_id
        t.integer :group_id
        t.boolean :approved
        t.timestamps
      end
    end

    def self.down
      drop_table :users
      drop_table :messages
      drop_table :groups
      drop_table :group_memberships
      drop_table :networks
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
end

class Test::Unit::TestCase
  def fake_rails_root
    File.dirname(__FILE__) + '/../tmp/rails_root'
  end

  def file_list
    Dir.glob(File.join(fake_rails_root, "*"))
  end

  def setup_database
    PgtcMigration::CreateTables.up
    migration = PgtcMigration.generate_migration
    eval migration
    CreatePgTriggerCount.up
  end

  def teardown_database
    PgtcMigration::CreateTables.down
    CreatePgTriggerCount.down
  end
end
