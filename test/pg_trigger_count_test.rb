require File.dirname(__FILE__) + '/test_helper'
require 'active_record'

class PgTriggerCountTest < Test::Unit::TestCase
  # should "probably rename this file and start testing for real" do
  #   flunk "hey buddy, you should probably rename this file and start testing for real"
  # end

  context "Basic Reflection" do
    
    setup do
      ArMessage.stubs(:connection).returns(stub(:execute => true))    
      @reflection = PgTriggerCount::Reflection.new(:count_column => :ar_messages, :counter_class => "ArUser")
    end
    
    should "have right counter class" do
      assert_equal ArUser, @reflection.counter_class
    end

    should "have right counted class" do
      assert_equal ArMessage, @reflection.counted_class
    end

    should "have right counts class" do
      assert_equal ArUserCount, @reflection.counts_class
    end

    should "have right count column" do
      assert_equal "ar_messages_count", @reflection.count_column
    end

    should "have right count method name" do
      assert_equal "ar_messages_count", @reflection.count_method_name
    end

    should "have right counter_keys" do
      assert_equal @reflection.counter_keys, {"id"=>{:counter_key=>"id", :counts_key=>"ar_user_id", :counted_by_key=>"ar_user_id"}}
    end
    
    should "have table names" do
      assert_equal "ar_messages", @reflection.counted_table
      assert_equal "ar_users", @reflection.counter_table
      assert_equal "ar_user_counts", @reflection.counts_table
    end
        
  end

  context "reflection with as" do
    setup do
      ArMessage.stubs(:connection).returns(stub(:execute => true))    
      @reflection = PgTriggerCount::Reflection.new(:count_column => :ar_messages, :counter_class => "ArUser", :as => :sender)
    end

    should "have right counter_keys" do
      assert_equal @reflection.counter_keys, {"id"=>{:counter_key=>"id", :counts_key=>"ar_user_id", :counted_by_key=>"sender_id"}}
    end

  end

end
