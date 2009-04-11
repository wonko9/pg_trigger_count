require File.dirname(__FILE__) + '/test_helper'
require 'active_record'
require 'rails_generator'
require 'rails_generator/scripts/generate'

class GeneratorTest < Test::Unit::TestCase
  # should "probably rename this file and start testing for real" do
  #   flunk "hey buddy, you should probably rename this file and start testing for real"
  # end

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

  context "Basic Reflection" do
    
    setup do
      CreateTables.up
      # Message.stubs(:connection).returns(stub(:execute => true))    
      @reflection = PgTriggerCount::Reflection.new(:count_column => :messages, :counter_class => "User")
      @generator = PgTriggerCount::Generator::Reflection.new(@reflection)
    end
    
    should "work" do
      sql = @generator.generate_sql
      f = File.open("../tmp/pg_trig_reflection1.sql", "w")
      f.write(sql)
    end    
    
    teardown do
      CreateTables.down
    end
  end


  context "polymorphic" do
    
    setup do
      Message.stubs(:connection).returns(stub(:execute => true))    
      @reflection = PgTriggerCount::Reflection.new(:count_column => :messages, :counter_class => "User", :as => :sender)
      @generator = PgTriggerCount::Generator::Reflection.new(@reflection)
    end
    
    should "work" do
      sql = @generator.generate_sql
      f = File.open("../tmp/pg_trig_reflection2.sql", "w")
      f.write(sql)
    end    
  end
  
  context "full generator" do
    setup do
      CreateTables.up
      @messages = PgTriggerCount::Reflection.new(:count_column => :messages, :counter_class => "User", :as => :sender)
      @user_groups = PgTriggerCount::Reflection.new(:count_column => :groups, :counter_class => "User", :counted_class => "GroupMembership")
      @group_users = PgTriggerCount::Reflection.new(:count_column => :users, :counter_class => "Group", :counted_class => "GroupMembership")
      @generator = PgTriggerCount::Generator.new([@messages,@user_groups,@group_users])
    end
    teardown do
      CreateTables.down
    end
    
    should "generate function" do
      # pp "ADAMDEBUG: ", @generator.reflections.first.insert_count_sql
      
      sql = @generator.generate_functions
      f = File.open("../tmp/pg_trig.sql", "w")
      f.write(sql)
      f.write("\n\n")
      # f.write(@generator.generate_trigger_safe)
    end    
    
    should "new tables" do
      assert_equal @generator.new_counts_table_definitions, {
        "user_counts" => { 
            "user_id"        => {:type=>:integer, :name=>"user_id"},
            "groups_count"   => {:type=>:integer, :name=>"groups_count"},
            "messages_count" => {:type=>:integer, :name=>"messages_count"}
          },
        "group_counts"=> {
          "users_count"=> {:type=>:integer, :name=>"users_count"},
          "group_id"   => {:type=>:integer, :name=>"group_id"}
         }
      }
         
    end

    context "missing columns" do
      setup do
        CreateUserCounts.up      
      end
    
      teardown do
        CreateUserCounts.down
      end                    
    
      should "new columns" do
        assert_equal @generator.new_counts_column_definitions, {"user_counts"=>{"groups_count"=>{:type=>:integer, :name=>"groups_count"}}}
      end
    end
    
    # context "migrations" do
    #   
    #   setup do
    #     FileUtils.mkdir_p(fake_rails_root)
    #     @original_files = file_list
    #   end
    #   teardown do
    #     FileUtils.rm_r(fake_rails_root)
    #   end
    #   
    #   should "create migration" do
    #     Rails::Generator::Scripts::Generate.new.run(["pg_trigger_count","generate"], :destination => fake_rails_root)
    #     new_file = (file_list - @original_files).first
    #     pp "ADAMDEBUG: #{new_file}"
    #   end
    # end
    

  end
end
