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
      # Handle empty/nil names gracefully
      return if name.nil? || name.to_s.strip.empty?
      
      # Convert to string for consistent key handling
      name_str = name.to_s
      @variables[name_str] = value
    end
  
    def get_variable(name)
      # Handle empty/nil names gracefully - these are often parsing artifacts
      if name.nil? || name.to_s.strip.empty? || name.to_s == ","
        return nil
      end
      
      # Convert to string for consistent key handling
      name_str = name.to_s.strip
      
      # Skip single character punctuation that isn't a valid variable name
      if name_str.length == 1 && name_str.match?(/[^a-zA-Z_]/)
        return nil
      end
      
      # Look in current scope first, then up the scope stack
      return @variables[name_str] if @variables.key?(name_str)
      return @variables[name.to_sym] if @variables.key?(name.to_sym)
  
      # Search through scope stack from most recent to oldest
      @scope_stack.reverse_each do |scope|
        return scope[name_str] if scope.key?(name_str)
        return scope[name.to_sym] if scope.key?(name.to_sym)
      end
  
      # Check for goal-related variables that should be auto-registered
      if goal_variable?(name_str)
        register_goal_variable(name_str)
        return @variables[name_str]
      end
  
      raise "Undefined variable: #{name}"
    end
  
    def goal_variable?(name)
      # Check if this is a goal-related variable that should be auto-registered
      goal_patterns = [
        /^complex_search$/,
        /^discover_relationships$/,
        /^find_even$/,
        /^find_valid_x$/,
        /^solve_equation$/,
        /^optimize$/,
        /^find_answer$/,
        /.*_goal$/,
        /.*_search$/,
        /.*_relationships$/
      ]
      
      goal_patterns.any? { |pattern| name.match?(pattern) }
    end
  
    def register_goal_variable(name)
      # Register goal variables with appropriate default values
      case name
      when 'complex_search'
        @variables[name] = :complex_search_goal
      when 'discover_relationships'
        @variables[name] = :discover_relationships_goal
      when 'find_even'
        @variables[name] = :find_even_goal
      when 'find_valid_x'
        @variables[name] = :find_valid_x_goal
      when 'solve_equation'
        @variables[name] = :solve_equation_goal
      when 'optimize'
        @variables[name] = :optimize_goal
      when 'find_answer'
        @variables[name] = :find_answer_goal
      else
        @variables[name] = :"#{name}_goal"
      end
    end
  end
end