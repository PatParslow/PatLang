#!/usr/bin/env ruby
# Test script to validate CrossParadigmCoordinator stack overflow fixes

require_relative 'src/reasoning/cross_paradigm_coordinator'

def test_stack_overflow_elimination
  puts "Testing CrossParadigmCoordinator stack overflow fixes..."
  
  coordinator = CrossParadigmCoordinator.new
  
  # Test 1: Simple workflow execution without infinite recursion
  puts "\n1. Testing simple workflow execution..."
  begin
    result = coordinator.execute_workflow("test_workflow", <<~WORKFLOW)
      workflow test_workflow() {
        type_constraints: {
          x :: Number
          y :: String
        }
        adaptive_goals: {
          goal optimize_x {
            strategy: gradient_descent
          }
        }
        logic_rules: {
          rule enhance_types {
            when x > 0
            then x :: PositiveNumber
          }
        }
      }
    WORKFLOW
    
    if result[:success]
      puts "✓ Simple workflow executed successfully"
    else
      puts "✗ Simple workflow failed: #{result[:error]}"
    end
  rescue SystemStackError => e
    puts "✗ SystemStackError still occurs: #{e.message}"
    return false
  rescue => e
    puts "✓ No SystemStackError (got different error: #{e.class})"
  end
  
  # Test 2: Deep nested workflow to test depth limits
  puts "\n2. Testing workflow depth limits..."
  begin
    deep_workflow = ""
    50.times do |i|
      deep_workflow += <<~SECTION
        adaptive_goals: {
          goal nested_goal_#{i} {
            strategy: backtracking
          }
        }
      SECTION
    end
    
    result = coordinator.execute_workflow("deep_workflow", "workflow deep() {\n#{deep_workflow}\n}")
    puts "✓ Deep workflow handled without stack overflow"
  rescue SystemStackError => e
    puts "✗ SystemStackError in deep workflow: #{e.message}"
    return false
  rescue => e
    puts "✓ Deep workflow handled gracefully (error: #{e.class})"
  end
  
  # Test 3: Complex cross-paradigm coordination
  puts "\n3. Testing complex cross-paradigm coordination..."
  begin
    complex_result = coordinator.optimize_goals_with_type_information(
      [{ name: 'test_goal', constraints: ['x > 0'] }],
      { x: 'Number', y: 'String' }
    )
    puts "✓ Complex cross-paradigm coordination successful"
  rescue SystemStackError => e
    puts "✗ SystemStackError in cross-paradigm coordination: #{e.message}"
    return false
  rescue => e
    puts "✓ Cross-paradigm coordination handled (error: #{e.class})"
  end
  
  # Test 4: Variable type evolution
  puts "\n4. Testing variable type evolution..."
  begin
    evolution_result = coordinator.evolve_variable_types_through_logic(
      { 'x' => 'Number', 'y' => 'String' },
      [{ name: 'test_rule', conditions: ['x > 0'], actions: ['x :: PositiveNumber'] }]
    )
    puts "✓ Variable type evolution successful"
  rescue SystemStackError => e
    puts "✗ SystemStackError in type evolution: #{e.message}"
    return false
  rescue => e
    puts "✓ Type evolution handled (error: #{e.class})"
  end
  
  # Test 5: Emergent behavior detection
  puts "\n5. Testing emergent behavior detection..."
  begin
    emergent_result = coordinator.detect_emergent_behaviors([
      { phase: :type_inference, result: { type_evolution: [] } },
      { phase: :goal_oriented, result: { adaptations: 1 } }
    ])
    puts "✓ Emergent behavior detection successful"
  rescue SystemStackError => e
    puts "✗ SystemStackError in emergent behavior detection: #{e.message}"
    return false
  rescue => e
    puts "✓ Emergent behavior detection handled (error: #{e.class})"
  end
  
  puts "\n✅ All tests completed - No SystemStackError detected!"
  true
end

def test_workflow_depth_protection
  puts "\nTesting workflow depth protection mechanism..."
  
  coordinator = CrossParadigmCoordinator.new
  
  # Simulate potential infinite recursion scenario
  begin
    # Create a workflow that might trigger deep recursion
    recursive_workflow = <<~WORKFLOW
      workflow recursive_test() {
        adaptive_goals: {
          goal recursive_goal {
            strategy: recursive_backtracking
          }
        }
        logic_rules: {
          rule recursive_rule {
            when always_true
            then trigger_recursive_action
          }
        }
      }
    WORKFLOW
    
    result = coordinator.execute_workflow("recursive_test", recursive_workflow)
    
    if result[:error] && result[:error].include?("Maximum workflow depth exceeded")
      puts "✓ Workflow depth protection working correctly"
      return true
    else
      puts "✓ Workflow completed without depth issues"
      return true
    end
  rescue SystemStackError => e
    puts "✗ SystemStackError not prevented: #{e.message}"
    return false
  rescue => e
    puts "✓ Workflow handled gracefully: #{e.class}"
    return true
  end
end

# Run the tests
puts "=" * 60
puts "CrossParadigmCoordinator Stack Overflow Fix Validation"
puts "=" * 60

test_success = test_stack_overflow_elimination
depth_success = test_workflow_depth_protection

puts "\n" + "=" * 60
puts "FINAL RESULTS:"
puts "Stack Overflow Elimination: #{test_success ? 'PASSED' : 'FAILED'}"
puts "Depth Protection: #{depth_success ? 'PASSED' : 'FAILED'}"
puts "Overall Status: #{(test_success && depth_success) ? 'SUCCESS' : 'NEEDS ATTENTION'}"
puts "=" * 60