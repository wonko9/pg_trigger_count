require File.dirname(__FILE__) + '/active_record_extensions'

class PgTriggerCount
  
  class << self
    def pgmemcache_checked?
      @pgmemcache_checked    
    end

    def pgmemcache_checked=(bool)
      @pgmemcache_checked = bool
    end

    def use_pgmemcache?
      @use_pgmemcache
    end

    def use_pgmemcache=(bool)
      @use_pgmemcache = bool    
    end
    
  end
  
  attr_accessor :by, :scope, :counts_table, :trig_name, :recalc_name,
  :table_name, :invalidate_cache, :options, :count_column, :name
  def initialize(table_name, options)
    @table_name       = table_name
    @options          = options
    @by               = [@options[:by]].flatten
    @scope            = @options[:scope]
    @use_pgmemcache   = @options.has_key?(:use_pgmemcache) ? @options[:use_pgmemcache] : true
    @counts_table     = "#{table_name}_counts"    
    @trig_name        = "tcfunc_#{table_name}_by_" + (scope ? "#{scope.first}" : "#{by.join('_and_')}")
    @recalc_name      = "#{@trig_name}_recalc"
    @count_column     = options[:count_column] || 'cnt'
    @name             = options[:name] || "'#{scope ? scope.first : by.join(',')}' "
  end
    
  def invalidate_cache?
    @use_pgmemcache    
  end
    
  def count_key_prefix
    "#{table_name}:#{scope ? scope.first : by.join(',')}"
  end
  
  def generate_drop_function
    "DROP FUNCTION #{trig_name}() CASCADE"    
  end
  
  def key_select
    by.join(key_separator)    
  end
    
  def scope_conditions
    scope ? ' AND ' << scope[1].collect{|k,v|"#{k}='#{v}'"}.join(' AND ') : ''
  end
  
  def separator
    '_'    
  end
  
  def key_separator
    "||'#{separator}'||"    
  end
  
  def generate_trigger_function
    new_update_where = "name=#{name} AND key=#{by.collect{|b|"NEW.#{b}"}.join(key_separator)}"  
    old_update_where = "name=#{name} AND key=#{by.collect{|b|"OLD.#{b}"}.join(key_separator)}"

    if_cond          = (by + (scope ? scope[1].keys : [])).collect{|b|"NEW.#{b} <> OLD.#{b}"}.join(' , ')
    cache_key        = "'#{count_key_prefix}:'||#{by.collect{|b|"NEW.#{b}"}.join(key_separator)}"
    
    cache_sql        = invalidate_cache? ? "
      BEGIN
        PERFORM memcache_delete(#{cache_key});
      EXCEPTION WHEN OTHERS THEN      -- Ignore errors
      END;
--    INSERT INTO pg_trigger_cache_keys (key) VALUES ('#{count_key_prefix}:'||#{by.collect{|b|"NEW.#{b}"}.join(key_separator)});" : ''

    <<-FUN
        CREATE OR REPLACE FUNCTION #{trig_name}() RETURNS TRIGGER AS $#{trig_name}$
          DECLARE
            up_count    integer;
            new_count   RECORD;
            new_total   integer;
            cache_data  varchar;
          BEGIN
            IF (TG_OP = 'DELETE') THEN
              UPDATE #{counts_table} SET #{count_column}=#{count_column}-1 WHERE #{new_update_where};
            ELSIF (TG_OP = 'INSERT') THEN
              UPDATE #{counts_table} SET #{count_column}=#{count_column}+1 WHERE #{new_update_where};
            ELSIF (TG_OP = 'UPDATE') THEN
              IF #{if_cond} THEN
                UPDATE #{counts_table} SET #{count_column}=#{count_column}+1 WHERE #{new_update_where};
                UPDATE #{counts_table} SET #{count_column}=#{count_column}-1 WHERE #{old_update_where};
              ELSE
                RETURN NEW;
              END IF;
            END IF;

            GET DIAGNOSTICS up_count = ROW_COUNT;
            IF up_count = 0 THEN --  we couldn't update so now we have to pre-populate
              SELECT #{trig_name}_recalc(#{by.collect{|b|"NEW.#{b}"}.join(',')}) INTO new_total;
            END IF;
            #{cache_sql}
            RETURN NEW;
          END;
        $#{trig_name}$ LANGUAGE plpgsql;
    FUN
    
  end
    
  def generate_recalc_function
    func_conditions = by.collect{|b|"var_#{b} " + (b.to_s[-3,3] == '_id' ? 'bigint' : 'varchar')}.join(',')
    conditions = by.collect{|b|"#{b}=var_#{b}"}.join(' AND ')
    <<-SQL
    CREATE OR REPLACE FUNCTION #{trig_name}_recalc(#{func_conditions}) RETURNS integer AS $$
      DECLARE
        new_count RECORD;
      BEGIN
        SELECT #{key_select} as key, #{name} as name, count(*) as #{count_column} FROM #{table_name}
        WHERE #{conditions} #{scope_conditions}
        GROUP BY #{by.join(',')} INTO new_count;
        INSERT INTO #{counts_table} (key,name,#{count_column}) VALUES (new_count.key, new_count.name, new_count.#{count_column});
        RETURN new_count.cnt;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def generate_trigger
    <<-TRIG
      CREATE TRIGGER #{trig_name}
      AFTER INSERT OR UPDATE OR DELETE ON messages
      FOR EACH ROW EXECUTE PROCEDURE #{trig_name}();
    TRIG
  end
  
    
end