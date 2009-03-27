$:.unshift(File.dirname(__FILE__))

require 'active_record_extensions'
require 'pg_trigger_count/reflection'
require 'pg_trigger_count/generator'
require 'pg_trigger_count/reflection_generator'

class PgTriggerCount

  def self.use_pgmemcache?(connection)
    return @use_pgmemcache if defined?(@use_pgmemcache)
    begin
      connection.execute("select memcache_get('test')")
      @use_pgmemcache = true
    rescue ActiveRecord::StatementInvalid => e
      pp "PgMemcache not installed"
      @use_pgmemcache = false
    end
  end
end
