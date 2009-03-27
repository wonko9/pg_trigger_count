require 'forwardable'
class PgTriggerCount
  class ReflectionGenerator
    
    attr_accessor :reflection
    def initialize(reflection)
      @reflection = reflection        
    end
  
    def count_sql(target="NEW")
      counted_keys = reflection.counted_keys.keys.join(",")
      <<-SQL
        SELECT #{counted_keys}, count(*) as #{reflection.count_column} FROM #{counted_table}
        WHERE #{count_conditions(target)}
        GROUP BY #{counted_keys}
      SQL
    end

    def count_conditions(target="NEW")
      @conditions ||= begin
        conditions = scope.collect {|k,v|"#{reflection.counter_table}.#{k}='#{v}'"}
        conditions += reflection.counter_keys.keys.collect do |key|
          "#{reflection.counter_table}.#{key}=#{target}.#{key}"
        end
      end
    end

    def counts_update_sql(target,increment=1)
      <<-SQL
        UPDATE #{reflection.counts_table} 
        SET #{reflection.count_column}=#{reflection.count_column}#{increment < 0 ? '' : '+'}#{increment} 
        WHERE #{counts_conditions(target)}
      SQL
    end

    def counts_insert_sql(target="NEW")
      counted_keys = reflection.counted_keys.keys
      values = counted_keys.collect{|k|"#{target}.#{k}"}.join(",") + 
      <<-SQL
        INSERT INTO #{reflection.counts_table} (#{counted_keys.join(",")},#{reflection.count_column}) 
        VALUES (#{target}.#{reflection}, new_count.#{reflection.count_column});
      SQL

    end

    def counts_conditions(target="NEW")
      @counts_counter_conditions ||= begin
        conditions = reflection.counts_keys.collect do |count_key, keys|
          "#{reflection.counts_table}.#{count_key}=#{target}.#{keys[:counter_key]}"
        end
        conditions << "#{reflection.counts_table}.#{reflection.count_column} IS NOT NULL"
        conditions.join(" AND ")
      end
    end        

    def record_changed_conditions
      conditions = (reflection.counter_keys.keys + scope.keys).collect do |key|
        "NEW.#{key} <> OLD.#{key}"
      end.join(",")
    end

    def cache_invalidation_sql(cache_key)
      return '' unless use_pgmemcache?
      <<-SQL
        BEGIN
          PERFORM memcache_delete(#{cache_key});
        EXCEPTION WHEN OTHERS THEN      -- Ignore errors
        END;
         -- INSERT INTO pg_trigger_cache_keys (key) VALUES ('#{count_key_prefix}:'||#{by.collect{|b|"NEW.#{b}"}.join(key_separator)});" : ''
      SQL
    end

    def cache_key
      ""
      #"'#{count_key_prefix}:'||#{by.collect{|b|"NEW.#{b}"}.join(key_separator)}"      
    end

    def reflection_sql
      <<-SQL
        IF (TG_OP = 'DELETE') THEN
          #{counts_update_sql("NEW",-1)};
        ELSIF (TG_OP = 'INSERT') THEN
          #{counts_update_sql("NEW",1)};
        ELSIF (TG_OP = 'UPDATE') THEN
          IF #{record_changed_conditions} THEN
            #{counts_update_sql("NEW",1)};
            #{counts_update_sql("OLD",-1)};
          ELSE
            RETURN NEW;
          END IF;
        END IF;

        GET DIAGNOSTICS up_count = ROW_COUNT;
        IF up_count = 0 THEN --  we couldn't update so now we have to pre-populate
           #{count_sql} INTO new_count;
           #{counts_insert_sql};
        END IF;
  --        #{cache_invalidation_sql(cache_key)};
        RETURN NEW;
      SQL

    end
    
    def method_missing(name,*args)
      begin
        reflection.send(name,*args)
      rescue NameError => e
        raise NameError.new("Method #{name} does not exist on #{self.class} or #{reflection.class}")
      end
    end
  end
end