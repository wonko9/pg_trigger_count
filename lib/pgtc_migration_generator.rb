require 'rails_generator'
class PgtcMigrationGenerator < Rails::Generator::Base

  def manifest
    record do |m|
      m.migration_template 'lib/migration.rb', "db/migrate", {
        # :assigns => yaffle_local_assigns,
        :migration_file_name => "create_pg_trigger_count"
      }
    end

  end
end