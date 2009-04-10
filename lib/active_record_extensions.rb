class PgTriggerCountError < StandardError; end

module ActiveRecord
  class Base

    def self.pg_trigger_count(count_column,options={})
      options[:count_column]  ||= count_column
      options[:counted_class] ||= options[:class_name] if options[:class_name]
      options[:counter_class]   = self
      
      reflection = PgTriggerCount::Reflection.new(options)
      
      PgTriggerCount.add_counted_model(reflection.counted_class)
    end

    def self.define_count_method(counts_association,count_method_name,count_column)
      define_method "#{count_method_name}" do
        assoc = self.send(counts_association)
        if assoc
          assoc.send(count_column)
        else
          0
          #regenerate
        end
      end
    end

    def self.trigger_counts
      @trigger_counts
    end
    
    def self.pgtc_generator
      @pgtc_generator ||= PgTriggerCount::Generator.new(trigger_counts)
    end
    
    # def count_for(reflection)
    #   self.class.connection.select_value(reflection.select_count_for(self)) || self.class.connection.select_value(reflection.recalc_count_for(self))
    # end

    # def purge_count_caches
    #   self.class.pg_trig_reflections.values.each do |reflection|
    #     CACHE.delete reflection.cache_key_for(self)
    #   end
    # end
  end


end