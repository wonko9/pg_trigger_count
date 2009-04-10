class <%= migration_name %> < ActiveRecord::Migration
  def self.up
  <%- new_tables.each do |table_name, columns| -%>
    create_table :<%= table_name %> do |t|
    <%- columns.values.each do |column| -%>
      t.column :<%=column[:name] %>, :<%=column[:type]%>
    <%- end -%>
      t.timestamps
    end
  <%- end -%>
  <%- new_columns.each do |table_name, column| -%>
    add_column :<%=table_name %>, :<%= column[:name] %>, :<%=column[:type]%>
  <%- end -%>
  
  <%- create_functions.each do |function| -%>
    function = <<-SQL
      <%= function %>
    SQL
    ActiveRecord::Base.connection.execute(function)
  <%- end -%>
  <%- create_triggers.each do |trigger| -%>
    trigger = <<-SQL
      <%= trigger %>
    SQL
    ActiveRecord::Base.connection.execute(trigger)
  <%- end -%>
  
  end

  def self.down
  <%- new_tables.each do |table_name, columns| -%>
    drop_table :<%= table_name %>
  <%- end -%>
  <%- new_columns.each do |table_name, column| -%>
    remove_column :<%=table_name %>, :<%= column[:name] %>
  <%- end -%>
  <%- drop_functions.each do |function| -%>
    ActiveRecord::Base.connection.execute("<%= function %>")
  <%- end -%>
  end
end