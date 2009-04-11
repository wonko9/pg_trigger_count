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

    def self.define_pg_count_method(reflection)
      define_method "#{reflection.count_method_name}" do
        assoc = self.send(reflection.counts_association)
        if assoc and assoc.send(reflection.count_column)
          assoc.send(reflection.count_column)
        else
          reflection.update_count_for(self)
          UserCount.cached_index("by_#{reflection.counts_keys.keys.first}").invalidate(self.send(reflection.counter_keys.keys.first))
          if (self.send(reflection.counts_association) && self.send(reflection.counts_association).reload) || self.send(reflection.counts_association,true)
            self.send(reflection.counts_association).send(reflection.count_column)
          else
            # should this be 0?
            0
          end            
        end
      end
    end
    
    def self.trigger_counts
      @trigger_counts
    end

    def self.pgtc_generator
      @pgtc_generator ||= PgTriggerCount::Generator.new(trigger_counts)
    end
    
    def self.trigger_exists?(trigger)
      ActiveRecord::Base.connection.select_value("SELECT tgname from pg_trigger WHERE tgname='#{trigger}'")            
    end
    
  end


end