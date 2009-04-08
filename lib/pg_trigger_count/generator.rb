require 'forwardable'
class PgTriggerCount
  class Generator

    attr_accessor :reflections, :function_name
        
    def initialize(reflections)
      @reflections = [reflections].flatten.collect{|r|PgTriggerCount::ReflectionGenerator.new(r)}
      @function_name  = "tcfunc_#{counted_class.table_name}"
    end

    def counted_class
      reflections.first.counted_class if reflections.any?
    end

    def counted_table
      counted_class.table_name
    end

    def generate_drop_function
      "DROP FUNCTION #{function_name}() CASCADE"
    end

    def begin_function_sql
      "CREATE OR REPLACE FUNCTION #{function_name}() RETURNS TRIGGER AS $#{function_name}$
      DECLARE
        up_count    integer;
        new_count   RECORD;
        new_total   integer;
        cache_data  varchar;
      BEGIN
      "
    end

    def end_function_sql
      "
        RETURN NEW;
      END;
      $#{function_name}$ LANGUAGE plpgsql;
      "
    end


    def generate_function
      begin_function_sql <<
      reflections.collect{ |r| r.generate_sql }.join("\n") <<
      end_function_sql
    end

    def generate_trigger
      <<-TRIG
        CREATE TRIGGER #{function_name}
        AFTER INSERT OR UPDATE OR DELETE ON #{counted_table}
        FOR EACH ROW EXECUTE PROCEDURE #{function_name}();
      TRIG
    end

    def generate_trigger_safe
      "BEGIN
        PERFORM #{generate_trigger}
       EXCEPTION WHEN OTHERS THEN      -- Ignore errors
       END;"
    end

    def drop_and_generate_trigger
      "DROP TRIGGER #{function_name};
      #{generate_trigger}"
    end
    
    def counts_classes
      reflections.collect{|reflection| reflection.counts_class}.uniq
    end
    
    def new_counts_tables
      new_tables = counts_classes.reject{|klass|klass.table_exists?}.collect(&:table_name)
    end
    
    def new_counts_table_definitions
      definitions = {}
      reflections.each do |reflection|
        counts_class    = reflection.counts_class
        counter_columns = reflection.counter_class.columns_hash
        unless counts_class.table_exists?
          definitions[counts_class.table_name] ||= {}
          reflection.counts_keys.each do |key,keys|
            definitions[counts_class.table_name][key] = {
              :name => key,
              :type => counter_columns[keys[:counter_key].to_s].type,
            }
          end
          definitions[counts_class.table_name][reflection.count_column] = {
            :name => reflection.count_column,
            :type => :integer
          }
        end
      end
      definitions
    end
    
    def new_counts_column_definitions
      definitions = {}
      reflections.each do |reflection|
        counts_class    = reflection.counts_class
        counter_columns = reflection.counter_class.columns_hash
        if counts_class.table_exists?
          reflection.counts_keys.each do |key,keys|
            unless counts_class.columns_hash[key.to_s]
              definitions[counts_class.table_name] ||= {}
              definitions[counts_class.table_name][key] = {
                :name => key,
                :type => counter_columns[keys[:counter_key].to_s].type,
              }
            end
          end
          unless counts_class.columns_hash[reflection.count_column]
            definitions[counts_class.table_name] ||= {}
            definitions[counts_class.table_name][reflection.count_column] = {
              :name => reflection.count_column,
              :type => :integer,
            }
          end
          
        end
      end
      definitions
    end
    
    # def generate_migrations
    #   migrations = ''
    #   counted_columns = reflections.collect(&:counted_column)
    #   if reflections.first.counts_class.table_exists?
    #     migrations = "create_table :features do |t|\n"
    #     keys = reflections.collect do |reflection|
    #       reflection.counts_keys.keys
    #     end.flatten.uniq
    #     keys.each do |key|
    #       migration << ""
    #     end
    # 
    #   else
    #   end
    #   
    # end

  end
end