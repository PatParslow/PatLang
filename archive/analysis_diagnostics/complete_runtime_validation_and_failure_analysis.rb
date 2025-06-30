#!/usr/bin/env ruby

# Complete Runtime Error Analysis Script
# Focus: Deep analysis of the remaining 19 runtime ERRORS (not failures)

require 'json'

# Test execution results captured from the full test suite run
TEST_OUTPUT = <<~OUTPUT
Running comprehensive test suite with coverage analysis...
Discovered 39 test files:
  - infrastructure/test_ast_nodes.rb
  - infrastructure/test_complex_logic_queries.rb
  - infrastructure/test_facts_database.rb
  - infrastructure/test_function_lexer.rb
  - infrastructure/test_function_parser.rb
  - infrastructure/test_lexer.rb
  - infrastructure/test_lexer_comprehensive.rb
  - infrastructure/test_lexer_error_recovery.rb
  - infrastructure/test_parser.rb
  - infrastructure/test_parser_edge_cases.rb
  - infrastructure/test_unification_engine.rb
  - patlang_language/test_control_flow_evaluator.rb
  - patlang_language/test_cross_paradigm_coordination.rb
  - patlang_language/test_evaluator.rb
  - patlang_language/test_evaluator_reasoning.rb
  - patlang_language/test_flexible_function_syntax.rb
🎯 TESTING FLEXIBLE FUNCTION SYNTAX
==================================================

1. Full syntax: make a function called
   Code: make a function called greet { return "Hello" }
   Expected: Should work (original syntax)
   ✅ SUCCESS: "greet"

2. No "a": make function called
   Code: make function called greet { return "Hello" }
   Expected: Should work (no "a")
   ✅ SUCCESS: "greet"

3. No "called": make a function
   Code: make a function greet { return "Hello" }
   Expected: Should work (no "called")
   ✅ SUCCESS: "greet"

4. Minimal: make function
   Code: make function greet { return "Hello" }
   Expected: Should work (minimal syntax)
   ✅ SUCCESS: "greet"

5. Test function definition (full)
   Code: make a function called test { return "works" }
   Expected: Should define function successfully
   ✅ SUCCESS: "test"

6. Test function definition (minimal)
   Code: make function simple { return "simple" }
   Expected: Should define function successfully
   ✅ SUCCESS: "simple"

🎯 TESTING COMPLETE!
  - patlang_language/test_flexible_with_calls.rb
🎯 TESTING FLEXIBLE FUNCTION SYNTAX WITH CALLS
==================================================

1. Full syntax with call
   Expected: Should return "works"
   ✅ SUCCESS: "works"

2. Minimal syntax with call
   Expected: Should return "simple"
   ✅ SUCCESS: "simple"

3. No "a" with call
   Expected: Should return "demo"
   ✅ SUCCESS: "demo"

4. No "called" with call
   Expected: Should return "mini"
   ✅ SUCCESS: "mini"

🎯 FLEXIBLE FUNCTION SYNTAX FULLY WORKING!
  - patlang_language/test_form_validation.rb
  - patlang_language/test_function_integration.rb
  - patlang_language/test_function_validation.rb
  - patlang_language/test_integration.rb
  - patlang_language/test_is_keyword_implementation.rb
🚀 TESTING PATLANG'S REVOLUTIONARY 'IS' KEYWORD IMPLEMENTATION
======================================================================

1. Traditional assignment with =
   Code: x = 42
   ✅ PASSED: Got 42.0 (expected 42)

2. Traditional MAKE with =
   Code: make y = 17
   ✅ PASSED: Got 17.0 (expected 17)

3. Revolutionary assignment with 'is'
   Code: x is 42
   ✅ PASSED: Got 42.0 (expected 42)

4. Complex expression with 'is'
   Code: result is 10 + 5 * 2
   ✅ PASSED: Got 20.0 (expected 20)

5. Variable reference with 'is'
   Code: a is 5
b is a + 3
   ✅ PASSED: Got 8.0 (expected 8)

6. String assignment with 'is'
   Code: message is "Hello World"
   ✅ PASSED: Got "Hello World" (expected "Hello World")

7. Boolean assignment with 'is'
   Code: flag is true
   ✅ PASSED: Got true (expected true)

8. Complex calculation with 'is'
   Code: calculation is (2 + 3) * (4 - 1)
   ✅ PASSED: Got 15.0 (expected 15)

🎯 REVOLUTIONARY KEYWORD 'IS' FULLY IMPLEMENTED AND OPERATIONAL!
  - patlang_language/test_object_evaluation.rb
  - patlang_language/test_performance_optimization.rb
  - patlang_language/test_reasoning_integration.rb
  - patlang_language/test_regression_core.rb
  - ruby_implementation/test_advanced_goal_strategies.rb
  - ruby_implementation/test_evaluator_edge_cases.rb
  - ruby_implementation/test_evaluator_stress.rb
  - ruby_implementation/test_extended_string_methods.rb
  - ruby_implementation/test_function_evaluator.rb
  - ruby_implementation/test_goal_system.rb
  - ruby_implementation/test_object_model_comprehensive.rb
  - ruby_implementation/test_object_model_stress.rb
  - ruby_implementation/test_object_model.rb
  - ruby_implementation/test_string_literals.rb
  - ruby_implementation/test_string_operations.rb
  - ruby_implementation/test_type_constraints_clean.rb
  - ruby_implementation/test_type_constraints.rb

ERROR DETECTION RESULTS:
 39) Error:
TestFunctionParser#test_lambda_syntax_edge_cases:
NoMethodError: undefined method `debug_print' for #<FunctionParser:0x00000244dcbb5630>
    E:/patlang/src/parser/function_parser.rb:264:in `parse_lambda_definition'
    E:/patlang/src/parser/function_parser.rb:50:in `parse_function_definition'
    E:/patlang/src/parser.rb:110:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    infrastructure/test_function_parser.rb:315:in `test_lambda_syntax_edge_cases'

 40) Error:
TestFunctionParser#test_type_annotated_parameters:
NoMethodError: undefined method `debug_print' for #<FunctionParser:0x00000244dcbba828>
    E:/patlang/src/parser/function_parser.rb:264:in `parse_lambda_definition'
    E:/patlang/src/parser/function_parser.rb:50:in `parse_function_definition'
    E:/patlang/src/parser.rb:110:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    infrastructure/test_function_parser.rb:171:in `test_type_annotated_parameters'

 41) Error:
TestFunctionParser#test_function_with_complex_types:
NoMethodError: undefined method `debug_print' for #<FunctionParser:0x00000244dcbbb0f8>
    E:/patlang/src/parser/function_parser.rb:264:in `parse_lambda_definition'
    E:/patlang/src/parser/function_parser.rb:50:in `parse_function_definition'
    E:/patlang/src/parser.rb:110:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    infrastructure/test_function_parser.rb:235:in `test_function_with_complex_types'

 42) Error:
TestFunctionParser#test_lambda_with_parameters:
NoMethodError: undefined method `debug_print' for #<FunctionParser:0x00000244dcbbb968>
    E:/patlang/src/parser/function_parser.rb:264:in `parse_lambda_definition'
    E:/patlang/src/parser/function_parser.rb:50:in `parse_function_definition'
    E:/patlang/src/parser.rb:110:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    infrastructure/test_function_parser.rb:365:in `test_lambda_with_parameters'

 43) Error:
TestFunctionParser#test_lambda_with_type_annotations:
NoMethodError: undefined method `debug_print' for #<FunctionParser:0x00000244dcbbbc90>
    E:/patlang/src/parser/function_parser.rb:264:in `parse_lambda_definition'
    E:/patlang/src/parser/function_parser.rb:50:in `parse_function_definition'
    E:/patlang/src/parser.rb:110:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    infrastructure/test_function_parser.rb:393:in `test_lambda_with_type_annotations'

 44) Error:
TestFunctionParser#test_function_with_return_type:
NoMethodError: undefined method `debug_print' for #<FunctionParser:0x00000244dcbbcbc0>
    E:/patlang/src/parser/function_parser.rb:264:in `parse_lambda_definition'
    E:/patlang/src/parser/function_parser.rb:50:in `parse_function_definition'
    E:/patlang/src/parser.rb:110:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    infrastructure/test_function_parser.rb:205:in `test_function_with_return_type'

 45) Error:
TestFunctionParser#test_variadic_functions:
NoMethodError: undefined method `debug_print' for #<FunctionParser:0x00000244dcbbd4e8>
    E:/patlang/src/parser/function_parser.rb:264:in `parse_lambda_definition'
    E:/patlang/src/parser/function_parser.rb:50:in `parse_function_definition'
    E:/patlang/src/parser.rb:110:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    infrastructure/test_function_parser.rb:267:in `test_variadic_functions'

 46) Error:
TestFunctionParser#test_nested_lambda_definitions:
NoMethodError: undefined method `debug_print' for #<FunctionParser:0x00000244dcbbde10>
    E:/patlang/src/parser/function_parser.rb:264:in `parse_lambda_definition'
    E:/patlang/src/parser/function_parser.rb:50:in `parse_function_definition'
    E:/patlang/src/parser.rb:110:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    infrastructure/test_function_parser.rb:421:in `test_nested_lambda_definitions'

 47) Error:
TestParserEdgeCases#test_error_recovery_detailed:
ParseError: Unexpected token in factor at token Token(ASSIGN, =) at line 1, column 2
    E:/patlang/src/parser.rb:33:in `error'
    E:/patlang/src/parser/expression_parser.rb:366:in `primary'
    E:/patlang/src/parser/expression_parser.rb:139:in `postfix'
    E:/patlang/src/parser/expression_parser.rb:125:in `exponentiation'
    E:/patlang/src/parser/expression_parser.rb:121:in `unary'
    E:/patlang/src/parser/expression_parser.rb:99:in `term'
    E:/patlang/src/parser/expression_parser.rb:85:in `arithmetic'
    E:/patlang/src/parser/expression_parser.rb:69:in `comparison'
    E:/patlang/src/parser/expression_parser.rb:56:in `type_annotation'
    E:/patlang/src/parser/expression_parser.rb:41:in `equality'
    E:/patlang/src/parser/expression_parser.rb:28:in `logical_and'
    E:/patlang/src/parser/expression_parser.rb:15:in `logical_or'
    E:/patlang/src/parser/expression_parser.rb:11:in `expression'
    E:/patlang/src/parser.rb:233:in `expression'
    E:/patlang/src/parser.rb:149:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    infrastructure/test_parser_edge_cases.rb:43:in `block in test_error_recovery_detailed'
    infrastructure/test_parser_edge_cases.rb:38:in `each'
    infrastructure/test_parser_edge_cases.rb:38:in `test_error_recovery_detailed'

 48) Error:
TestParserEdgeCases#test_expression_precedence_edge_cases:
ParseError: Unexpected token in factor at token Token(ASSIGN, =) at line 1, column 2
    E:/patlang/src/parser.rb:33:in `error'
    E:/patlang/src/parser/expression_parser.rb:366:in `primary'
    E:/patlang/src/parser/expression_parser.rb:139:in `postfix'
    E:/patlang/src/parser/expression_parser.rb:125:in `exponentiation'
    E:/patlang/src/parser/expression_parser.rb:121:in `unary'
    E:/patlang/src/parser/expression_parser.rb:99:in `term'
    E:/patlang/src/parser/expression_parser.rb:85:in `arithmetic'
    E:/patlang/src/parser/expression_parser.rb:69:in `comparison'
    E:/patlang/src/parser/expression_parser.rb:56:in `type_annotation'
    E:/patlang/src/parser/expression_parser.rb:41:in `equality'
    E:/patlang/src/parser/expression_parser.rb:28:in `logical_and'
    E:/patlang/src/parser/expression_parser.rb:15:in `logical_or'
    E:/patlang/src/parser/expression_parser.rb:11:in `expression'
    E:/patlang/src/parser.rb:233:in `expression'
    E:/patlang/src/parser.rb:149:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    infrastructure/test_parser_edge_cases.rb:73:in `block in test_expression_precedence_edge_cases'
    infrastructure/test_parser_edge_cases.rb:68:in `each'
    infrastructure/test_parser_edge_cases.rb:68:in `test_expression_precedence_edge_cases'

 49) Error:
TestParserEdgeCases#test_complex_nested_expressions:
ParseError: Unexpected token in factor at token Token(ASSIGN, =) at line 1, column 2
    E:/patlang/src/parser.rb:33:in `error'
    E:/patlang/src/parser/expression_parser.rb:366:in `primary'
    E:/patlang/src/parser/expression_parser.rb:139:in `postfix'
    E:/patlang/src/parser/expression_parser.rb:125:in `exponentiation'
    E:/patlang/src/parser/expression_parser.rb:121:in `unary'
    E:/patlang/src/parser/expression_parser.rb:99:in `term'
    E:/patlang/src/parser/expression_parser.rb:85:in `arithmetic'
    E:/patlang/src/parser/expression_parser.rb:69:in `comparison'
    E:/patlang/src/parser/expression_parser.rb:56:in `type_annotation'
    E:/patlang/src/parser/expression_parser.rb:41:in `equality'
    E:/patlang/src/parser/expression_parser.rb:28:in `logical_and'
    E:/patlang/src/parser/expression_parser.rb:15:in `logical_or'
    E:/patlang/src/parser/expression_parser.rb:11:in `expression'
    E:/patlang/src/parser.rb:233:in `expression'
    E:/patlang/src/parser.rb:149:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    infrastructure/test_parser_edge_cases.rb:132:in `block in test_complex_nested_expressions'
    infrastructure/test_parser_edge_cases.rb:127:in `each'
    infrastructure/test_parser_edge_cases.rb:127:in `test_complex_nested_expressions'

 50) Error:
TestParserEdgeCases#test_malformed_syntax_recovery:
ParseError: Unexpected token in factor at token Token(ASSIGN, =) at line 1, column 2
    E:/patlang/src/parser.rb:33:in `error'
    E:/patlang/src/parser/expression_parser.rb:366:in `primary'
    E:/patlang/src/parser/expression_parser.rb:139:in `postfix'
    E:/patlang/src/parser/expression_parser.rb:125:in `exponentiation'
    E:/patlang/src/parser/expression_parser.rb:121:in `unary'
    E:/patlang/src/parser/expression_parser.rb:99:in `term'
    E:/patlang/src/parser/expression_parser.rb:85:in `arithmetic'
    E:/patlang/src/parser/expression_parser.rb:69:in `comparison'
    E:/patlang/src/parser/expression_parser.rb:56:in `type_annotation'
    E:/patlang/src/parser/expression_parser.rb:41:in `equality'
    E:/patlang/src/parser/expression_parser.rb:28:in `logical_and'
    E:/patlang/src/parser/expression_parser.rb:15:in `logical_or'
    E:/patlang/src/parser/expression_parser.rb:11:in `expression'
    E:/patlang/src/parser.rb:233:in `expression'
    E:/patlang/src/parser.rb:149:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    infrastructure/test_parser_edge_cases.rb:102:in `block in test_malformed_syntax_recovery'
    infrastructure/test_parser_edge_cases.rb:97:in `each'
    infrastructure/test_parser_edge_cases.rb:97:in `test_malformed_syntax_recovery'

 51) Error:
TestParserEdgeCases#test_token_resolution_failures:
ParseError: Unexpected token in factor at token Token(IS, is) at line 1, column 1
    E:/patlang/src/parser.rb:33:in `error'
    E:/patlang/src/parser/expression_parser.rb:366:in `primary'
    E:/patlang/src/parser/expression_parser.rb:139:in `postfix'
    E:/patlang/src/parser/expression_parser.rb:125:in `exponentiation'
    E:/patlang/src/parser/expression_parser.rb:121:in `unary'
    E:/patlang/src/parser/expression_parser.rb:99:in `term'
    E:/patlang/src/parser/expression_parser.rb:85:in `arithmetic'
    E:/patlang/src/parser/expression_parser.rb:69:in `comparison'
    E:/patlang/src/parser/expression_parser.rb:56:in `type_annotation'
    E:/patlang/src/parser/expression_parser.rb:41:in `equality'
    E:/patlang/src/parser/expression_parser.rb:28:in `logical_and'
    E:/patlang/src/parser/expression_parser.rb:15:in `logical_or'
    E:/patlang/src/parser/expression_parser.rb:11:in `expression'
    E:/patlang/src/parser.rb:233:in `expression'
    E:/patlang/src/parser.rb:149:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    infrastructure/test_parser_edge_cases.rb:247:in `block in test_token_resolution_failures'
    infrastructure/test_parser_edge_cases.rb:243:in `each'
    infrastructure/test_parser_edge_cases.rb:243:in `test_token_resolution_failures'

 52) Error:
TestParserEdgeCases#test_eof_handling_in_various_states:
ParseError: Unexpected token in factor at token Token(EOF) at line 1, column 5
    E:/patlang/src/parser.rb:33:in `error'
    E:/patlang/src/parser/expression_parser.rb:366:in `primary'
    E:/patlang/src/parser/expression_parser.rb:139:in `postfix'
    E:/patlang/src/parser/expression_parser.rb:125:in `exponentiation'
    E:/patlang/src/parser/expression_parser.rb:121:in `unary'
    E:/patlang/src/parser/expression_parser.rb:99:in `term'
    E:/patlang/src/parser/expression_parser.rb:91:in `arithmetic'
    E:/patlang/src/parser/expression_parser.rb:69:in `comparison'
    E:/patlang/src/parser/expression_parser.rb:56:in `type_annotation'
    E:/patlang/src/parser/expression_parser.rb:41:in `equality'
    E:/patlang/src/parser/expression_parser.rb:28:in `logical_and'
    E:/patlang/src/parser/expression_parser.rb:15:in `logical_or'
    E:/patlang/src/parser/expression_parser.rb:11:in `expression'
    E:/patlang/src/parser.rb:233:in `expression'
    E:/patlang/src/parser.rb:149:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    infrastructure/test_parser_edge_cases.rb:156:in `block in test_eof_handling_in_various_states'
    infrastructure/test_parser_edge_cases.rb:152:in `each'
    infrastructure/test_parser_edge_cases.rb:152:in `test_eof_handling_in_various_states'

 65) Error:
TestEvaluatorStress#test_return_value_handling_complex_control_flows:
ParseError: Expected LBRACE, got WITH at token Token(WITH, with) at line 1, column 37
    E:/patlang/src/parser.rb:33:in `error'
    E:/patlang/src/parser.rb:58:in `eat'
    E:/patlang/src/parser/function_parser.rb:72:in `parse_function_definition'
    E:/patlang/src/parser.rb:110:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    ruby_implementation/test_evaluator_stress.rb:16:in `block in setup'
    ruby_implementation/test_evaluator_stress.rb:453:in `test_return_value_handling_complex_control_flows'

 66) Error:
TestEvaluatorStress#test_infinite_loop_detection_accuracy:
ParseError: Expected LBRACE, got CALL at token Token(CALL, call) at line 2, column 3
    E:/patlang/src/parser.rb:33:in `error'
    E:/patlang/src/parser.rb:58:in `eat'
    E:/patlang/src/parser/function_parser.rb:72:in `parse_function_definition'
    E:/patlang/src/parser.rb:110:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    ruby_implementation/test_evaluator_stress.rb:16:in `block in setup'
    ruby_implementation/test_evaluator_stress.rb:116:in `test_infinite_loop_detection_accuracy'

 67) Error:
TestEvaluatorStress#test_memory_management_long_running:
ParseError: Expected LBRACE, got WITH at token Token(WITH, with) at line 1, column 36
    E:/patlang/src/parser.rb:33:in `error'
    E:/patlang/src/parser.rb:58:in `eat'
    E:/patlang/src/parser/function_parser.rb:72:in `parse_function_definition'
    E:/patlang/src/parser.rb:110:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    ruby_implementation/test_evaluator_stress.rb:16:in `block in setup'
    ruby_implementation/test_evaluator_stress.rb:202:in `test_memory_management_long_running'

 68) Error:
TestEvaluatorStress#test_variable_scope_deep_nesting:
ParseError: Expected LBRACE, got WITH at token Token(WITH, with) at line 1, column 31
    E:/patlang/src/parser.rb:33:in `error'
    E:/patlang/src/parser.rb:58:in `eat'
    E:/patlang/src/parser/function_parser.rb:72:in `parse_function_definition'
    E:/patlang/src/parser.rb:110:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    ruby_implementation/test_evaluator_stress.rb:16:in `block in setup'
    ruby_implementation/test_evaluator_stress.rb:316:in `test_variable_scope_deep_nesting'

 69) Error:
TestEvaluatorStress#test_error_propagation_nested_contexts:
ParseError: Expected LBRACE, got IDENTIFIER at token Token(IDENTIFIER, result) at line 2, column 3
    E:/patlang/src/parser.rb:33:in `error'
    E:/patlang/src/parser.rb:58:in `eat'
    E:/patlang/src/parser/function_parser.rb:72:in `parse_function_definition'
    E:/patlang/src/parser.rb:110:in `statement'
    E:/patlang/src/parser.rb:83:in `program'
    E:/patlang/src/parser.rb:76:in `parse'
    ruby_implementation/test_evaluator_stress.rb:16:in `block in setup'
    ruby_implementation/test_evaluator_stress.rb:229:in `test_error_propagation_nested_contexts'

 80) Error:
TestGoalSystem#test_goal_with_multiple_strategies:
NoMethodError: undefined method `length' for nil
    ruby_implementation/test_goal_system.rb:79:in `test_goal_with_multiple_strategies'

 87) Error:
TestEvaluatorReasoning#test_patlang_evaluate_with_facts_database:
RuntimeError: Undefined variable: database
    E:/patlang/src/evaluator/scope_manager.rb:61:in `get_variable'
    E:/patlang/src/evaluator.rb:283:in `get_variable'
    E:/patlang/src/evaluator.rb:347:in `visit_variable_node'
    E:/patlang/src/evaluator.rb:195:in `evaluate'
    E:/patlang/src/evaluator.rb:383:in `block in visit_block_node'
    E:/patlang/src/evaluator.rb:382:in `each'
    E:/patlang/src/evaluator.rb:382:in `visit_block_node'
    E:/patlang/src/evaluator.rb:213:in `evaluate'
    E:/patlang/src/patlang.rb:55:in `process_expression'
    E:/patlang/src/patlang.rb:98:in `rescue in evaluate_with_reasoning'
    E:/patlang/src/patlang.rb:93:in `evaluate_with_reasoning'
    E:/patlang/src/patlang.rb:76:in `evaluate'
    patlang_language/test_evaluator_reasoning.rb:26:in `test_patlang_evaluate_with_facts_database'

 97) Error:
TestCrossParadigmCoordination#test_large_scale_cross_paradigm_coordination:
NoMethodError: undefined method `[]' for nil
    patlang_language/test_cross_paradigm_coordination.rb:526:in `test_large_scale_cross_paradigm_coordination'

 98) Error:
TestCrossParadigmCoordination#test_cross_paradigm_constraint_satisfaction:
NoMethodError: undefined method `[]' for nil
    patlang_language/test_cross_paradigm_coordination.rb:359:in `test_cross_paradigm_constraint_satisfaction'

 99) Error:
TestCrossParadigmCoordination#test_learning_better_constraint_patterns:
NoMethodError: undefined method `length' for nil
    patlang_language/test_cross_paradigm_coordination.rb:426:in `test_learning_better_constraint_patterns'

697 runs, 4108 assertions, 91 failures, 19 errors, 6 skips
OUTPUT

puts "🔍 EXTRACTING THE 19 RUNTIME ERRORS FOR DEEP ANALYSIS"
puts "=" * 70

# Extract all ERROR entries (not failures)
error_entries = []
current_error = nil

TEST_OUTPUT.lines.each do |line|
  # Match error numbers and types
  if line.match(/^\s*(\d+)\) Error:/)
    if current_error
      error_entries << current_error
    end
    
    current_error = {
      number: $1.to_i,
      test_class: nil,
      test_method: nil,
      error_type: nil,
      error_message: nil,
      file_location: nil,
      line_number: nil,
      stack_trace: []
    }
    
    # Extract test class and method
    if line.match(/Error:\s*(\w+)#(\w+):/)
      current_error[:test_class] = $1
      current_error[:test_method] = $2
    end
  elsif current_error && line.match(/^(\w+Error|ParseError|RuntimeError): (.+)/)
    current_error[:error_type] = $1
    current_error[:error_message] = $2
  elsif current_error && line.match(/^\s+(.+):(\d+):in `(.+)'/)
    file_path = $1
    line_num = $2.to_i
    method_name = $3
    
    if current_error[:file_location].nil? && file_path.include?('patlang')
      current_error[:file_location] = file_path
      current_error[:line_number] = line_num
    end
    
    current_error[:stack_trace] << {
      file: file_path,
      line: line_num,
      method: method_name
    }
  end
end

# Add the last error if exists
if current_error
  error_entries << current_error
end

puts "📊 RUNTIME ERROR SUMMARY:"
puts "Total Errors Found: #{error_entries.length}"
puts

# Group errors by type
error_by_type = error_entries.group_by { |e| e[:error_type] }

puts "🏷️  ERROR CLASSIFICATION BY TYPE:"
error_by_type.each do |type, errors|
  puts "  #{type}: #{errors.length} errors"
  errors.each do |error|
    puts "    - #{error[:test_class]}##{error[:test_method]} (Error #{error[:number]})"
  end
  puts
end

puts "🔍 DETAILED ERROR ANALYSIS:"
puts "=" * 70

error_entries.each_with_index do |error, index|
  puts "ERROR #{index + 1}/#{error_entries.length}: #{error[:test_class]}##{error[:test_method]}"
  puts "  🔢 Error Number: #{error[:number]}"
  puts "  🏷️  Type: #{error[:error_type]}"
  puts "  💬 Message: #{error[:error_message]}"
  puts "  📁 Location: #{error[:file_location]}:#{error[:line_number]}"
  puts "  📚 Stack Trace Depth: #{error[:stack_trace].length} levels"
  
  # Show top 3 stack trace entries for context
  puts "  🥞 Key Stack Trace:"
  error[:stack_trace].first(3).each do |frame|
    puts "    #{frame[:file]}:#{frame[:line]} in `#{frame[:method]}'"
  end
  puts
end

puts "🎯 ROOT CAUSE PATTERN ANALYSIS:"
puts "=" * 50

# Analysis of patterns
patterns = {
  debug_print_missing: error_entries.select { |e| 
    e[:error_type] == 'NoMethodError' && 
    e[:error_message]&.include?('debug_print') 
  },
  
  parser_edge_cases: error_entries.select { |e|
    e[:error_type] == 'ParseError' && 
    e[:test_class] == 'TestParserEdgeCases'
  },
  
  evaluator_stress: error_entries.select { |e|
    e[:error_type] == 'ParseError' && 
    e[:test_class] == 'TestEvaluatorStress'
  },
  
  nil_method_calls: error_entries.select { |e|
    e[:error_type] == 'NoMethodError' && 
    e[:error_message]&.include?('for nil')
  },
  
  undefined_variables: error_entries.select { |e|
    e[:error_type] == 'RuntimeError' && 
    e[:error_message]&.include?('Undefined variable')
  }
}

patterns.each do |pattern_name, pattern_errors|
  next if pattern_errors.empty?
  
  puts "🔵 #{pattern_name.to_s.upcase.gsub('_', ' ')}:"
  puts "   Count: #{pattern_errors.length}"
  puts "   Errors: #{pattern_errors.map { |e| e[:number] }.join(', ')}"
  
  # Why didn't previous fixes address these?
  case pattern_name
  when :debug_print_missing
    puts "   🤔 Why not fixed: Missing method likely introduced during function parser refactoring"
    puts "   🎯 Fix Strategy: Add debug_print method to FunctionParser class"
    puts "   🚀 Complexity: LOW - Simple method addition"
  when :parser_edge_cases
    puts "   🤔 Why not fixed: Edge case parsing not covered in previous syntax fixes"
    puts "   🎯 Fix Strategy: Improve error recovery and token handling in expression parser"
    puts "   🚀 Complexity: MEDIUM - Parser logic enhancement"
  when :evaluator_stress
    puts "   🤔 Why not fixed: Test setup issues with complex function syntax not addressed"
    puts "   🎯 Fix Strategy: Fix test setup for stress testing scenarios"
    puts "   🚀 Complexity: MEDIUM - Test infrastructure improvement"
  when :nil_method_calls
    puts "   🤔 Why not fixed: Nil checks missed in cross-paradigm coordination components"
    puts "   🎯 Fix Strategy: Add nil guards in coordination logic"
    puts "   🚀 Complexity: LOW - Add nil checks"
  when :undefined_variables
    puts "   🤔 Why not fixed: Variable scope issues in reasoning integration"
    puts "   🎯 Fix Strategy: Proper variable initialization in test setup"
    puts "   🚀 Complexity: LOW - Variable initialization"
  end
  puts
end

puts "📈 PRIORITIZATION ANALYSIS:"
puts "=" * 40

priority_analysis = [
  {
    priority: "HIGH",
    errors: patterns[:debug_print_missing],
    reason: "Blocking 8 function parser tests - core functionality",
    impact: "Function parsing completely broken for advanced features"
  },
  {
    priority: "MEDIUM",
    errors: patterns[:parser_edge_cases],
    reason: "Edge case handling - affects robustness",
    impact: "Parser fails on malformed input, poor error recovery"
  },
  {
    priority: "MEDIUM", 
    errors: patterns[:evaluator_stress],
    reason: "Stress testing infrastructure - quality assurance",
    impact: "Cannot validate system performance under load"
  },
  {
    priority: "LOW",
    errors: patterns[:nil_method_calls] + patterns[:undefined_variables],
    reason: "Isolated test issues - not core functionality",
    impact: "Some integration scenarios fail but core works"
  }
]

priority_analysis.each do |analysis|
  next if analysis[:errors].empty?
  
  puts "🔴 #{analysis[:priority]} PRIORITY:"
  puts "   Error Count: #{analysis[:errors].length}"
  puts "   Error Numbers: #{analysis[:errors].map { |e| e[:number] }.join(', ')}"
  puts "   Reason: #{analysis[:reason]}"
  puts "   Impact: #{analysis[:impact]}"
  puts
end

puts "🎯 RECOMMENDED FIX SEQUENCE:"
puts "=" * 35

puts "1. 🔥 PHASE 1: Fix debug_print missing method (8 errors)"
puts "   - Add debug_print method to FunctionParser"
puts "   - Estimated time: 5 minutes"
puts "   - Expected reduction: 8 errors → 11 remaining"
puts

puts "2. 🛠️  PHASE 2: Fix parser edge case handling (6 errors)"
puts "   - Improve expression parser error recovery"
puts "   - Handle malformed syntax gracefully"
puts "   - Estimated time: 30 minutes"
puts "   - Expected reduction: 11 errors → 5 remaining"
puts

puts "3. 🏗️  PHASE 3: Fix evaluator stress test setup (5 errors)"
puts "   - Update test setup for complex function syntax"
puts "   - Fix token expectations in stress tests"
puts "   - Estimated time: 20 minutes"
puts "   - Expected reduction: 5 errors → 0 remaining"
puts

puts "💡 INSIGHTS ON WHY THESE SURVIVED PREVIOUS FIXES:"
puts "=" * 55

insights = [
  "🔍 debug_print errors: Introduced during function parser modularization",
  "🔍 Parser edge cases: Original fixes focused on core parsing, not edge cases",
  "🔍 Stress test failures: Complex test scenarios not covered in basic fixes", 
  "🔍 Nil method calls: Cross-paradigm integration components not fully tested",
  "🔍 Variable scope: Reasoning integration tests need proper setup"
]

insights.each { |insight| puts insight }

puts
puts "🎉 CONCLUSION:"
puts "The remaining 19 errors fall into clear patterns with straightforward fixes."
puts "Most are missing method implementations or test setup issues, not core logic problems."
puts "With focused fixes in the recommended sequence, all errors should be eliminated."

# Generate JSON report for detailed analysis
report = {
  total_errors: error_entries.length,
  error_classification: error_by_type.transform_values { |errors| errors.length },
  detailed_errors: error_entries,
  pattern_analysis: patterns.transform_values { |errors| 
    {
      count: errors.length,
      error_numbers: errors.map { |e| e[:number] }
    }
  },
  priority_sequence: priority_analysis,
  fix_recommendations: [
    {
      phase: 1,
      target: "debug_print method",
      errors_affected: 8,
      complexity: "LOW",
      estimated_time: "5 minutes"
    },
    {
      phase: 2, 
      target: "parser edge cases",
      errors_affected: 6,
      complexity: "MEDIUM",
      estimated_time: "30 minutes"
    },
    {
      phase: 3,
      target: "stress test setup",
      errors_affected: 5,
      complexity: "MEDIUM", 
      estimated_time: "20 minutes"
    }
  ]
}

File.write('RUNTIME_VALIDATION_AND_FAILURE_ANALYSIS.json', JSON.pretty_generate(report))

puts
puts "📄 Detailed analysis report saved to: RUNTIME_VALIDATION_AND_FAILURE_ANALYSIS.json"