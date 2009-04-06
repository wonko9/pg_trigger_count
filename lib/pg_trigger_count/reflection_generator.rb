require 'forwardable'
class PgTriggerCount
  class ReflectionGenerator

    attr_accessor :reflection
    def initialize(reflection)
      @reflection = reflection
    end

    def select_count_conditions(target="NEW")
      conditions = scope.collect {|k,v|"#{reflection.counted_table}.#{k}='#{v}'"}
      conditions += reflection.counted_keys.keys.collect do |key|
        "#{reflection.counted_table}.#{key}=#{target}.#{key}"
      end
      conditions.join(" AND ")
    end

    def select_count_sql(target="NEW")
      counted_keys = reflection.counted_keys.keys.collect{|k|"#{counted_table}.#{k}"}.join(",")
      "SELECT #{counted_keys}, count(*) as #{count_column} FROM #{counted_table}
      WHERE #{select_count_conditions(target)}
      GROUP BY #{counted_keys}"
    end
    
    def insert_count_sql(target="NEW")
      insert_keys = counted_keys.collect{|k,keys|keys[:counts_key]}
      insert_keys << count_column
      "INSERT INTO #{reflection.counts_table} (#{insert_keys.join(",")})
        #{select_count_sql(target)}"
      
    end

    # def insert_count_sql(target="NEW")
    #   counted_keys = reflection.counted_keys.keys
    #   values = counted_keys.collect{|k|"#{target}.#{k}"}
    #   values << "new_count.cnt"
    #   "INSERT INTO #{reflection.counts_table} (#{counted_keys.join(",")},#{reflection.count_column})
    #   VALUES (#{values.join(",")})"
    # end

    def update_count_conditions(target="NEW")
      conditions = reflection.counts_keys.collect do |count_key, keys|
        "#{reflection.counts_table}.#{count_key}=#{target}.#{keys[:counter_key]}"
      end
      conditions << "#{reflection.counts_table}.#{reflection.count_column} IS NOT NULL"
      conditions.join(" AND ")
    end

    def update_count_sql(target,increment=1)
      "UPDATE #{reflection.counts_table}
      SET #{reflection.count_column}=#{reflection.count_column}#{increment < 0 ? '' : '+'}#{increment}
      WHERE #{update_count_conditions(target)}"
    end

    def record_changed_conditions
      conditions = (reflection.counter_keys.keys + scope.keys).collect do |key|
        "NEW.#{key} <> OLD.#{key}"
      end.join(",")
    end

    def cache_invalidation_sql(cache_key)
      return '' unless use_pgmemcache?
      "BEGIN
        PERFORM memcache_delete(#{cache_key});
       EXCEPTION WHEN OTHERS THEN      -- Ignore errors
       END;"
         # -- INSERT INTO pg_trigger_cache_keys (key) VALUES ('#{count_key_prefix}:'||#{by.collect{|b|"NEW.#{b}"}.join(key_separator)});" : ''
    end

    def cache_key
      ""
      #"'#{count_key_prefix}:'||#{by.collect{|b|"NEW.#{b}"}.join(key_separator)}"
    end

    def generate_sql
      "
      IF (TG_OP = 'DELETE') THEN
        #{update_count_sql("NEW",-1)};
      ELSIF (TG_OP = 'INSERT') THEN
        #{update_count_sql("NEW",1)};
      ELSIF (TG_OP = 'UPDATE') THEN
        IF #{record_changed_conditions} THEN
          #{update_count_sql("NEW",1)};
          #{update_count_sql("OLD",-1)};
        ELSE
          RETURN NEW;
        END IF;
      END IF;

      GET DIAGNOSTICS up_count = ROW_COUNT;
      IF up_count = 0 THEN --  we couldn't update so now we have to pre-populate
         #{insert_count_sql};
      END IF;
      --        #{cache_invalidation_sql(cache_key)}
      "
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