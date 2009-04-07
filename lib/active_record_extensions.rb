class PgTriggerCountError < StandardError; end

module ActiveRecord
  class Base

    def self.define_count_method(counts_reflection,count_method_name,count_column)
      define_method "#{count_method_name}" do
        self.send(counts_reflection).send(count_column)

        # if use_cache?
        #   return counter_class.instance_variable_get("@#{reflection.method_name}") if counter_class.instance_variable_get("@#{reflection.method_name}")
        #   cache_key = reflection.cache_key_for(counter_class)
        #   counter_class.instance_variable_set("@#{reflection.method_name}", CACHE.get_or_set(cache_key) do
        #     count_for(reflection)
        #   end.to_i)
        # else
          # ar_reflection.send(count_column)
        # end
      end
    end

    def self.pg_trig_reflections
      @pg_trig_reflections
    end

    def self.pg_trigger_count(count_column,options={})
      options[:count_column]  ||= count_column
      options[:counted_class] ||= options[:class_name] if options[:class_name]
      options[:counter_class]   = self

      PgTriggerCount::Reflection.add_reflection(options)

      # reflection = PgTriggerCountReflection.new(self,*args)



      # if self.instance_methods.include?(reflection.method_name.to_s)
      #   raise PgTriggerCountError.new("#{reflection.method_name} method already used")
      # end

      # function = reflection.pgtrig.generate_trigger_function
      # recalc   = reflection.pgtrig.generate_recalc_function
      # trigger  = reflection.pgtrig.generate_trigger
      # connection.execute(function)
      # connection.execute(recalc)
      # begin
      #   connection.execute(trigger)
      # rescue ActiveRecord::StatementInvalid => e
      #   # puts "Trigger already exists, dropping and recreating"
      # end

      # @pg_trig_reflections ||= {}
      # @pg_trig_reflections[reflection.name] = reflection
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