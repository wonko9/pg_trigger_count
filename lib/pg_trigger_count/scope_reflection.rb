class PgTriggerCount
  class ScopeReflection

    attr_accessor :reflection, :scope
    def initialize(reflection,scope)
      @reflection = reflection
      @scope      = scope      
    end
    
  end
end