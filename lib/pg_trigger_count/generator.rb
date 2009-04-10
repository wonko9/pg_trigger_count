require 'forwardable'
class PgTriggerCount
  class Generator

    attr_accessor :reflections

    def initialize(reflections)
      @reflections = [reflections].flatten.collect{|r|PgTriggerCount::ReflectionGenerator.new(r)}
    end
    
    def function_name(counted_class)
      "tcfunc_#{counted_class.table_name}"      
    end

    def generate_drop_function(counted_class)
      "DROP FUNCTION #{function_name(counted_class)}() CASCADE"
    end

    def begin_function_sql(counted_class)
      "CREATE OR REPLACE FUNCTION #{function_name(counted_class)}() RETURNS TRIGGER AS $#{function_name(counted_class)}$
      DECLARE
        up_count    integer;
        new_count   RECORD;
        new_total   integer;
        cache_data  varchar;
      BEGIN
      "
    end

    def end_function_sql(counted_class)
      "
        RETURN NEW;
      END;
      $#{function_name(counted_class)}$ LANGUAGE plpgsql;
      "
    end

    def generate_trigger(counted_class)
      <<-TRIG
        CREATE TRIGGER #{function_name(counted_class)}
        AFTER INSERT OR UPDATE OR DELETE ON #{counted_class.table_name}
        FOR EACH ROW EXECUTE PROCEDURE #{function_name(counted_class)}();
      TRIG
    end

    def drop_and_generate_trigger(counted_class)
      "DROP TRIGGER #{function_name(counted_class)};
      #{generate_trigger(counted_class)}"
    end

    def generate_function(counted_class)
      begin_function_sql(counted_class) <<
      reflections_by_counted_class[counted_class].collect{ |r| r.generate_sql }.join("\n") <<
      end_function_sql(counted_class)
    end
    
    def generate_functions
      reflections_by_counted_class.keys.collect{|counted_class| generate_function(counted_class)}
    end
    
    def generate_drop_functions
      reflections_by_counted_class.keys.collect{|counted_class| generate_drop_function(counted_class)}      
    end
    
    def generate_missing_triggers
      missing_triggers = reflections_by_counted_class.keys.reject do |counted_class| 
        ActiveRecord::Base.connection.select_value("SELECT tgname from pg_trigger WHERE tgname = '#{function_name(counted_class)}'")
      end.collect{|counted_class| generate_trigger(counted_class) }
    end

    def counts_classes
      reflections.collect{|reflection| reflection.counts_class}.uniq
    end

    def reflections_by_counted_class
      reflections_by_counted_class = {}
      reflections.each do |reflection|
        reflections_by_counted_class[reflection.counted_class] ||= []
        reflections_by_counted_class[reflection.counted_class] << reflection
      end
      reflections_by_counted_class
    end

    def reflections_by_counts_class
      reflections_by_counts_class = {}
      reflections.each do |reflection|
        reflections_by_counts_class[reflection.counts_class] ||= []
        reflections_by_counts_class[reflection.counts_class] << reflection
      end
      reflections_by_counts_class
    end
    
    def new_counts_tables
      new_tables = counts_classes.reject{|klass|klass.table_exists?}.collect(&:table_name)
    end

    def new_counts_table_definitions
      definitions = {}
      reflections_by_counts_class.each do |counts_class,reflections|
        next if counts_class.table_exists?
        counter_columns = reflections.first.counter_class.columns_hash
        definitions[counts_class.table_name] ||= {}
        reflections.each do |reflection|
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
      reflections_by_counts_class.each do |counts_class,reflections|
        next unless counts_class.table_exists?
        counter_columns = reflections.first.counter_class.columns_hash
        # pp "ADAMDEBUG: ", counter_columns

        # add missing key columns
        reflections.collect(&:counts_keys).each do |keys|
          keys = keys.values.first
          next if counts_class.columns_hash[keys[:counts_key].to_s]
          definitions[counts_class.table_name] ||= {}
          definitions[counts_class.table_name][keys[:counts_key]] = {
            :name => key,
            :type => counter_columns[keys[:counter_key].to_s].type,
          }
        end

        # add missing count columns
        reflections.each do |reflection|
          next if counts_class.columns_hash[reflection.count_column]
          definitions[counts_class.table_name] ||= {}
          definitions[counts_class.table_name][reflection.count_column] = {
            :name => reflection.count_column,
            :type => :integer,
          }
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