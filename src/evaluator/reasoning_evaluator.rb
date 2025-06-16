require_relative '../reasoning/type_constraint_system'
require_relative '../reasoning/unification_engine'
require_relative '../exceptions'

# Reasoning-aware evaluation module for handling constraint validation during evaluation
module EvaluatorModules
  class ReasoningEvaluator
    attr_reader :reasoning_mode_enabled, :constraint_system, :unification_engine
    
    def initialize(evaluator)
      @evaluator = evaluator
      @reasoning_mode_enabled = false
      @constraint_system = TypeConstraintSystem.new
      @unification_engine = UnificationEngine.new
      @performance_stats = {
        assignments_validated: 0,
        constraints_checked: 0,
        violations_detected: 0,
        reasoning_operations: 0,
        start_time: Time.now
      }
    end
    
    # Enable reasoning mode with constraint checking
    def enable_reasoning_mode
      @reasoning_mode_enabled = true
      @performance_stats[:reasoning_mode_enabled_at] = Time.now
    end
    
    # Disable reasoning mode
    def disable_reasoning_mode
      @reasoning_mode_enabled = false
      @performance_stats[:reasoning_mode_disabled_at] = Time.now
    end
    
    # Visit type constraint nodes from the AST
    def visit_type_constraint_node(node)
      unless @reasoning_mode_enabled
        raise ReasoningModeError, "Type constraints require reasoning mode to be enabled"
      end
      
      @performance_stats[:constraints_checked] += 1
      
      # Create constraint in the constraint system
      constraint = @constraint_system.create_constraint(
        node.variable,
        :type,
        node.constraint_type.to_sym,
        conditions: node.conditions
      )
      
      constraint
    end
    
    # Enhanced assignment validation with constraint checking
    def validate_assignment(variable_name, value)
      return true unless @reasoning_mode_enabled
      
      @performance_stats[:assignments_validated] += 1
      
      begin
        # Check if variable has constraints
        constraints = @constraint_system.get_constraints(variable_name)
        
        if constraints.any?
          # Validate against all constraints
          unless @constraint_system.satisfies_all_constraints?(variable_name, value)
            @performance_stats[:violations_detected] += 1
            
            # Create detailed error message
            violation_details = constraints.map do |constraint|
              unless constraint.satisfies?(value)
                "#{constraint.constraint_type} constraint (#{constraint.constraint_data}) violated"
              end
            end.compact
            
            raise ConstraintViolationError.new(
              "Assignment violates constraint for #{variable_name} = #{value.inspect}: #{violation_details.join(', ')}"
            )
          end
        end
        
        # Update constraint system with new value
        @constraint_system.set_variable_value(variable_name, value)
        
        true
      rescue => e
        @performance_stats[:violations_detected] += 1
        raise e
      end
    end
    
    # Create constraints programmatically
    def create_constraint(variable, constraint_type, constraint_data, **options)
      unless @reasoning_mode_enabled
        raise ReasoningModeError, "Constraint creation requires reasoning mode to be enabled"
      end
      
      @performance_stats[:reasoning_operations] += 1
      @constraint_system.create_constraint(variable, constraint_type, constraint_data, **options)
    end
    
    # Check if a variable satisfies its constraints
    def variable_satisfies_constraints?(variable, value)
      return true unless @reasoning_mode_enabled
      
      @constraint_system.satisfies_all_constraints?(variable, value)
    end
    
    # Get constraints for a variable
    def get_constraints(variable)
      @constraint_system.get_constraints(variable)
    end
    
    # Unify two terms using the unification engine
    def unify(term1, term2, substitution = {})
      unless @reasoning_mode_enabled
        raise ReasoningModeError, "Unification requires reasoning mode to be enabled"
      end
      
      @performance_stats[:reasoning_operations] += 1
      @unification_engine.unify(term1, term2, substitution)
    end
    
    # Propagate constraints through the system
    def propagate_constraints
      return unless @reasoning_mode_enabled
      
      @performance_stats[:reasoning_operations] += 1
      @constraint_system.propagate_constraints
    end
    
    # Add relationships between variables
    def add_variable_relationship(var1, var2)
      return unless @reasoning_mode_enabled
      
      @constraint_system.add_equality_relationship(var1, var2)
    end
    
    # Detect constraint conflicts
    def detect_constraint_conflicts(variable)
      return [] unless @reasoning_mode_enabled
      
      @constraint_system.detect_conflicts(variable)
    end
    
    # Enhanced assignment node evaluation with constraint checking
    def visit_assignment_node(node)
      value = @evaluator.evaluate(node.expression)
      
      # Validate assignment against reasoning constraints if enabled
      if @reasoning_mode_enabled
        validate_assignment(node.name, value)
      end
      
      # Set the variable in the evaluator's scope
      @evaluator.set_variable(node.name, value)
      value
    end
    
    # Visit goal nodes for goal-based reasoning
    def visit_goal_node(node)
      unless @reasoning_mode_enabled
        raise ReasoningModeError, "Goal declarations require reasoning mode to be enabled"
      end
      
      @performance_stats[:reasoning_operations] += 1
      
      # Create goal structure
      goal_data = {
        description: node.description,
        preconditions: node.preconditions || [],
        postconditions: node.postconditions || [],
        strategies: node.strategies || [],
        created_at: Time.now
      }
      
      goal_data
    end
    
    # Visit logic rule nodes
    def visit_logic_rule_node(node)
      unless @reasoning_mode_enabled
        raise ReasoningModeError, "Logic rules require reasoning mode to be enabled"
      end
      
      @performance_stats[:reasoning_operations] += 1
      
      # Create rule structure
      rule_data = {
        head: node.head,
        body: node.body,
        rule_type: node.rule_type || :standard,
        created_at: Time.now
      }
      
      rule_data
    end
    
    # Visit query nodes
    def visit_query_node(node)
      unless @reasoning_mode_enabled
        raise ReasoningModeError, "Logic queries require reasoning mode to be enabled"
      end
      
      @performance_stats[:reasoning_operations] += 1
      
      # Create query structure
      query_data = {
        goal_term: node.goal_term,
        variables: node.variables || [],
        query_type: node.query_type || :standard,
        executed_at: Time.now
      }
      
      # Return query result structure
      {
        query: query_data,
        results: [],  # Would be populated by actual query execution
        result_count: 0,
        executed_via: :reasoning_evaluator
      }
    end
    
    # Visit reasoning mode control nodes
    def visit_reasoning_mode_node(node)
      if node.enabled
        enable_reasoning_mode
      else
        disable_reasoning_mode
      end
      
      @reasoning_mode_enabled
    end
    
    # Get performance statistics
    def statistics
      current_time = Time.now
      uptime = current_time - @performance_stats[:start_time]
      
      @performance_stats.merge({
        reasoning_mode_enabled: @reasoning_mode_enabled,
        constraint_count: @constraint_system.constraint_count,
        uptime_seconds: uptime.round(2),
        operations_per_second: @performance_stats[:reasoning_operations] / [uptime, 1].max
      })
    end
    
    # Reset reasoning state
    def reset!
      @constraint_system = TypeConstraintSystem.new
      @unification_engine = UnificationEngine.new
      @performance_stats = {
        assignments_validated: 0,
        constraints_checked: 0,
        violations_detected: 0,
        reasoning_operations: 0,
        start_time: Time.now
      }
    end
    
    # Check if reasoning mode meets performance requirements
    def performance_acceptable?
      stats = statistics
      
      # Performance should be < 20% overhead for non-reasoning code
      return true unless stats[:uptime_seconds] > 1
      
      reasoning_overhead = (@performance_stats[:reasoning_operations].to_f / stats[:uptime_seconds])
      reasoning_overhead < 5.0  # Max 5 reasoning operations per second for acceptable performance
    end
  end
end