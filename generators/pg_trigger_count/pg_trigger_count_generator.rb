class PgTriggerCountGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      # m.directory "lib"
      # m.template 'README', "README"
      m.migration_template 'templates/migration.rb', "db/migrate", {
        # :assigns => yaffle_local_assigns,
        :migration_file_name => "create_pg_trigger_count"
      }
      
    end
  end
end
