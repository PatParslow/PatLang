# Comprehensive Test Suite Report

Generated: 2025-06-17T15:55:00+01:00
Execution Time: 46.51s

## Executive Summary

- **Total Test Files**: 61
- **Passed**: 26 (42.6%)
- **Failed**: 16
- **Errors**: 19

## Coverage Analysis

- **Line Coverage**: 0.0%
- **Branch Coverage**: N/A%
- **Files Analyzed**: 51
- **Low Coverage Files**: 51

## Results by Category

### Infrastructure
- Passed: 9
- Failed: 5
- Errors: 2
- Execution Time: 11.98s

### Ruby_implementation
- Passed: 3
- Failed: 3
- Errors: 9
- Execution Time: 9.63s

### Patlang_language
- Passed: 6
- Failed: 7
- Errors: 7
- Execution Time: 19.95s

### Integration
- Passed: 0
- Failed: 1
- Errors: 0
- Execution Time: 0.57s

### Helpers
- Passed: 0
- Failed: 0
- Errors: 1
- Execution Time: 0.47s

### Branch_coverage
- Passed: 2
- Failed: 0
- Errors: 0
- Execution Time: 0.92s

### Root_level
- Passed: 6
- Failed: 0
- Errors: 0
- Execution Time: 2.97s

## Recommendations

### 1. Line coverage is below 80%. Focus on adding tests for uncovered code. (high priority)
**Action**: Add tests for low-coverage files

### 2. 19 files have unknown error errors (high priority)
**Action**: Investigate and fix these errors

## Failed Tests

- **test_complex_logic_queries.rb** (infrastructure)
  - Status: failed
  - Execution Time: 0.554s
  - Error: ...

- **test_function_parser.rb** (infrastructure)
  - Status: failed
  - Execution Time: 0.965s
  - Error: ...

- **test_lexer_error_scenarios.rb** (infrastructure)
  - Status: failed
  - Execution Time: 1.198s
  - Error: ...

- **test_parser.rb** (infrastructure)
  - Status: failed
  - Execution Time: 1.58s
  - Error: ...

- **test_parser_edge_cases.rb** (infrastructure)
  - Status: failed
  - Execution Time: 1.717s
  - Error: #<Thread:0x0000026c52fda848 E:/patlang/src/emergency_timeout.rb:18 run> terminated with exception (report_on_exception is true):
C:/Users/p/.local/share/gem/ruby/3.3.0/gems/minitest-5.25.5/lib/minitest...

- **test_extended_string_methods.rb** (ruby_implementation)
  - Status: failed
  - Execution Time: 0.908s
  - Error: ...

- **test_goal_system.rb** (ruby_implementation)
  - Status: failed
  - Execution Time: 0.671s
  - Error: ...

- **test_string_literals.rb** (ruby_implementation)
  - Status: failed
  - Execution Time: 0.575s
  - Error: ...

- **test_control_flow_evaluator.rb** (patlang_language)
  - Status: failed
  - Execution Time: 2.484s
  - Error: ...

- **test_cross_paradigm_coordination.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.677s
  - Error: ...

- **test_form_validation.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.731s
  - Error: ...

- **test_function_validation.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.881s
  - Error: ...

- **test_goal_declaration_syntax.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.702s
  - Error: ...

- **test_integration.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.679s
  - Error: ...

- **test_performance_optimization.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.993s
  - Error: ...

- **test_unified_reasoning_integration.rb** (integration)
  - Status: failed
  - Execution Time: 0.565s
  - Error: ...

## Error Tests

- **test_reasoning_coordinator.rb** (infrastructure)
  - Error Type: unknown_error
  - Execution Time: 0.363s
  - Error: ...

- **test_type_constraint_parser.rb** (infrastructure)
  - Error Type: unknown_error
  - Execution Time: 0.393s
  - Error: ...

- **test_evaluator_edge_cases.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.546s
  - Error: ...

- **test_evaluator_stress.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 1.544s
  - Error: ...

- **test_function_evaluator.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.407s
  - Error: ...

- **test_object_model_comprehensive.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.513s
  - Error: Global event handler error: Global handler error
Event handler error for test: Handler error
...

- **test_object_model_edge_cases.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.385s
  - Error: ...

- **test_reasoning_evaluator_integration.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.468s
  - Error: ...

- **test_string_operations.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.756s
  - Error: ...

- **test_type_constraints.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.361s
  - Error: ...

- **test_type_constraints_clean.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.415s
  - Error: ...

- **test_enhanced_reasoning_parser.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.445s
  - Error: ...

- **test_evaluator.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.65s
  - Error: ...

- **test_evaluator_error_handling.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 6.176s
  - Error: ...

- **test_function_integration.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.47s
  - Error: ...

- **test_object_evaluation.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.468s
  - Error: ...

- **test_reasoning_integration.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.451s
  - Error: ...

- **test_type_constraint_syntax.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.398s
  - Error: ...

- **test_constants.rb** (helpers)
  - Error Type: unknown_error
  - Execution Time: 0.469s
  - Error: E:/patlang/test/helpers/test_constants.rb:6: warning: already initialized constant TestConstants::TestEvaluatorBranchCoverage
E:/patlang/test/helpers/test_constants.rb:6: warning: previous definition o...
