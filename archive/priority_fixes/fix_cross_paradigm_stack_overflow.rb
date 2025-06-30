#!/usr/bin/env ruby

# Fix 1: CrossParadigmCoordinator Stack Overflow
# Issue: Multiple misplaced @workflow_depth -= 1 statements causing stack issues

puts "🔧 FIX 1: CrossParadigmCoordinator Stack Overflow"
puts "=================================================="

# Read the current problematic file
cross_paradigm_content = File.read('src/reasoning/cross_paradigm_coordinator.rb')

# The issue is on lines 468, 471, 485, 487, 490, 504, 506, 509, 519
# These are misplaced @workflow_depth -= 1 statements that should be removed

fixed_content = cross_paradigm_content.dup

# Remove the problematic lines - they appear as standalone statements
problematic_lines = [
  "      @workflow_depth -= 1 if @workflow_depth > 0\n    end",
  "      @workflow_depth -= 1 if @workflow_depth > 0\n    end\n      @workflow_depth -= 1 if @workflow_depth > 0\n    end",
  "      @workflow_depth -= 1 if @workflow_depth > 0\n    end\n       @workflow_depth -= 1 if @workflow_depth > 0\n    end",
  "      @workflow_depth -= 1 if @workflow_depth > 0\n    end\n    logic_result\n      @workflow_depth -= 1 if @workflow_depth > 0\n    end",
  "      @workflow_depth -= 1 if @workflow_depth > 0\n    end"
]

# Clean up the execute_type_inference_phase method
fixed_content.gsub!(/def execute_type_inference_phase\(parsed_workflow, execution_context\)\s+type_result = \{ type_evolution: \[\], constraints_processed: 0 \}\s+# Process type constraints and evolve types through logic\s+if parsed_workflow\[:components\]\[:type_constraints\]\s+constraints = parsed_workflow\[:components\]\[:type_constraints\]\s+logic_rules = parsed_workflow\[:components\]\[:type_refinement_rules\] \|\| \[\]\s+# Evolve variable types through logic satisfaction\s+evolution_result = evolve_variable_types_through_logic\(\s+execution_context\[:variables\],\s+logic_rules\s+\)\s+type_result\[:type_evolution\] = evolution_result\[:type_evolution\]\s+type_result\[:constraints_processed\] = constraints\.length\s+@workflow_depth -= 1 if @workflow_depth > 0\s+end\s+type_result\s+@workflow_depth -= 1 if @workflow_depth > 0\s+end/m) do
  <<~'RUBY'
def execute_type_inference_phase(parsed_workflow, execution_context)
    type_result = { type_evolution: [], constraints_processed: 0 }
    
    # Process type constraints and evolve types through logic
    if parsed_workflow[:components][:type_constraints]
      constraints = parsed_workflow[:components][:type_constraints]
      logic_rules = parsed_workflow[:components][:type_refinement_rules] || []
      
      # Evolve variable types through logic satisfaction
      evolution_result = evolve_variable_types_through_logic(
        execution_context[:variables], 
        logic_rules
      )
      
      type_result[:type_evolution] = evolution_result[:type_evolution]
      type_result[:constraints_processed] = constraints.length
    end
    type_result
  end
  RUBY
end

# Clean up the execute_goal_oriented_phase method
fixed_content.gsub!(/def execute_goal_oriented_phase\(parsed_workflow, execution_context\).*?goal_result\s+@workflow_depth -= 1 if @workflow_depth > 0\s+end/m) do
  <<~'RUBY'
def execute_goal_oriented_phase(parsed_workflow, execution_context)
    goal_result = { adaptations: 0, goals_executed: [] }
    
    # Execute adaptive goals with type-guided optimization
    if parsed_workflow[:components][:adaptive_goals]
      goals = parsed_workflow[:components][:adaptive_goals]
      
      goals.each do |goal_def|
        # Execute goal with cross-paradigm coordination
        goal_execution = execute_cross_paradigm_goal(goal_def, execution_context)
        goal_result[:goals_executed] << goal_execution
        goal_result[:adaptations] += goal_execution[:adaptations] || 0
      end
    end
    goal_result
  end
  RUBY
end

# Clean up the execute_logic_programming_phase method
fixed_content.gsub!(/def execute_logic_programming_phase\(parsed_workflow, execution_context\).*?logic_result\s+@workflow_depth -= 1 if @workflow_depth > 0\s+end/m) do
  <<~'RUBY'
def execute_logic_programming_phase(parsed_workflow, execution_context)
    logic_result = { rules_applied: 0, inferences_made: [] }
    
    # Apply logic rules with constraint enhancement
    if parsed_workflow[:components][:logic_rules]
      rules = parsed_workflow[:components][:logic_rules]
      
      rules.each do |rule|
        # Apply rule with cross-paradigm context
        rule_result = apply_cross_paradigm_rule(rule, execution_context)
        logic_result[:inferences_made] << rule_result
        logic_result[:rules_applied] += 1
      end
    end
    logic_result
  end
  RUBY
end

# Clean up the execute_cross_paradigm_goal method
fixed_content.gsub!(/def execute_cross_paradigm_goal\(goal_def, execution_context\).*?@workflow_depth -= 1 if @workflow_depth > 0\s+end/m) do
  <<~'RUBY'
def execute_cross_paradigm_goal(goal_def, execution_context)
    {
      goal: goal_def[:name],
      execution_strategy: :cross_paradigm_adaptive,
      adaptations: 1,
      success: true,
      cross_paradigm_optimized: true
    }
  end
  RUBY
end

# Write the fixed content
File.write('src/reasoning/cross_paradigm_coordinator.rb', fixed_content)

puts "✅ Fixed CrossParadigmCoordinator stack overflow issue"
puts "   - Removed misplaced @workflow_depth -= 1 statements"
puts "   - Cleaned up method structures"
puts "   - Depth tracking now only in main execute_workflow method"
puts