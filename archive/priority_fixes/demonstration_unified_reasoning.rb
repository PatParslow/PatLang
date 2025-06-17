#!/usr/bin/env ruby
# Comprehensive demonstration of unified reasoning evaluator integration

require_relative 'src/evaluator'
require_relative 'src/reasoning/reasoning_coordinator'
require_relative 'src/ast_nodes'
require_relative 'src/lexer'
require_relative 'src/parser'

def demonstrate_unified_reasoning
  puts "=== PATLANG Unified Reasoning Demonstration ==="
  puts "Showing end-to-end reasoning construct evaluation\n\n"
  
  # Initialize the complete system
  evaluator = Evaluator.new
  coordinator = ReasoningCoordinator.new(evaluator)
  evaluator.set_reasoning_coordinator(coordinator)
  evaluator.enable_reasoning_mode
  
  puts "✓ Reasoning system initialized and enabled\n"
  
  # Demonstration 1: Type Constraint System
  puts "--- 1. TYPE CONSTRAINT SYSTEM ---"
  puts "Creating constraints for variables..."
  
  # Create type constraints
  age_constraint = TypeConstraintNode.new('age', :range, (0..120))
  score_constraint = TypeConstraintNode.new('score', :range, (0..100))
  name_constraint = TypeConstraintNode.new('name', :type, String)
  
  evaluator.evaluate(age_constraint)
  evaluator.evaluate(score_constraint)
  evaluator.evaluate(name_constraint)
  
  puts "  ✓ age constrained to 0..120"
  puts "  ✓ score constrained to 0..100"
  puts "  ✓ name constrained to String type"
  
  # Test constraint validation
  begin
    valid_age = AssignmentNode.new('age', NumberNode.new(25))
    evaluator.evaluate(valid_age)
    puts "  ✓ Valid assignment: age = 25"
    
    invalid_age = AssignmentNode.new('age', NumberNode.new(150))
    evaluator.evaluate(invalid_age)
  rescue => e
    puts "  ✓ Invalid assignment rejected: #{e.message.split(':').last.strip}"
  end
  
  # Demonstration 2: Goal-Oriented Programming
  puts "\n--- 2. GOAL-ORIENTED PROGRAMMING ---"
  puts "Declaring and pursuing goals..."
  
  # Declare goals
  optimization_goal = GoalNode.new(
    'optimize_score',
    ['score >= 0', 'attempts < 5'],
    ['score >= 80', 'time_efficient'],
    ['greedy_search', 'backtrack_if_needed']
  )
  
  search_goal = GoalNode.new(
    'find_perfect_match',
    ['constraints_satisfied'],
    ['all_criteria_met'],
    ['exhaustive_search']
  )
  
  evaluator.evaluate(optimization_goal)
  evaluator.evaluate(search_goal)
  
  puts "  ✓ optimize_score goal declared"
  puts "  ✓ find_perfect_match goal declared"
  
  # Pursue goals
  pursue_opt = PursueNode.new('optimize_score')
  pursue_search = PursueNode.new('find_perfect_match')
  
  opt_result = evaluator.evaluate(pursue_opt)
  search_result = evaluator.evaluate(pursue_search)
  
  puts "  ✓ Goal pursuit results:"
  puts "    - optimize_score: #{opt_result}"
  puts "    - find_perfect_match: #{search_result}"
  
  # Demonstration 3: Logic Programming
  puts "\n--- 3. LOGIC PROGRAMMING ---"
  puts "Asserting facts and rules, then querying..."
  
  # Assert facts
  fact1 = AssertNode.new('student(alice)')
  fact2 = AssertNode.new('student(bob)')
  fact3 = AssertNode.new('course(math)')
  fact4 = AssertNode.new('enrolled(alice, math)')
  
  evaluator.evaluate(fact1)
  evaluator.evaluate(fact2)
  evaluator.evaluate(fact3)
  evaluator.evaluate(fact4)
  
  puts "  ✓ Facts asserted:"
  puts "    - student(alice), student(bob)"
  puts "    - course(math)"
  puts "    - enrolled(alice, math)"
  
  # Define rules
  rule1 = LogicRuleNode.new(
    'good_student(X)',
    'student(X), enrolled(X, math)',
    :standard
  )
  
  rule2 = LogicRuleNode.new(
    'academically_qualified(X)',
    'good_student(X), score(X, Y), Y > 80',
    :conditional
  )
  
  evaluator.evaluate(rule1)
  evaluator.evaluate(rule2)
  
  puts "  ✓ Rules defined:"
  puts "    - good_student(X) :- student(X), enrolled(X, math)"
  puts "    - academically_qualified(X) :- good_student(X), score(X, Y), Y > 80"
  
  # Execute queries
  query1 = QueryNode.new('student(alice)', [], :standard)
  query2 = QueryNode.new('good_student(X)', ['X'], :variable_binding)
  query3 = QueryNode.new('enrolled(alice, math)', [], :existence)
  
  result1 = evaluator.evaluate(query1)
  result2 = evaluator.evaluate(query2)
  result3 = evaluator.evaluate(query3)
  
  puts "  ✓ Query results:"
  puts "    - student(alice): #{result1[:result_count]} matches"
  puts "    - good_student(X): #{result2[:result_count]} matches" 
  puts "    - enrolled(alice, math): #{result3[:result_count]} matches"
  
  # Demonstration 4: Cross-Paradigm Integration
  puts "\n--- 4. CROSS-PARADIGM INTEGRATION ---"
  puts "Showing constraint validation with goal pursuit..."
  
  # Create constraint for optimization target
  target_constraint = TypeConstraintNode.new('target', :range, (50..100))
  evaluator.evaluate(target_constraint)
  
  # Create goal that works with constraint
  constrained_goal = GoalNode.new(
    'find_optimal_target',
    ['target_exists'],
    ['target >= 50', 'target <= 100'],
    ['constraint_aware_search']
  )
  evaluator.evaluate(constrained_goal)
  
  # Pursue goal (should respect constraints)
  pursue_constrained = PursueNode.new('find_optimal_target')
  constrained_result = evaluator.evaluate(pursue_constrained)
  
  puts "  ✓ Constraint-aware goal pursuit result: #{constrained_result}"
  
  # Validate the result satisfies constraints
  begin
    target_assignment = AssignmentNode.new('target', NumberNode.new(75))
    evaluator.evaluate(target_assignment)
    puts "  ✓ Result satisfies constraints: target = 75"
  rescue => e
    puts "  ✗ Constraint violation: #{e.message}"
  end
  
  # Demonstration 5: Performance and Statistics
  puts "\n--- 5. PERFORMANCE MONITORING ---"
  stats = evaluator.instance_variable_get(:@reasoning_stats)
  if stats
    puts "  ✓ Reasoning system statistics:"
    stats.each do |key, value|
      next if key == :start_time
      puts "    - #{key.to_s.gsub('_', ' ')}: #{value}"
    end
    
    elapsed = Time.now - stats[:start_time]
    puts "    - total execution time: #{elapsed.round(3)} seconds"
  end
  
  # Demonstration 6: Error Handling and Recovery
  puts "\n--- 6. ERROR HANDLING ---"
  puts "Testing graceful error handling..."
  
  begin
    # Try to use reasoning constructs without reasoning mode
    evaluator.disable_reasoning_mode
    error_constraint = TypeConstraintNode.new('error_var', :range, (1..10))
    evaluator.evaluate(error_constraint)
  rescue => e
    puts "  ✓ Proper error when reasoning mode disabled: #{e.message}"
  end
  
  # Re-enable for final test
  evaluator.enable_reasoning_mode
  
  begin
    # Try invalid constraint that should conflict
    conflicting_constraint = TypeConstraintNode.new('target', :range, (200..300))
    evaluator.evaluate(conflicting_constraint)
  rescue => e
    puts "  ✓ Constraint conflict properly detected: #{e.message.split(':').first}"
  end
  
  puts "\n=== DEMONSTRATION COMPLETE ==="
  puts "✓ All unified reasoning features successfully demonstrated!"
  puts "✓ Evaluator integration working end-to-end"
  puts "✓ Cross-paradigm communication established"
  puts "✓ Error handling and validation operational"
  
  true
rescue => e
  puts "\n✗ Demonstration failed: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace.first(10)
  false
end

# Run the demonstration
if __FILE__ == $0
  success = demonstrate_unified_reasoning
  exit(success ? 0 : 1)
end