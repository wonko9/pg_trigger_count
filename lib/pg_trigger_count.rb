$:.unshift(File.dirname(__FILE__))

require 'active_record'
require 'active_support'
require 'active_record_extensions'
require 'pg_trigger_count/reflection'
require 'pg_trigger_count/generator'
require 'pg_trigger_count/generator/reflection'
require 'pg_trigger_count/generator/counted_table'

class PgTriggerCount

  def self.use_pgmemcache?(connection)
    return @use_pgmemcache if defined?(@use_pgmemcache)
    begin
      connection.execute("select memcache_get('test')")
      @use_pgmemcache = true
    rescue ActiveRecord::StatementInvalid => e
      @use_pgmemcache = false
    end
  end

  def self.add_counted_model(klass)
    @counted_models ||= []
    @counted_models << klass unless @counted_models.include?(klass)
  end

  def self.counted_models
    @counted_models || []
  end

  def self.generator
    PgTriggerCount::Generator.new(counted_models.collect(&:trigger_counts).flatten)
  end
end
