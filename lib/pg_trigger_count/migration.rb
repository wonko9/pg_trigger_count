class PgTriggerCount
  class Migration
    MIGRATION_TEMPLATE = <<-MIG
    class PgTriggerCount < ActiveRecord::Migration
      def self.up
        <% @create_tables.each do |table| %>
        <% end %>
      end

      def self.down
      end
    end

    MIG
    
    def self.generate(reflection)
      
      
    end
  end
end

