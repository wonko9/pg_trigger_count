class PgTriggerCount
  class Reflection

    attr_accessor :options, :counter_class, :counted_class, :counts_class, :count_column, :cache,
                  :count_method_name, :scope, :counter_keys, :counted_keys, :counts_keys

    def initialize(options)
      @options           = options
      @count_column      = "#{options[:count_column]}_count"
      @counter_class     = options[:counter_class].to_s.constantize
      @counted_class     = options[:counted_class] ? options[:counted_class].to_s.constantize : options[:count_column].to_s.classify.constantize
      @count_method_name = options[:count_method_name] || count_column
      @scope             = options[:scope] || {}
      @counts_class_name = "#{counter_class}_counts".classify
      @cache             = options[:cache] || defined?(CACHE) ? CACHE : nil
      @counter_keys      = {}
      @counted_keys      = {}
      @counts_keys       = {}

      begin
        @counts_class    = options[:counts_class] || @counts_class_name.constantize
      rescue NameError
        @counts_class = Class.new(ActiveRecord::Base)
        Object.const_set(@counts_class_name,@counts_class)
        puts "ERROR: #{@counts_class_name} has not been created. Please run ./script/generate pg_trigger_count migration" unless @counts_class.table_exists?
      end

      if options[:as]
        @counter_keys = {
          'id' => {
            :counter_key => 'id',
            :counts_key  => "#{counter_class.name.underscore}_id",
            :counted_key => "#{options[:as]}_id",
          }
        }
        @scope["#{options[:as]}_type"] = counter_class.to_s
      else
        @counter_keys = {
          'id'=> {
            :counter_key => 'id',
            :counts_key  => "#{counter_class.name.underscore}_id",
            :counted_key => "#{counter_class.name.underscore}_id",
          }
        }
      end

      # setup lookups for each type of table
      @counter_keys.each do |counter_key,keys|
        @counted_keys[keys[:counted_key]] = keys
        @counts_keys[keys[:counts_key]]   = keys
      end

      if connection and options[:record_cache] and counts_class.respond_to?(:record_cache)
        @record_cache = PgTriggerCount.use_pgmemcache?(connection)
      end

      # set up active record reflection
      counter_class.has_one counts_association, :class_name => counts_class.to_s unless respond_to? counts_class.table_name
      if record_cache?
        counts_class.record_cache :by => counts_keys.keys.first
      end
      counter_class.define_pg_count_method(self)

      add_to_model_class
    end

    def add_to_model_class
      trigger_counts = counted_class.instance_variable_get("@trigger_counts") || []
      trigger_counts << self
      counted_class.instance_variable_set("@trigger_counts",trigger_counts)
    end

    def counts_association
      counts_class.table_name
    end

    def record_cache?
      @record_cache
    end

    def cache_key_prefix
      "'pgtc:#{counts_class}:'"
    end

    def count_by_keys
      counted_keys.keys
    end

    def method_missing(name, *args)
      name = name.to_s
      if name =~ /^(.*)_table$/
        self.send("#{$1}_class").table_name
      else
        raise NameError.new("Method #{name} does not exist")
      end
    end

    def generator
      @generator ||= PgTriggerCount::Generator::Reflection.new(self)
    end

    def update_count_for(record)
      target = {}
      counter_keys.keys.each{|k| target[k]=record.send(k) }
      if (connection.update(generator.update_count_from_select_sql(target)) < 1)
        connection.insert(generator.insert_count_from_select_sql(target))
      end
    end

    def connection
      counted_class.connection
    end

  end
end