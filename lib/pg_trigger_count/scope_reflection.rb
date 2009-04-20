class PgTriggerCount
  class ScopeReflection

    attr_accessor :reflection, :scope
    def initialize(reflection,options)
      @reflection = reflection
      @scope      = options[:scope]
      @scope_tables[k][:table]       ||= options[:table]
      @scope_tables[k][:foreign_key] ||= "#{options[:table].singularize}_id"
      @scope_tables[k][:primary_key] ||= "id"
      
    end
    
  end
end