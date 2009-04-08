require File.dirname(__FILE__) + '/test_helper'
require 'active_record'
require 'ostruct'

class PgTriggerCountTest < Test::Unit::TestCase
  # should "probably rename this file and start testing for real" do
  #   flunk "hey buddy, you should probably rename this file and start testing for real"
  # end


  # def test_generates_definition
  #   Rails::Generator::Scripts::Generate.new.run(["yaffle", "bird"], :destination => fake_rails_root)
  #   definition = File.read(File.join(fake_rails_root, "definition.txt"))
  #   assert_match /Yaffle\:/, definition
  # end

  context "Basic Reflection" do
    
    setup do
      Message.stubs(:connection).returns(stub(:execute => true))    
      @reflection = PgTriggerCount::Reflection.new(:count_column => :messages, :counter_class => "User")
    end
    
    should "have right counter class" do
      assert_equal User, @reflection.counter_class
    end

    should "have right counted class" do
      assert_equal Message, @reflection.counted_class
    end

    should "have right counts class" do
      assert_equal UserCount, @reflection.counts_class
    end

    should "have right count column" do
      assert_equal "messages_count", @reflection.count_column
    end

    should "have right count method name" do
      assert_equal "messages_count", @reflection.count_method_name
    end

    should "have right counter_keys" do
      assert_equal @reflection.counter_keys, {"id"=>{:counter_key=>"id", :counts_key=>"user_id", :counted_key=>"user_id"}}
    end
    
    should "have table names" do
      assert_equal "messages", @reflection.counted_table
      assert_equal "users", @reflection.counter_table
      assert_equal "user_counts", @reflection.counts_table
    end
        
  end

  context "reflection with as" do
    setup do
      Message.stubs(:connection).returns(stub(:execute => true))    
      @reflection = PgTriggerCount::Reflection.new(:count_column => :messages, :counter_class => "User", :as => :sender)
    end

    should "have right counter_keys" do
      assert_equal @reflection.counter_keys, {"id"=>{:counter_key=>"id", :counts_key=>"user_id", :counted_key=>"sender_id"}}
    end
    
    should "select" do
      u = OpenStruct.new(:id => 1)
      pp "ADAMDEBUG: ", @reflection.select_count_for(u)
    end

  end

end
