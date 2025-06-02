# Scope management module for handling variable scoping and symbol table operations
module EvaluatorModules
  class ScopeManager
    attr_reader :variables, :scope_stack

    def initialize
      @variables = {}
      @scope_stack = []
    end

    def push_scope
      @scope_stack.push(@variables.dup)
    end

    def pop_scope
      if @scope_stack.empty?
        raise "Cannot pop scope: scope stack is empty"
      end
      @variables = @scope_stack.pop
    end

    def set_variable(name, value)
      @variables[name] = value
    end

    def get_variable(name)
      # Look in current scope first, then up the scope stack
      return @variables[name] if @variables.key?(name)

      # Search through scope stack from most recent to oldest
      @scope_stack.reverse_each do |scope|
        return scope[name] if scope.key?(name)
      end

      raise "Undefined variable: #{name}"
    end
  end
end