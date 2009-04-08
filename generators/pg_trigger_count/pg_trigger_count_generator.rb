class PgTriggerCountGenerator < Rails::Generator::NamedBase
  
  def initialize(runtime_args, runtime_options = {})
    super
    pp "ADAMDEBUG: ", runtime_args, runtime_options
    
  end            
  
  def manifest
    record do |m|
      # m.directory "lib"
      # m.template 'README', "README"
      now = Time.now.to_i
      m.migration_template 'migration.rb', 'db/migrate', :assigns => {
        :migration_name => "CreatePgTriggerCountMigration#{now}"
      }, :migration_file_name => "create_pg_trigger_count_migration_#{now}"

      # m.migration_template 'templates/migration.rb', "db/migrate", {
      #   # :assigns => yaffle_local_assigns,
      #   :migration_file_name => "create_pg_trigger_count"
      # }
      
    end
  end
end
