require 'forwardable'
class PgTriggerCount
  class ReflectionGenerator

    attr_accessor :reflection
    def initialize(reflection)
      @reflection = reflection
    end

    def select_count_conditions(target="NEW")
      conditions = scope.collect {|k,v|"#{counted_table}.#{k}='#{v}'"}
      conditions += counted_keys.collect do |key,keys|
        "#{counted_table}.#{key}=#{target}.#{key}"
      end
      conditions.join(" AND ")
    end

    def select_count_sql(target="NEW")
      select_keys = counted_keys.keys.collect{|k|"#{counted_table}.#{k}"}.join(",")
      "SELECT #{select_keys}, count(*) as #{count_column} FROM #{counted_table}
          WHERE #{select_count_conditions(target)}
          GROUP BY #{select_keys}"
    end

    def insert_count_from_select_sql(target="NEW")
      insert_keys = counted_keys.collect { |key,keys| keys[:counts_key] }
      insert_keys << count_column
      "INSERT INTO #{counts_table} (#{insert_keys.join(",")})
      #{select_count_sql(target)}"
    end
    
    def insert_count_sql(target="NEW")
      insert_keys = counted_keys.collect { |key,keys| keys[:counts_key] }
      insert_keys += [count_column,"created_at","updated_at"]
      values = counted_keys.keys.collect{|k|"#{target}.#{k}"}
      values << ["new_count.#{count_column}","now()","now()"]
      "INSERT INTO #{counts_table} (#{insert_keys.join(',')})
            VALUES (#{values.join(",")})"
    end

    def update_count_conditions(target="NEW")
      conditions = reflection.counts_keys.collect do |count_key, keys|
        "#{reflection.counts_table}.#{count_key}=#{target}.#{keys[:counted_key]}"
      end
      conditions << "#{reflection.counts_table}.#{reflection.count_column} IS NOT NULL"
      conditions.join(" AND ")
    end
    
    def insert_or_update_count(target="NEW")
      "#{select_count_sql(target)} INTO new_count;
        UPDATE #{counts_table} SET #{count_column}=new_count.#{count_column}, updated_at=now()
        WHERE #{update_count_conditions(target)};
        IF NOT FOUND THEN
          #{insert_count_sql("new_count")};
        END IF;"
    end

    def increment_counts_sql(target,increment=1)
      "UPDATE #{counts_table}
      SET #{count_column}=#{count_column}#{increment < 0 ? '' : '+'}#{increment}
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
        #{increment_counts_sql("NEW",-1)};
      ELSIF (TG_OP = 'INSERT') THEN
        #{increment_counts_sql("NEW",1)};
      ELSIF (TG_OP = 'UPDATE') THEN
        IF #{record_changed_conditions} THEN
          #{increment_counts_sql("NEW",1)};
          #{increment_counts_sql("OLD",-1)};
        ELSE
          RETURN NEW;
        END IF;
      END IF;

      GET DIAGNOSTICS up_count = ROW_COUNT;
      IF up_count = 0 THEN --  we couldn't update so now we have to pre-populate
        #{insert_or_update_count}
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