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
      sql = @generator.reflection_sql
      f = File.open("../tmp/pg_trig.sql", "w")
      f.write(sql)
    end
    
    String
    
  end
end
