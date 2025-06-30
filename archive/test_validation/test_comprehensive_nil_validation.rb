#!/usr/bin/env ruby

require_relative 'src/reasoning/cross_paradigm_coordinator'

# Comprehensive test for all nil handling scenarios
puts "Comprehensive nil handling validation for CrossParadigmCoordinator..."

coordinator = CrossParadigmCoordinator.new

test_count = 0
pass_count = 0

def run_test(test_name, &block)
  puts "\n#{test_name}..."
  begin
    yield
    puts "✓ PASS"
    return true
  rescue => e
    puts "✗ FAIL: #{e.message}"
    puts "  #{e.backtrace.first}"
    return false
  end
end

# Test 1: Various nil scenarios in analyze_logic_implications
pass_count += 1 if run_test("1. analyze_logic_implications with nil logic_context") do
  result = coordinator.send(:analyze_logic_implications, "test_constraint", nil)
  raise "Expected empty array" unless result == []
end
test_count += 1

pass_count += 1 if run_test("2. analyze_logic_implications with empty logic_context") do
  result = coordinator.send(:analyze_logic_implications, "test_constraint", [])
  raise "Expected empty array" unless result == []
end
test_count += 1

# Test 2: Various nil scenarios in analyze_cross_paradigm_interactions
pass_count += 1 if run_test("3. analyze_cross_paradigm_interactions with nil execution_history") do
  result = coordinator.send(:analyze_cross_paradigm_interactions, nil)
  raise "Expected empty array" unless result == []
end
test_count += 1

pass_count += 1 if run_test("4. analyze_cross_paradigm_interactions with empty execution_history") do
  result = coordinator.send(:analyze_cross_paradigm_interactions, [])
  raise "Expected empty array" unless result == []
end
test_count += 1

# Test 3: Various nil scenarios in detect_self_optimization_patterns
pass_count += 1 if run_test("5. detect_self_optimization_patterns with nil execution_history") do
  result = coordinator.send(:detect_self_optimization_patterns, nil)
  raise "Expected empty array" unless result == []
end
test_count += 1

pass_count += 1 if run_test("6. detect_self_optimization_patterns with empty execution_history") do
  result = coordinator.send(:detect_self_optimization_patterns, [])
  raise "Expected empty array" unless result == []
end
test_count += 1

# Test 4: Various nil scenarios in select_strategies_by_types
pass_count += 1 if run_test("7. select_strategies_by_types with nil type_analysis") do
  result = coordinator.send(:select_strategies_by_types, {}, nil)
  raise "Expected empty array" unless result == []
end
test_count += 1

pass_count += 1 if run_test("8. select_strategies_by_types with type_analysis missing relevant_types") do
  result = coordinator.send(:select_strategies_by_types, {}, {})
  raise "Expected empty array" unless result == []
end
test_count += 1

pass_count += 1 if run_test("9. select_strategies_by_types with nil relevant_types") do
  result = coordinator.send(:select_strategies_by_types, {}, { relevant_types: nil })
  raise "Expected empty array" unless result == []
end
test_count += 1

# Test 5: Test synthesize_cross_paradigm_results with nil execution_history
pass_count += 1 if run_test("10. synthesize_cross_paradigm_results with nil execution_history") do
  result = coordinator.send(:synthesize_cross_paradigm_results, nil)
  raise "Should handle nil execution_history" unless result[:executed_goals] == []
end
test_count += 1

# Test 6: Test detect_emergent_behaviors with nil execution_history
pass_count += 1 if run_test("11. detect_emergent_behaviors with nil execution_history") do
  result = coordinator.detect_emergent_behaviors(nil)
  raise "Should handle nil execution_history" unless result == []
end
test_count += 1

# Test 7: Test enhance_constraints_with_logic_rules with nil logic_context
pass_count += 1 if run_test("12. enhance_constraints_with_logic_rules with nil logic_context") do
  constraints = [{ variable: "x", type: "Number" }]
  result = coordinator.enhance_constraints_with_logic_rules(constraints, nil)
  raise "Should handle nil logic_context" unless result[:enhanced_constraints].length >= constraints.length
end
test_count += 1

# Test 8: Test optimize_goals_with_type_information with various nil scenarios
pass_count += 1 if run_test("13. optimize_goals_with_type_information with nil type_context") do
  goals = [{ name: "test" }]
  result = coordinator.optimize_goals_with_type_information(goals, nil)
  raise "Should handle nil type_context" unless result.is_a?(Array)
end
test_count += 1

puts "\n" + "="*50
puts "COMPREHENSIVE NIL HANDLING VALIDATION RESULTS"
puts "="*50
puts "Tests passed: #{pass_count}/#{test_count}"
puts "Success rate: #{'%.1f' % (pass_count.to_f / test_count * 100)}%"

if pass_count == test_count
  puts "🎉 ALL TESTS PASSED - Nil handling is robust!"
else
  puts "⚠️  Some tests failed - Review nil handling implementation"
  exit 1
end