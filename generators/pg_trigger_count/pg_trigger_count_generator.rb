require 'rails_generator'
class PgTriggerCountGenerator < Rails::Generator::NamedBase
  
  def initialize(runtime_args, runtime_options = {})
    super
    pp "ADAMDEBUG: ", runtime_args, runtime_options
    
  end            
  
  def manifest
    @generator = PgTriggerCount.generator
    record do |m|
      # m.directory "lib"
      # m.template 'README', "README"
      now = Time.now.to_i
      m.migration_template 'migration.rb', 'db/migrate', :assigns => {
        :migration_name => "CreatePgTriggerCountMigration#{now}",
        :new_tables => @generator.new_counts_table_definitions,
        :new_columns => @generator.new_counts_column_definitions,
      }, :migration_file_name => "create_pg_trigger_count_migration_#{now}"

      # m.migration_template 'templates/migration.rb', "db/migrate", {
      #   # :assigns => yaffle_local_assigns,
      #   :migration_file_name => "create_pg_trigger_count"
      # }
      
    end
  end
end
