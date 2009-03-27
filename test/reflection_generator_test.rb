require File.dirname(__FILE__) + '/test_helper'
require 'active_record'

class ReflectionGeneratorTest < Test::Unit::TestCase
  # should "probably rename this file and start testing for real" do
  #   flunk "hey buddy, you should probably rename this file and start testing for real"
  # end

  context "Basic Reflection" do
    
    setup do
      ArMessage.stubs(:connection).returns(stub(:execute => true))    
      @reflection = PgTriggerCount::Reflection.new(:count_column => :ar_messages, :counter_class => "ArUser")
      @generator = PgTriggerCount::ReflectionGenerator.new(@reflection)
    end
    
    should "work" do
      pp "ADAMDEBUG: ", @generator.reflection_sql
    end
    
  end
end
