#!/usr/bin/env ruby

# Runtime Error Analysis - Extracting the 15 specific ERROR instances from test output
# Focus: Systematic categorization and prioritization

puts "🔍 ANALYZING 15 RUNTIME ERRORS FROM TEST SUITE"
puts "=" * 60

# Extract the 15 runtime ERROR instances from the test output
runtime_errors = [
  {
    id: 1,
    test: "TestCrossParadigmCoordination#test_large_scale_cross_paradigm_coordination",
    error_type: "NoMethodError",
    message: "undefined method `[]' for nil",
    file: "patlang_language/test_cross_paradigm_coordination.rb",
    line: 526,
    pattern: "nil_access"
  },
  {
    id: 2,
    test: "TestCrossParadigmCoordination#test_learning_better_constraint_patterns",
    error_type: "NoMethodError", 
    message: "undefined method `length' for nil",
    file: "patlang_language/test_cross_paradigm_coordination.rb",
    line: 426,
    pattern: "nil_access"
  },
  {
    id: 3,
    test: "TestReasoningIntegration#test_goal_resolution_with_backtracking_performance",
    error_type: "RuntimeError",
    message: "Undefined variable: complex_search",
    file: "E:/patlang/src/evaluator/scope_manager.rb",
    line: 35,
    pattern: "undefined_variable"
  },
  {
    id: 4,
    test: "TestReasoningIntegration#test_rule_definition",
    error_type: "RuntimeError",
    message: "Expected method name after '.' at token Token(RULE, rule)",
    file: "E:/patlang/src/parser/expression_parser.rb", 
    line: 205,
    pattern: "parser_error"
  },
  {
    id: 5,
    test: "TestReasoningIntegration#test_constraint_with_range_condition",
    error_type: "NoMethodError",
    message: "undefined method `empty?' for nil",
    file: "E:/patlang/src/reasoning/type_constraint.rb",
    line: 247,
    pattern: "nil_access"
  },
  {
    id: 6,
    test: "TestReasoningIntegration#test_invalid_constraint_syntax_reports_error",
    error_type: "NameError",
    message: "uninitialized constant TestReasoningIntegration::ParseError",
    file: "patlang_language/test_reasoning_integration.rb",
    line: 329,
    pattern: "missing_constant"
  },
  {
    id: 7,
    test: "TestReasoningIntegration#test_goal_driven_fact_discovery",
    error_type: "RuntimeError",
    message: "Undefined variable: ,",
    file: "E:/patlang/src/evaluator/scope_manager.rb",
    line: 35,
    pattern: "undefined_variable"
  },
  {
    id: 8,
    test: "TestReasoningIntegration#test_malformed_goal_syntax_reports_location",
    error_type: "NameError",
    message: "uninitialized constant TestReasoningIntegration::ParseError",
    file: "patlang_language/test_reasoning_integration.rb",
    line: 345,
    pattern: "missing_constant"
  },
  {
    id: 9,
    test: "TestReasoningIntegration#test_structural_type_constraint",
    error_type: "RuntimeError",
    message: "Invalid character '\\' at position 118",
    file: "E:/patlang/src/lexer.rb",
    line: 15,
    pattern: "lexer_error"
  },
  {
    id: 10,
    test: "TestReasoningIntegration#test_reasoning_with_object_mode_variables",
    error_type: "NoMethodError",
    message: "undefined method `>' for nil",
    file: "patlang_language/test_reasoning_integration.rb",
    line: 385,
    pattern: "nil_access"
  },
  {
    id: 11,
    test: "TestReasoningIntegration#test_large_fact_database_query_performance",
    error_type: "RuntimeError",
    message: "Unexpected token in factor at token Token(WHERE, where)",
    file: "E:/patlang/src/parser/expression_parser.rb",
    line: 362,
    pattern: "parser_error"
  },
  {
    id: 12,
    test: "TestUnificationEngine#test_multiple_unifications_generate_unique_events",
    error_type: "Error",
    message: "Event IDs should be unique. Expected: 2 Actual: 4",
    file: "infrastructure/test_unification_engine.rb",
    line: 178,
    pattern: "event_system_bug"
  },
  {
    id: 13,
    test: "TestEvaluatorReasoning#test_patlang_evaluate_with_facts_database",
    error_type: "RuntimeError",
    message: "Undefined variable: database",
    file: "E:/patlang/src/evaluator/scope_manager.rb",
    line: 35,
    pattern: "undefined_variable"
  },
  {
    id: 14,
    test: "TestTypeConstraints#test_propagation_performance_scales_with_network_size",
    error_type: "Error",
    message: "Expected: 100 Actual: nil",
    file: "ruby_implementation/test_type_constraints.rb",
    line: 282,
    pattern: "nil_return"
  },
  {
    id: 15,
    test: "TestAdvancedGoalStrategies#test_real_time_goal_adaptation_under_changing_conditions",
    error_type: "Error", 
    message: "Expected false to be truthy",
    file: "ruby_implementation/test_advanced_goal_strategies.rb",
    line: 384,
    pattern: "logical_error"
  }
]

puts "\n📊 ERROR CATEGORIZATION BY TYPE:"
puts "-" * 40

# Group by error pattern
error_patterns = runtime_errors.group_by { |e| e[:pattern] }

error_patterns.each do |pattern, errors|
  puts "\n🔸 #{pattern.upcase} (#{errors.size} errors):"
  errors.each { |e| puts "   #{e[:id]}. #{e[:error_type]}: #{e[:message]}" }
end

puts "\n🎯 PRIORITY ANALYSIS:"
puts "-" * 40

# Priority 1: High Impact Clusters (multiple errors, same root cause)
priority_1 = [
  {
    cluster: "NIL_ACCESS_CLUSTER",
    count: 4,
    errors: [1, 2, 5, 10],
    impact: "HIGH - 4 errors from nil variable access",
    complexity: "LOW - Add nil guards",
    files: ["test_cross_paradigm_coordination.rb", "type_constraint.rb"],
    fix_strategy: "Add nil validation before method calls"
  },
  {
    cluster: "UNDEFINED_VARIABLE_CLUSTER", 
    count: 3,
    errors: [3, 7, 13],
    impact: "HIGH - 3 errors from scope/variable issues",
    complexity: "MEDIUM - Variable scoping fixes",
    files: ["scope_manager.rb"],
    fix_strategy: "Fix variable resolution and goal registration"
  },
  {
    cluster: "PARSER_ERROR_CLUSTER",
    count: 2, 
    errors: [4, 11],
    impact: "MEDIUM - 2 parsing failures",
    complexity: "MEDIUM - Parser grammar fixes", 
    files: ["expression_parser.rb"],
    fix_strategy: "Fix rule/query parsing syntax"
  },
  {
    cluster: "MISSING_CONSTANT_CLUSTER",
    count: 2,
    errors: [6, 8],
    impact: "LOW - 2 test-specific constant errors",
    complexity: "LOW - Define missing constants",
    files: ["test_reasoning_integration.rb"],
    fix_strategy: "Define ParseError constant for tests"
  }
]

# Priority 2: Individual Issues
priority_2 = [
  {
    cluster: "LEXER_ERROR",
    count: 1, 
    errors: [9],
    impact: "MEDIUM - Regex pattern parsing",
    complexity: "LOW - Escape character handling",
    files: ["lexer.rb"],
    fix_strategy: "Fix backslash escape handling"
  },
  {
    cluster: "EVENT_SYSTEM_BUG",
    count: 1,
    errors: [12], 
    impact: "LOW - Event ID uniqueness",
    complexity: "LOW - UUID generation fix",
    files: ["unification_engine.rb"],
    fix_strategy: "Ensure unique event ID generation"
  },
  {
    cluster: "NIL_RETURN_BUG",
    count: 1,
    errors: [14],
    impact: "LOW - Performance test returns nil",
    complexity: "LOW - Return value fix",
    files: ["test_type_constraints.rb"],
    fix_strategy: "Fix method to return expected value"
  },
  {
    cluster: "LOGICAL_ERROR",
    count: 1,
    errors: [15],
    impact: "LOW - Test expectation mismatch", 
    complexity: "LOW - Test logic fix",
    files: ["test_advanced_goal_strategies.rb"],
    fix_strategy: "Fix test assertion logic"
  }
]

puts "\n🥇 PRIORITY 1 - HIGH IMPACT CLUSTERS:"
priority_1.each_with_index do |cluster, i|
  puts "\n#{i+1}. #{cluster[:cluster]} (#{cluster[:count]} errors)"
  puts "   Impact: #{cluster[:impact]}" 
  puts "   Complexity: #{cluster[:complexity]}"
  puts "   Files: #{cluster[:files].join(', ')}"
  puts "   Strategy: #{cluster[:fix_strategy]}"
  puts "   Error IDs: #{cluster[:errors].join(', ')}"
end

puts "\n🥈 PRIORITY 2 - INDIVIDUAL ISSUES:"
priority_2.each_with_index do |cluster, i|
  puts "\n#{i+1}. #{cluster[:cluster]} (#{cluster[:count]} error)"
  puts "   Impact: #{cluster[:impact]}"
  puts "   Complexity: #{cluster[:complexity]}" 
  puts "   Files: #{cluster[:files].join(', ')}"
  puts "   Strategy: #{cluster[:fix_strategy]}"
  puts "   Error IDs: #{cluster[:errors].join(', ')}"
end

puts "\n🎯 RECOMMENDED IMPLEMENTATION ORDER:"
puts "-" * 50
puts "1. NIL_ACCESS_CLUSTER (4 errors) - Quick nil guard fixes"
puts "2. UNDEFINED_VARIABLE_CLUSTER (3 errors) - Variable scoping"  
puts "3. MISSING_CONSTANT_CLUSTER (2 errors) - Define ParseError"
puts "4. PARSER_ERROR_CLUSTER (2 errors) - Grammar fixes"
puts "5. LEXER_ERROR (1 error) - Escape character handling"
puts "6. Remaining individual issues (3 errors)"

puts "\n📈 ESTIMATED IMPACT:"
puts "-" * 30
puts "• Priority 1 fixes: 11/15 errors (73% reduction)"
puts "• All fixes: 15/15 errors (100% reduction)"
puts "• Test improvement: ~17% error rate reduction"

puts "\n✅ ANALYSIS COMPLETE!"