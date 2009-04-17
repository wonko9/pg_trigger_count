class PgTriggerCount::Generator
  class CountedTable
    
    attr_accessor :reflections
    def initialize(reflections)
      @reflections = [reflections].flatten.collect{|r|PgTriggerCount::Generator::Reflection.new(r)}
    end
    
    def add(reflection)
      @reflections << reflection      
    end
    
    def counted_class
      reflections.first.counted_class      
    end
    
    def function_name
      "tcfunc_#{counted_class.table_name}"      
    end

    def generate_drop_function
      "DROP FUNCTION #{function_name}() CASCADE"
    end

    def begin_function_sql
      "CREATE OR REPLACE FUNCTION #{function_name}() RETURNS TRIGGER AS $#{function_name}$
      DECLARE
        up_count1 integer;
        up_count2 integer;
        up_count3 integer;
        up_count4 integer;
        up_count5 integer;
        inc_count integer;
        scope_record RECORD;
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

    def generate_trigger
      <<-TRIG
        CREATE TRIGGER #{function_name}
        AFTER INSERT OR UPDATE OR DELETE ON #{counted_class.table_name}
        FOR EACH ROW EXECUTE PROCEDURE #{function_name}();
      TRIG
    end
    
    def trigger_exists?
      ActiveRecord::Base.trigger_exists?(function_name)
    end

    def drop_and_generate_trigger
      "DROP TRIGGER #{function_name};
      #{generate_trigger}"
    end

    def generate_function
      begin_function_sql <<
      reflections.collect{ |r| r.generate_sql }.join("\n") <<
      end_function_sql
    end
    
  end
end