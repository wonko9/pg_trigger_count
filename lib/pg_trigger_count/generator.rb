sh require 'forwardable'
class PgTriggerCount
  class Generator

    attr_accessor :reflections, :function_name
    def initialize(reflections)
      @reflections = [reflections].flatten.collect{|r|PgTriggerCount::ReflectionGenerator.new(r)}
      @function_name  = "tcfunc_#{counted_class.table_name}"
    end

    def counted_class
      reflections.first.counted_class
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

  end
end