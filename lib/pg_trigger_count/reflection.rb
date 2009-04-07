class PgTriggerCount
  class Reflection


    def self.add_reflection(options)
      reflection = new(options)
      class_reflections = reflection.counted_class.instance_variable_get("@pgtc_reflections")
      class_reflections ||= []
      class_reflections << reflection
      reflection.counted_class.instance_variable_set("@pgtc_reflections",class_reflections)      
    end

    attr_accessor :options, :counter_class, :counted_class, :counts_class, :count_column,
                  :count_method_name, :use_pgmemcache, :scope, :counter_keys, :counted_keys, :counts_keys

    def initialize(options)
      @options           = options
      @count_column      = "#{options[:count_column]}_count"
      @counter_class     = options[:counter_class].to_s.constantize
      @counted_class     = options[:counted_class] ? options[:counted_class].to_s.constantize : options[:count_column].to_s.classify.constantize
      
      @count_method_name = options[:count_method_name] || count_column
      @scope             = options[:scope] || {}
      @counter_keys      = {}
      @counted_keys      = {}
      @counts_keys       = {}

      @counts_class_name = "#{counter_class}_counts".classify
      begin
        @counts_class    = options[:counts_class] || @counts_class_name.constantize
      rescue NameError
        @counts_class = Class.new(ActiveRecord::Base)
        Object.const_set(@counts_class_name,@counts_class)
        puts "ERROR: #{@counts_class_name} has not been created. Please run rake pgtc:generate_migration" unless @counts_class.table_exists?
      end

      if options[:as]
        @counter_keys = {
          'id' => {
            :counter_key    => 'id',
            :counts_key     => "#{counter_class.name.underscore}_id",
            :counted_key => "#{options[:as]}_id",
          }
        }
        @scope["#{options[:as]}_type"] = counter_class.to_s
      else
        @counter_keys = {
          'id'=> {
            :counter_key    => 'id',
            :counts_key     => "#{counter_class.name.underscore}_id",
            :counted_key => "#{counter_class.name.underscore}_id",
          }
        }
      end

      # setup lookups for each type of table
      @counter_keys.each do |counter_key,keys|
        @counted_keys[keys[:counted_key]] = keys
        @counts_keys[keys[:counts_key]]      = keys
      end


      # @count_by_keys = options[:by]
      #
      # if
      #   options[:by].each do |b|
      #     @foreign_key_map[b.to_s] = b.to_s
      #   end
      # elsif options[:as]
      #   @foreign_key_map = {
      #     "#{options[:as]}_id"       => 'id',
      #     "#{options[:as]}_type"     => "class"
      #   }
      # elsif options[:foreign_key]
      #   @foreign_key_map = {
      #     options[:foreign_key].to_s => 'id'
      #   }
      # else
      #   @foreign_key_map = {
      #     "#{klass.to_s.downcase}_id" => 'id'
      #   }
      # end
      #
      # options[:by] ||= @foreign_key_map.keys

      if connection and (options.has_key?(:use_pgmemcache)) or options[:use_pgmemcache]
        @use_pgmemcache = PgTriggerCount.use_pgmemcache?(connection)
      end
    end
    
    def use_pgmemcache?
      @use_pgmemcache      
    end
    
    def count_by_keys
      counted_keys.keys
    end
    
    def generator
      
    end

    def connection
      counted_class.connection
    end
    
    def self.create_counts_class(klass)
      eval %"class #{klass} < ActiveRecord::Base;end"
    end

    def quote(to_quote)
      connection.quote(to_quote.to_s)
    end

    def method_missing(name, *args)
      name = name.to_s
      if name =~ /^(.*)_table$/
        self.send("#{$1}_class").table_name
      else
        raise NameError.new("Method #{name} does not exist")
      end
    end

    def define_count_method
      counter_class.define_method "#{reflection.method_name}" do
        if use_cache?
          return counter_class.instance_variable_get("@#{reflection.method_name}") if counter_class.instance_variable_get("@#{reflection.method_name}")
          cache_key = reflection.cache_key_for(counter_class)
          counter_class.instance_variable_set("@#{reflection.method_name}", CACHE.get_or_set(cache_key) do
            count_for(reflection)
          end.to_i)
        else
          counter_class.instance_variable_set("@#{reflection.method_name}", count_for(reflection))
        end
      end
    end

    # def select_count_for(record)
    #   "SELECT cnt FROM #{pgtrig.counts_table} WHERE name=#{pgtrig.name} AND key='#{pgtrig.by.collect{|b|"#{record.send(foreign_key_map[b.to_s])}"}.join(pgtrig.separator)}'"
    # end
    #
    # def recalc_count_for(record)
    #   "SELECT #{pgtrig.recalc_name}("+ pgtrig.by.collect{|b| quote(record.send(foreign_key_map[b.to_s]))}.join(',')+")"
    # end
    #
    # def cache_key_for(record)
    #   "#{pgtrig.count_key_prefix}:#{pgtrig.by.collect{|b|"#{record.send(foreign_key_map[b.to_s])}"}.join(pgtrig.separator)}"
    # end

    # def name
    #   @pgtrig.trig_name
    # end
  end
end