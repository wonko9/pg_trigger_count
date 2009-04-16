require File.dirname(__FILE__) + '/test_helper'
require 'ostruct'

class PgTriggerCountTest < Test::Unit::TestCase

  # context "Basic Reflection" do
  #   
  #   setup do
  #     @reflection = PgTriggerCount::Reflection.new(:count_column => :messages, :counter_class => "User")
  #   end
  #   
  #   should "have right counter class" do
  #     assert_equal User, @reflection.counter_class
  #   end
  # 
  #   should "have right counted class" do
  #     assert_equal Message, @reflection.counted_class
  #   end
  #   
  #   should "have right counts class" do
  #     assert_equal UserCount, @reflection.counts_class
  #   end
  #   
  #   should "have right count column" do
  #     assert_equal "messages_count", @reflection.count_column
  #   end
  #   
  #   should "have right count method name" do
  #     assert_equal "messages_count", @reflection.count_method_name
  #   end
  #   
  #   should "have right counter_keys" do
  #     assert_equal @reflection.counter_keys, {"id"=>{:counter_key=>"id", :counts_key=>"user_id", :counted_key=>"user_id"}}
  #   end
  #   
  #   should "have table names" do
  #     assert_equal "messages", @reflection.counted_table
  #     assert_equal "users", @reflection.counter_table
  #     assert_equal "user_counts", @reflection.counts_table
  #   end
  #       
  # end
  
  context "reflection with as" do
    setup do
      @reflection = PgTriggerCount::Reflection.new(:count_column => :messages, :counter_class => "User", :as => :sender)
    end
  
    should "have right counter_keys" do
      assert_equal @reflection.counter_keys, {"id"=>{:counter_key=>"id", :counts_key=>"user_id", :counted_key=>"sender_id"}}
    end
    
  end       
  
  context "full" do
    
    setup do
      setup_database
      @n1 = Network.create
      @u1 = User.create(:network => @n1)
      @u2 = User.create(:network => @n1)
    end
    
    teardown do
      teardown_database
    end
    
    should "have scope" do
      @n1 = Network.find @n1.id
      assert_equal 0, @n1.users_count
      @u1.update_attribute :state, 'active'
      @n1 = Network.find @n1.id
      assert_equal 1, @n1.users_count
      @u1.update_attribute :state, 'passive'
      @n1 = Network.find @n1.id
      assert_equal 0, @n1.users_count
    end
            
    should "handle updates" do
      @m2 = Message.create(:sender => @u2)
      assert_equal 1, @u2.messages_count
      assert_equal 0, @u1.messages_count
      @m2.sender = @u1
      @m2.save
      assert_equal 0, @u2.user_counts(true).messages_count
      assert_equal 1, @u1.messages_count
    end
    
    should "inc dec message counts" do
      @m1 = Message.create(:sender => @u1)
      assert_equal 1, @u1.messages_count
      @m1.destroy
      @u1 = User.find @u1.id
      assert_equal 0, @u1.messages_count
      assert_equal 0, @u2.messages_count
    end
    
  end

end
