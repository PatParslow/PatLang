# Comprehensive Test Suite Report

Generated: 2025-06-16T23:52:07+01:00
Execution Time: 32.6s

## Executive Summary

- **Total Test Files**: 58
- **Passed**: 28 (48.3%)
- **Failed**: 11
- **Errors**: 19

## Coverage Analysis

- **Line Coverage**: 0.0%
- **Branch Coverage**: N/A%
- **Files Analyzed**: 51
- **Low Coverage Files**: 51

## Results by Category

### Infrastructure
- Passed: 11
- Failed: 3
- Errors: 2
- Execution Time: 9.19s

### Ruby_implementation
- Passed: 4
- Failed: 2
- Errors: 9
- Execution Time: 6.63s

### Patlang_language
- Passed: 8
- Failed: 5
- Errors: 7
- Execution Time: 14.29s

### Integration
- Passed: 0
- Failed: 1
- Errors: 0
- Execution Time: 0.43s

### Helpers
- Passed: 0
- Failed: 0
- Errors: 1
- Execution Time: 0.33s

### Branch_coverage
- Passed: 2
- Failed: 0
- Errors: 0
- Execution Time: 0.67s

### Root_level
- Passed: 3
- Failed: 0
- Errors: 0
- Execution Time: 1.05s

## Recommendations

### 1. Line coverage is below 80%. Focus on adding tests for uncovered code. (high priority)
**Action**: Add tests for low-coverage files

### 2. 19 files have unknown error errors (high priority)
**Action**: Investigate and fix these errors

## Failed Tests

- **test_complex_logic_queries.rb** (infrastructure)
  - Status: failed
  - Execution Time: 0.465s
  - Error: ...

- **test_lexer_error_scenarios.rb** (infrastructure)
  - Status: failed
  - Execution Time: 1.016s
  - Error: ...

- **test_parser_edge_cases.rb** (infrastructure)
  - Status: failed
  - Execution Time: 1.637s
  - Error: #<Thread:0x000001349254d248 E:/patlang/src/emergency_timeout.rb:18 run> terminated with exception (report_on_exception is true):
C:/Users/p/.local/share/gem/ruby/3.3.0/gems/minitest-5.25.5/lib/minitest...

- **test_goal_system.rb** (ruby_implementation)
  - Status: failed
  - Execution Time: 0.519s
  - Error: ...

- **test_string_literals.rb** (ruby_implementation)
  - Status: failed
  - Execution Time: 0.472s
  - Error: ...

- **test_cross_paradigm_coordination.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.527s
  - Error: ...

- **test_form_validation.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.575s
  - Error: ...

- **test_goal_declaration_syntax.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.538s
  - Error: ...

- **test_integration.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.522s
  - Error: ...

- **test_performance_optimization.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.758s
  - Error: ...

- **test_unified_reasoning_integration.rb** (integration)
  - Status: failed
  - Execution Time: 0.432s
  - Error: ...

## Error Tests

- **test_reasoning_coordinator.rb** (infrastructure)
  - Error Type: unknown_error
  - Execution Time: 0.295s
  - Error: ...

- **test_type_constraint_parser.rb** (infrastructure)
  - Error Type: unknown_error
  - Execution Time: 0.34s
  - Error: ...

- **test_evaluator_edge_cases.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.346s
  - Error: ...

- **test_evaluator_stress.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.762s
  - Error: ...

- **test_function_evaluator.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.361s
  - Error: ...

- **test_object_model_comprehensive.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.361s
  - Error: Global event handler error: Global handler error
Event handler error for test: Handler error
...

- **test_object_model_edge_cases.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.414s
  - Error: ...

- **test_reasoning_evaluator_integration.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.315s
  - Error: ...

- **test_string_operations.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.325s
  - Error: ...

- **test_type_constraints.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.303s
  - Error: ...

- **test_type_constraints_clean.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.294s
  - Error: ...

- **test_enhanced_reasoning_parser.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.415s
  - Error: ...

- **test_evaluator.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.353s
  - Error: ...

- **test_evaluator_error_handling.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 5.497s
  - Error: ...

- **test_function_integration.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.315s
  - Error: ...

- **test_object_evaluation.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.356s
  - Error: ...

- **test_reasoning_integration.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.34s
  - Error: ...

- **test_type_constraint_syntax.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.298s
  - Error: ...

- **test_constants.rb** (helpers)
  - Error Type: unknown_error
  - Execution Time: 0.325s
  - Error: E:/patlang/test/helpers/test_constants.rb:6: warning: already initialized constant TestConstants::TestEvaluatorBranchCoverage
E:/patlang/test/helpers/test_constants.rb:6: warning: previous definition o...
