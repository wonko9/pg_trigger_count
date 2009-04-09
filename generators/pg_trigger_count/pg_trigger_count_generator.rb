require 'rails_generator'
class PgTriggerCountGenerator < Rails::Generator::NamedBase
  
  def initialize(runtime_args, runtime_options = {})
    super    
  end            
  
  def manifest
    @generator = PgTriggerCount.generator
    record do |m|
      # m.directory "lib"
      # m.template 'README', "README"
      now = Time.now.to_i
      if @generator.new_counts_table_definitions.any? or @generator.new_counts_column_definitions.any?
        m.migration_template 'migration.rb', 'db/migrate', :assigns => {
          :migration_name => "CreatePgTriggerCount#{now}",
          :new_tables => @generator.new_counts_table_definitions,
          :new_columns => @generator.new_counts_column_definitions,
          :functions => @generator.generate_functions,
        }, :migration_file_name => "create_pg_trigger_count_#{now}"
      end

      # m.migration_template 'templates/migration.rb', "db/migrate", {
      #   # :assigns => yaffle_local_assigns,
      #   :migration_file_name => "create_pg_trigger_count"
      # }
      
    end
  end
end
