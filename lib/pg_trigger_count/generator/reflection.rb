require 'forwardable'
class PgTriggerCount::Generator
  class Reflection

    attr_accessor :reflection
    def initialize(reflection)
      @reflection = reflection
    end
    
    def quote(val)
      ActiveRecord::Base.connection.quote(val)
    end

    def select_count_conditions(target="NEW")
      conditions = scope.collect {|k,v|"#{counted_table}.#{k} IS NOT DISTINCT FROM #{quote(v)}"}
      if target.is_a?(Hash)
        target = target.dup.stringify_keys
        conditions += counted_keys.collect do |key,keys|
          "#{counted_table}.#{key} is not distinct from '#{target[keys[:counter_key].to_s]}'"
        end
      else
        conditions += counted_keys.collect do |key,keys|
          "#{counted_table}.#{key} is not distinct from #{target}.#{key}"
        end
      end
      conditions.join(" AND ")
    end

    def select_count_sql(target="NEW",select_keys=nil)
      group_by = ''
      if select_keys
        select_keys = "#{select_keys.join(',')},"
        group_by = " GROUP BY #{counted_keys.keys.join(',')}"
      end
      "SELECT #{select_keys}count(*) as #{count_column} FROM #{counted_table}
          WHERE #{select_count_conditions(target)}#{group_by}"
    end

    def insert_count_from_select_sql(target="NEW")
      insert_keys = counted_keys.collect { |key,keys| keys[:counts_key] }
      insert_keys += ["created_at","updated_at",count_column]
      select_keys = counted_keys.keys + ["now()","now()"]
      "INSERT INTO #{counts_table} (#{insert_keys.join(",")})
      #{select_count_sql(target,select_keys)}"
    end

    def update_count_conditions(target="NEW",check_for_value=true)
      if target.is_a?(Hash)
        target = target.dup.stringify_keys
        conditions = reflection.counts_keys.collect do |count_key, keys|
          "#{reflection.counts_table}.#{count_key} IS NOT DISTINCT FROM '#{target[keys[:counter_key]]}'"
        end
      else
        conditions = reflection.counts_keys.collect do |count_key, keys|
          "#{reflection.counts_table}.#{count_key} IS NOT DISTINCT FROM #{target}.#{keys[:counted_key]}"
        end
      end
      conditions << "#{reflection.counts_table}.#{reflection.count_column} IS NOT NULL" if check_for_value
      conditions.join(" AND ")
    end

    def update_count_from_select_sql(target="NEW")
      "UPDATE #{counts_table} SET #{count_column}=(#{select_count_sql(target)}), updated_at=now() WHERE #{update_count_conditions(target,false)};"
    end

    def insert_or_update_count(target="NEW")
      "#{update_count_from_select_sql(target)}
        IF NOT FOUND THEN
          #{insert_count_from_select_sql(target)};
        END IF;"
    end

    def increment_counts_sql(target,increment=1)
      "UPDATE #{counts_table}
      SET #{count_column}=#{count_column}#{increment < 0 ? '' : '+'}#{increment}
      WHERE #{update_count_conditions(target)}"
    end
    
    def increment_counts_if_valid(target,increment=1)
      return increment_counts_sql(target,increment) if scope.empty?
      if_conditions = scope.collect { |key,val| "#{target}.#{key} IS NOT DISTINCT FROM #{quote(val)}"}.join(" AND ")
      "IF #{if_conditions} THEN
          #{increment_counts_sql(target,increment)};
          END IF"
    end

    # NEW.#{key} <=> OLD.#{key}"
    def record_changed_conditions
      conditions = (reflection.counted_keys.keys + scope.keys).collect do |key|
        "NEW.#{key} IS DISTINCT FROM OLD.#{key}"
      end.join(" OR ")
      conditions
    end
    
    def select_scoped_record(scope)
      "SELECT * from #{scope[:table]} WHERE id = #{}"
      
    end

    def show_record_changed_conditions
      conditions = (reflection.counted_keys.keys + scope.keys).collect do |key|
        "'#{key}: '||coalesce(NEW.#{key}::text,'NULL') || 'IS DISTINCT FROM' || coalesce(OLD.#{key}::text,'NULL')"
      end.join(" || ' ' ||")
      conditions
    end

    def show_record_data(target="NEW")
      conditions = (reflection.counted_keys.keys + scope.keys).collect do |key|
        "'#{key}: ' || coalesce(#{target}.#{key}::text,'NULL')"
      end.join(" || ' ' ||")
      conditions
    end

    def debug
      true
    end

    def sql_log_debug(op,message)
      "INSERT INTO logs (log) VALUES ('#{op} counted:#{counted_class} counter:#{counter_class} ' || #{message});" if debug
    end

    def cache_invalidation_sql
      key = counted_keys.keys.first
      "BEGIN
        IF (TG_OP = 'DELETE') THEN
          PERFORM invalidate_cache('#{counts_class}','by_#{counts_keys.keys.first}',OLD.#{key}::text);
        ELSE
          PERFORM invalidate_cache('#{counts_class}','by_#{counts_keys.keys.first}',NEW.#{key}::text);
        END IF;
       EXCEPTION WHEN OTHERS THEN      -- Ignore errors
       END;"
    end

    def generate_sql
      "
      IF (TG_OP = 'DELETE') THEN
        #{increment_counts_if_valid("OLD",-1)};
        GET DIAGNOSTICS up_count1 = ROW_COUNT;
        #{sql_log_debug('DELETE',"'rows: ' || up_count1::text || ' ' ||" + show_record_data('OLD'))}
      ELSIF (TG_OP = 'INSERT') THEN
        #{increment_counts_if_valid("NEW",1)};
        GET DIAGNOSTICS up_count2 = ROW_COUNT;
        #{sql_log_debug('INSERT',show_record_data('NEW') + "|| ' ' || 'rows: ' || up_count2::text")}
      ELSIF (TG_OP = 'UPDATE') THEN
        IF #{record_changed_conditions} THEN
          #{increment_counts_if_valid("OLD",-1)};
          GET DIAGNOSTICS up_count3 = ROW_COUNT;
          #{sql_log_debug('UPDATE DEC',show_record_changed_conditions + " || ' rows:' || up_count3::text || ' ' || '" + increment_counts_sql("OLD",-1)+"'")}
          #{increment_counts_if_valid("NEW",1)};
          GET DIAGNOSTICS up_count4 = ROW_COUNT;
          #{sql_log_debug('UPDATE INC',show_record_changed_conditions + " || ' rows:' || up_count4::text || ' ' || '" + increment_counts_sql("NEW",1)+"'")}
        ELSE
          #{sql_log_debug('UPDATE NO CHANGE',show_record_changed_conditions)}
        END IF;
      ELSE
        #{sql_log_debug('NOOP',"TG_OP")}
      END IF;

      GET DIAGNOSTICS inc_count = ROW_COUNT;
      IF TG_OP != 'DELETE' AND inc_count = 0 THEN --  we couldn't update so now we have to pre-populate
        #{sql_log_debug('REFRESH',"'refresh'")}
        #{insert_or_update_count}
      END IF;
      #{cache_invalidation_sql}
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