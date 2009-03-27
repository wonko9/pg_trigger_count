require 'rubygems'
require 'pp'
require 'test/unit'
require 'shoulda'
require 'mocha'

$LOAD_PATH.unshift(File.dirname(__FILE__))
# $LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))
require 'pg_trigger_count'



class ArMock
  def self.table_name
    self.to_s.tableize    
  end
end

class ArUser < ArMock
end

class ArMessage < ArMock
end

class ArUserCount < ArMock
end


class Test::Unit::TestCase
end
