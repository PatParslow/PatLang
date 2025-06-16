#!/usr/bin/env ruby

# Extract the 22 ERROR entries from the test output
# Chain of Drafts: Test output shows 22 errors, extracting ERROR messages

error_entries = [
  {
    number: 1,
    test_class: "TestLexer",
    test_method: "test_lexer_position_tracking_with_complex_tokens",
    file: "test/infrastructure/test_lexer.rb:238",
    error_type: "NoMethodError",
    message: "undefined method `character' for nil:NilClass",
    stack_trace: "src/lexer.rb:165:in `current_position'"
  },
  {
    number: 2,
    test_class: "TestLexer", 
    test_method: "test_lexer_position_tracking_basic",
    file: "test/infrastructure/test_lexer.rb:219",
    error_type: "NoMethodError",
    message: "undefined method `character' for nil:NilClass",
    stack_trace: "src/lexer.rb:165:in `current_position'"
  },
  {
    number: 3,
    test_class: "TestLexer",
    test_method: "test_lexer_position_tracking_with_newlines", 
    file: "test/infrastructure/test_lexer.rb:257",
    error_type: "NoMethodError",
    message: "undefined method `character' for nil:NilClass",
    stack_trace: "src/lexer.rb:165:in `current_position'"
  },
  {
    number: 4,
    test_class: "TestParser",
    test_method: "test_parser_handles_incomplete_binary_operations",
    file: "test/infrastructure/test_parser.rb:439",
    error_type: "ArgumentError", 
    message: "wrong number of arguments (given 1, expected 2)",
    stack_trace: "src/parser.rb:311:in `initialize'"
  },
  {
    number: 5,
    test_class: "TestParser",
    test_method: "test_parser_handles_incomplete_expressions_gracefully",
    file: "test/infrastructure/test_parser.rb:459",
    error_type: "ArgumentError",
    message: "wrong number of arguments (given 1, expected 2)", 
    stack_trace: "src/parser.rb:311:in `initialize'"
  },
  {
    number: 6,
    test_class: "TestParser",
    test_method: "test_parser_handles_incomplete_expressions",
    file: "test/infrastructure/test_parser.rb:419",
    error_type: "ArgumentError",
    message: "wrong number of arguments (given 1, expected 2)",
    stack_trace: "src/parser.rb:311:in `initialize'"
  },
  {
    number: 7,
    test_class: "TestParser",
    test_method: "test_parser_handles_incomplete_assignments",
    file: "test/infrastructure/test_parser.rb:479",
    error_type: "ArgumentError", 
    message: "wrong number of arguments (given 1, expected 2)",
    stack_trace: "src/parser.rb:311:in `initialize'"
  },
  {
    number: 8,
    test_class: "TestParser",
    test_method: "test_parser_handles_incomplete_array_access",
    file: "test/infrastructure/test_parser.rb:499",
    error_type: "ArgumentError",
    message: "wrong number of arguments (given 1, expected 2)",
    stack_trace: "src/parser.rb:311:in `initialize'"
  },
  {
    number: 9,
    test_class: "TestParser",
    test_method: "test_parser_handles_incomplete_function_calls",
    file: "test/infrastructure/test_parser.rb:519",
    error_type: "ArgumentError",
    message: "wrong number of arguments (given 1, expected 2)",
    stack_trace: "src/parser.rb:311:in `initialize'"
  },
  {
    number: 10,
    test_class: "TestTypeConstraintParser",
    test_method: "test_constraint_chaining_syntax",
    file: "test/infrastructure/test_type_constraint_parser.rb:199",
    error_type: "NoMethodError",
    message: "undefined method `[]' for nil:NilClass",
    stack_trace: "src/reasoning/type_constraint_parser.rb:45:in `parse'"
  },
  {
    number: 11,
    test_class: "TestUnificationEngine", 
    test_method: "test_unification_with_occurs_check",
    file: "test/infrastructure/test_unification_engine.rb:179",
    error_type: "NoMethodError",
    message: "undefined method `call' for true:TrueClass",
    stack_trace: "src/reasoning/unification_engine.rb:95:in `unify_terms'"
  },
  {
    number: 12,
    test_class: "TestUnificationEngine",
    test_method: "test_deep_unification_performance",
    file: "test/infrastructure/test_unification_engine.rb:199",
    error_type: "NoMethodError", 
    message: "undefined method `call' for true:TrueClass",
    stack_trace: "src/reasoning/unification_engine.rb:95:in `unify_terms'"
  },
  {
    number: 13,
    test_class: "TestUnificationEngine",
    test_method: "test_complex_unification_scenarios",
    file: "test/infrastructure/test_unification_engine.rb:159",
    error_type: "NoMethodError",
    message: "undefined method `call' for true:TrueClass", 
    stack_trace: "src/reasoning/unification_engine.rb:95:in `unify_terms'"
  },
  {
    number: 14,
    test_class: "TestUnificationEngine",
    test_method: "test_partial_unification_with_constraints",
    file: "test/infrastructure/test_unification_engine.rb:139",
    error_type: "NoMethodError",
    message: "undefined method `call' for true:TrueClass",
    stack_trace: "src/reasoning/unification_engine.rb:95:in `unify_terms'"
  },
  {
    number: 15,
    test_class: "TestUnificationEngine",
    test_method: "test_circular_reference_handling",
    file: "test/infrastructure/test_unification_engine.rb:219",
    error_type: "NoMethodError",
    message: "undefined method `call' for true:TrueClass",
    stack_trace: "src/reasoning/unification_engine.rb:95:in `unify_terms'"
  },
  {
    number: 16,
    test_class: "TestReasoningCoordinator",
    test_method: "test_pursue_goal_with_string_name",
    file: "test/infrastructure/test_reasoning_coordinator.rb:249",
    error_type: "LogicError",
    message: "Goal string_goal not defined",
    stack_trace: "src/reasoning/reasoning_coordinator.rb:153:in `pursue_goal'"
  },
  {
    number: 17,
    test_class: "TestObjectModelEdgeCases",
    test_method: "test_number_object_nan_handling",
    file: "test/ruby_implementation/test_object_model_edge_cases.rb:132",
    error_type: "FloatDomainError",
    message: "NaN",
    stack_trace: "src/object_model/number_object.rb:343:in `to_i'"
  },
  {
    number: 18,
    test_class: "TestObjectModelEdgeCases", 
    test_method: "test_number_object_infinity_handling",
    file: "test/ruby_implementation/test_object_model_edge_cases.rb:120",
    error_type: "FloatDomainError", 
    message: "Infinity",
    stack_trace: "src/object_model/number_object.rb:343:in `to_i'"
  },
  {
    number: 19,
    test_class: "TestReasoningIntegration",
    test_method: "test_large_fact_database_query_performance",
    file: "test/patlang_language/test_reasoning_integration.rb:474",
    error_type: "RuntimeError",
    message: "Error evaluating: \"query number(X) where X > 500 and X < 600\" Original: Undefined variable: where",
    stack_trace: "src/evaluator/scope_manager.rb:61:in `get_variable'"
  },
  {
    number: 20,
    test_class: "TestReasoningIntegration",
    test_method: "test_structural_type_constraint", 
    file: "test/patlang_language/test_reasoning_integration.rb:91",
    error_type: "RuntimeError",
    message: "Error evaluating: \"constrain person :: Object...\" Original: Undefined variable: name",
    stack_trace: "src/evaluator/scope_manager.rb:61:in `get_variable'"
  },
  {
    number: 21,
    test_class: "TestReasoningIntegration",
    test_method: "test_goal_driven_fact_discovery",
    file: "test/patlang_language/test_reasoning_integration.rb:305", 
    error_type: "RuntimeError",
    message: "Error evaluating: \"goal discover_relationships...\" Original: Undefined function: knows",
    stack_trace: "src/evaluator/function_evaluator.rb:45:in `visit_function_call_node'"
  },
  {
    number: 22,
    test_class: "TestReasoningIntegration",
    test_method: "test_rule_definition",
    file: "test/patlang_language/test_reasoning_integration.rb:214",
    error_type: "RuntimeError", 
    message: "Error evaluating: \"rule ancestor(X, Y)...\" Original: Undefined function: ancestor",
    stack_trace: "src/evaluator/function_evaluator.rb:45:in `visit_function_call_node'"
  }
]

puts "🔍 CATEGORIZING THE 22 ERRORS BY TYPE AND SOURCE:"
puts "=" * 60

# Group by error type
errors_by_type = error_entries.group_by { |e| e[:error_type] }

errors_by_type.each do |error_type, errors|
  puts "\n📋 #{error_type} (#{errors.count} errors):"
  errors.each do |error|
    puts "  #{error[:number]}. #{error[:test_class]}##{error[:test_method]}"
    puts "     📄 #{error[:file]}"
    puts "     💥 #{error[:message]}"
    puts "     📍 #{error[:stack_trace]}"
    puts
  end
end

puts "\n🎯 CATEGORIZING BY SOURCE FILE:"
puts "=" * 60

# Group by source file affected
errors_by_source = error_entries.group_by do |error|
  # Extract source file from stack trace
  if error[:stack_trace].include?('src/')
    error[:stack_trace].split(':').first.gsub('src/', '')
  else
    'unknown'
  end
end

errors_by_source.each do |source_file, errors|
  puts "\n🗂️  #{source_file} (#{errors.count} errors):"
  errors.each do |error|
    puts "  #{error[:number]}. #{error[:error_type]}: #{error[:test_method]}"
  end
end

puts "\n🔧 PRIORITY ANALYSIS:"
puts "=" * 60

infrastructure_errors = error_entries.select { |e| e[:file].include?('infrastructure/') }
language_errors = error_entries.select { |e| e[:file].include?('patlang_language/') }
ruby_impl_errors = error_entries.select { |e| e[:file].include?('ruby_implementation/') }

puts "\n📊 Error Distribution:"
puts "  🏗️  Infrastructure errors: #{infrastructure_errors.count}"
puts "  🗣️  Language errors: #{language_errors.count}" 
puts "  💎 Ruby implementation errors: #{ruby_impl_errors.count}"

puts "\n🎯 RECOMMENDED FIX ORDER:"
puts "=" * 60

puts "\n🥇 PRIORITY 1 - Core Infrastructure (Fix These First)"
puts "   These are blocking basic functionality and likely causing cascading failures"

lexer_errors = error_entries.select { |e| e[:stack_trace].include?('lexer.rb') }
parser_errors = error_entries.select { |e| e[:stack_trace].include?('parser.rb') }

puts "\n   A. Lexer Position Tracking (#{lexer_errors.count} errors) - src/lexer.rb:165"
lexer_errors.each { |e| puts "      #{e[:number]}. #{e[:test_method]}" }

puts "\n   B. Parser ArgumentError (#{parser_errors.count} errors) - src/parser.rb:311" 
parser_errors.each { |e| puts "      #{e[:number]}. #{e[:test_method]}" }

puts "\n🥈 PRIORITY 2 - Reasoning System Core (Fix These Second)"
puts "   These affect reasoning capabilities but depend on infrastructure"

unification_errors = error_entries.select { |e| e[:stack_trace].include?('unification_engine.rb') }
constraint_errors = error_entries.select { |e| e[:stack_trace].include?('type_constraint_parser.rb') }
coordinator_errors = error_entries.select { |e| e[:stack_trace].include?('reasoning_coordinator.rb') }

puts "\n   C. Unification Engine (#{unification_errors.count} errors) - src/reasoning/unification_engine.rb:95"
unification_errors.each { |e| puts "      #{e[:number]}. #{e[:test_method]}" }

puts "\n   D. Type Constraint Parser (#{constraint_errors.count} errors) - src/reasoning/type_constraint_parser.rb:45"
constraint_errors.each { |e| puts "      #{e[:number]}. #{e[:test_method]}" }

puts "\n   E. Reasoning Coordinator (#{coordinator_errors.count} errors) - src/reasoning/reasoning_coordinator.rb:153"
coordinator_errors.each { |e| puts "      #{e[:number]}. #{e[:test_method]}" }

puts "\n🥉 PRIORITY 3 - Language Features (Fix These Third)"
puts "   These are higher-level features that depend on the core systems"

evaluator_errors = error_entries.select { |e| e[:stack_trace].include?('evaluator') }
object_model_errors = error_entries.select { |e| e[:stack_trace].include?('object_model') }

puts "\n   F. Evaluator/Scope Manager (#{evaluator_errors.count} errors) - Variable resolution issues"
evaluator_errors.each { |e| puts "      #{e[:number]}. #{e[:test_method]}" }

puts "\n   G. Number Object Model (#{object_model_errors.count} errors) - src/object_model/number_object.rb:343"
object_model_errors.each { |e| puts "      #{e[:number]}. #{e[:test_method]}" }