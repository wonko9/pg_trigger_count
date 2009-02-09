class PgTriggerCountError < StandardError; end

module ActiveRecord
  class Base
    def self.pg_trig_reflections
      @pg_trig_reflections
    end    
    
    def self.pg_trigger_count(count_column_name, options={})
      
      if PgTriggerCount.pgmemcache_checked?
        options[:use_pgmemcache] = PgTriggerCount.use_pgmemcache?
      else
        begin
          connection.execute("select memcache_get('test')")
          options[:use_pgmemcache] = PgTriggerCount.use_pgmemcache = true
        rescue ActiveRecord::StatementInvalid => e
          pp "PgMemcache not installed"
          options[:use_pgmemcache] = PgTriggerCount.use_pgmemcache = false
        end
        PgTriggerCount.pgmemcache_checked = true
      end
      
      reflection = PgTriggerCountReflection.new(self,options.merge(:count_column_name => count_column_name))
      
      if self.instance_methods.include?(reflection.method_name.to_s)
        raise PgTriggerCountError.new("#{reflection.method_name} method already used")
      end
      
      function = reflection.pgtrig.generate_trigger_function
      recalc   = reflection.pgtrig.generate_recalc_function
      trigger  = reflection.pgtrig.generate_trigger
      connection.execute(function)
      connection.execute(recalc)
      begin
        connection.execute(trigger)
      rescue ActiveRecord::StatementInvalid => e
        # puts "Trigger already exists, dropping and recreating"
      end
      
      @pg_trig_reflections ||= {}
      @pg_trig_reflections[reflection.name] = reflection
      
      define_method "#{reflection.method_name}" do
        if use_cache?
          return self.instance_variable_get("@#{reflection.method_name}") if self.instance_variable_get("@#{reflection.method_name}")
          cache_key = reflection.cache_key_for(self)
          self.instance_variable_set("@#{reflection.method_name}", CACHE.get_or_set(cache_key) do          
            count_for(reflection)
          end.to_i)
        else
          self.instance_variable_set("@#{reflection.method_name}", count_for(reflection))
        end
      end
      
      def count_for(reflection)
        self.class.connection.select_value(reflection.select_count_for(self)) || self.class.connection.select_value(reflection.recalc_count_for(self))        
      end
      
      def purge_count_caches
        self.class.pg_trig_reflections.values.each do |reflection|
          CACHE.delete reflection.cache_key_for(self)
        end        
      end
    end
  end
  
  class PgTriggerCountReflection
    
    attr_accessor :table_name, :counts_table, :options, :foreign_key_map, :count_column_name, 
    :pgtrig, :klass, :method_name
    def initialize(klass,options)
      @klass              = klass
      @options            = options
      @count_column_name  = options[:count_column_name]
      @table_name         = klass.table_name
      counts_table        = options[:class_name] ? options[:class_name].constantize.table_name : count_column_name.to_s
      @method_name        = "#{@count_column_name}_count"
      @foreign_key_map    = {}
      if options[:by]
        options[:by].each do |b|
          @foreign_key_map[b.to_s] = b.to_s
        end
      elsif options[:as]
        @foreign_key_map = {
          "#{options[:as]}_id"       => 'id',
          "#{options[:as]}_type"     => "class"          
        }
      elsif options[:foreign_key]
        @foreign_key_map = {
          options[:foreign_key].to_s => 'id'
        }
      else
        @foreign_key_map = {
          "#{klass.to_s.downcase}_id" => 'id'
        }
      end
            
      options[:by] ||= @foreign_key_map.keys
      
      @pgtrig = PgTriggerCount.new(counts_table,options)                  
    end    
    
    def use_cache?
      pgtrig.use_pgmemcache?      
    end

    def quote(to_quote)
      klass.connection.quote(to_quote.to_s)      
    end

    def select_count_for(record)
      "SELECT cnt FROM #{pgtrig.counts_table} WHERE name=#{pgtrig.name} AND key='#{pgtrig.by.collect{|b|"#{record.send(foreign_key_map[b.to_s])}"}.join(pgtrig.separator)}'"
    end
    
    def recalc_count_for(record)
      "SELECT #{pgtrig.recalc_name}("+ pgtrig.by.collect{|b| quote(record.send(foreign_key_map[b.to_s]))}.join(',')+")"
    end
    
    def cache_key_for(record)
      "#{pgtrig.count_key_prefix}:#{pgtrig.by.collect{|b|"#{record.send(foreign_key_map[b.to_s])}"}.join(pgtrig.separator)}"
    end  
        
    def name
      @pgtrig.trig_name      
    end
  end
    
end