require 'forwardable'
class PgTriggerCount
  class Generator

    attr_accessor :reflections

    def initialize(reflections)
      @reflections = [reflections].flatten.collect{|r|PgTriggerCount::Generator::Reflection.new(r)}
    end
        
    def counts_classes
      reflections.collect{|reflection| reflection.counts_class}.uniq
    end

    def counted_table_generators
      @reflections_by_counted_class ||= begin
        reflections_by_counted_class = {}
        reflections.each do |reflection|
          if reflections_by_counted_class[reflection.counted_class]
            reflections_by_counted_class[reflection.counted_class].add reflection
          else
            reflections_by_counted_class[reflection.counted_class] ||= PgTriggerCount::Generator::CountedTable.new(reflection)
          end
        end
        reflections_by_counted_class
      end
    end

    def generate_functions
      counted_table_generators.values.collect{|g| g.generate_function}
    end
    
    def generate_drop_functions
      counted_table_generators.values.collect{|g| g.generate_drop_function}      
    end
    
    def generate_missing_triggers
      counted_table_generators.values.reject(&:trigger_exists?).collect{|g| g.generate_trigger }
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
    
    def generate_invalidate_cache_function
      "
      CREATE OR REPLACE FUNCTION invalidate_cache(model VARCHAR, key VARCHAR, id VARCHAR) RETURNS BOOL AS $$
      DECLARE
        cache_version VARCHAR;
        cache_key VARCHAR;
        pass BOOL;
      BEGIN
        -- Go get the cache_Version
        cache_version := 0;
        cache_key := model || '_' || cache_version || '_0:' || key || ':' || id;
        INSERT INTO pg_trigger_cache_keys (foo) VALUES (cache_key);
        PERFORM memcache_delete(cache_key);
        RETURN true;
       EXCEPTION WHEN OTHERS THEN
        INSERT INTO pg_trigger_cache_keys (foo) VALUES ('fail');
        RETURN false;
      END;
      $$ LANGUAGE plpgsql;
      "
    end
    
  end
end