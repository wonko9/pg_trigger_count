class <%= migration_name %> < ActiveRecord::Migration
  
  def self.up
    <%=PgTriggerCount::Generator.up_migration %>
    
  end
  
  def self.down
    <%=PgTriggerCount::Generator.down_migration %>    
  end
end