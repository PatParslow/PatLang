#!/usr/bin/env ruby
# Test script to validate evaluator reasoning integration

require_relative 'src/evaluator'
require_relative 'src/reasoning/reasoning_coordinator'
require_relative 'src/ast_nodes'

def test_evaluator_reasoning_integration
  puts "Testing Evaluator Reasoning Integration..."
  
  # Initialize evaluator
  evaluator = Evaluator.new
  
  # Initialize reasoning coordinator
  coordinator = ReasoningCoordinator.new(evaluator)
  
  # Set up the integration
  evaluator.set_reasoning_coordinator(coordinator)
  
  # Enable reasoning mode
  result = evaluator.enable_reasoning_mode
  puts "✓ Reasoning mode enabled: #{result}"
  
  # Test 1: Type Constraint Evaluation
  puts "\n--- Test 1: Type Constraint Evaluation ---"
  begin
    constraint_node = TypeConstraintNode.new('x', :range, (1..100))
    result = evaluator.evaluate(constraint_node)
    puts "✓ Type constraint created: #{result.class}"
  rescue => e
    puts "✗ Type constraint failed: #{e.message}"
  end
  
  # Test 2: Goal System Evaluation
  puts "\n--- Test 2: Goal System Evaluation ---"
  begin
    goal_node = GoalNode.new(
      'find_answer', 
      ['x > 0'], 
      ['x < 100'], 
      ['search', 'optimize']
    )
    result = evaluator.evaluate(goal_node)
    puts "✓ Goal declared: #{result.class} - #{result.respond_to?(:name) ? result.name : result[:description]}"
  rescue => e
    puts "✗ Goal declaration failed: #{e.message}"
  end
  
  # Test 3: Logic Rule Evaluation
  puts "\n--- Test 3: Logic Rule Evaluation ---"
  begin
    rule_node = LogicRuleNode.new('likes(X, Y)', 'friend(X, Y)', :standard)
    result = evaluator.evaluate(rule_node)
    puts "✓ Logic rule asserted: #{result[:head]} :- #{result[:body]}"
  rescue => e
    puts "✗ Logic rule failed: #{e.message}"
  end
  
  # Test 4: Query Evaluation
  puts "\n--- Test 4: Query Evaluation ---"
  begin
    query_node = QueryNode.new('likes(alice, bob)', ['X', 'Y'], :standard)
    result = evaluator.evaluate(query_node)
    puts "✓ Query executed: #{result[:result_count]} results via #{result[:executed_via]}"
  rescue => e
    puts "✗ Query failed: #{e.message}"
  end
  
  # Test 5: Goal Pursuit Integration
  puts "\n--- Test 5: Goal Pursuit Integration ---"
  begin
    pursue_node = PursueNode.new('find_answer')
    result = evaluator.evaluate(pursue_node)
    puts "✓ Goal pursued with result: #{result}"
  rescue => e
    puts "✗ Goal pursuit failed: #{e.message}"
  end
  
  # Test 6: Constraint Validation in Assignment
  puts "\n--- Test 6: Constraint Validation in Assignment ---"
  begin
    # First create a constraint
    constraint_node = TypeConstraintNode.new('test_var', :range, (1..10))
    evaluator.evaluate(constraint_node)
    
    # Then try assignment within range
    assignment_node = AssignmentNode.new('test_var', NumberNode.new(5))
    result = evaluator.evaluate(assignment_node)
    puts "✓ Valid assignment succeeded: test_var = #{result}"
    
    # Try assignment outside range (should fail gracefully)
    assignment_node2 = AssignmentNode.new('test_var', NumberNode.new(15))
    begin
      result2 = evaluator.evaluate(assignment_node2)
      puts "? Assignment outside range unexpectedly succeeded: test_var = #{result2}"
    rescue => constraint_error
      puts "✓ Invalid assignment properly rejected: #{constraint_error.message}"
    end
  rescue => e
    puts "✗ Constraint validation test failed: #{e.message}"
  end
  
  # Test 7: Cross-paradigm Communication
  puts "\n--- Test 7: Cross-paradigm Communication ---"
  begin
    # Assert a fact
    assert_node = AssertNode.new('friend(alice, bob)')
    evaluator.evaluate(assert_node)
    
    # Query for the fact
    query_node = QueryNode.new('friend(alice, bob)', [], :standard)
    result = evaluator.evaluate(query_node)
    puts "✓ Cross-paradigm fact/query: #{result[:result_count]} matches"
  rescue => e
    puts "✗ Cross-paradigm communication failed: #{e.message}"
  end
  
  # Test 8: Performance Monitoring
  puts "\n--- Test 8: Performance Monitoring ---"
  if evaluator.instance_variable_get(:@reasoning_stats)
    stats = evaluator.instance_variable_get(:@reasoning_stats)
    puts "✓ Performance stats available:"
    stats.each { |key, value| puts "  #{key}: #{value}" }
  else
    puts "? Performance monitoring not initialized"
  end
  
  puts "\n✓ All evaluator reasoning integration tests completed!"
  true
rescue => e
  puts "\n✗ Integration test failed: #{e.message}"
  puts e.backtrace.first(5)
  false
end

# Run the test
if __FILE__ == $0
  success = test_evaluator_reasoning_integration
  exit(success ? 0 : 1)
end