require File.dirname(__FILE__) + '/test_helper'
require 'active_record'

class ReflectionGeneratorTest < Test::Unit::TestCase
  # should "probably rename this file and start testing for real" do
  #   flunk "hey buddy, you should probably rename this file and start testing for real"
  # end

  context "Basic Reflection" do
    
    setup do
      Message.stubs(:connection).returns(stub(:execute => true))    
      @reflection = PgTriggerCount::Reflection.new(:count_column => :messages, :counter_class => "User")
      @generator = PgTriggerCount::ReflectionGenerator.new(@reflection)
    end
    
    should "work" do
      sql = @generator.generate_sql
      f = File.open("../tmp/pg_trig_reflection1.sql", "w")
      f.write(sql)
    end    
  end


  context "polymorphic" do
    
    setup do
      Message.stubs(:connection).returns(stub(:execute => true))    
      @reflection = PgTriggerCount::Reflection.new(:count_column => :messages, :counter_class => "User", :as => :sender)
      @generator = PgTriggerCount::ReflectionGenerator.new(@reflection)
    end
    
    should "work" do
      sql = @generator.generate_sql
      f = File.open("../tmp/pg_trig_reflection2.sql", "w")
      f.write(sql)
    end    
  end
  
  context "full generator" do
    setup do
      Message.stubs(:connection).returns(stub(:execute => true))    
      @reflection = PgTriggerCount::Reflection.new(:count_column => :messages, :counter_class => "User", :as => :sender)
      @generator = PgTriggerCount::Generator.new(@reflection)
    end
    
    should "generate function" do
      # pp "ADAMDEBUG: ", @generator.reflections.first.insert_count_sql
      
      sql = @generator.generate_function
      f = File.open("../tmp/pg_trig.sql", "w")
      f.write(sql)
      f.write("\n\n")
      # f.write(@generator.generate_trigger_safe)
    end    
  end
end
