# Comprehensive Test Suite Report

Generated: 2025-06-16T05:01:06+01:00
Execution Time: 32.5s

## Executive Summary

- **Total Test Files**: 57
- **Passed**: 27 (47.4%)
- **Failed**: 12
- **Errors**: 18

## Coverage Analysis

- **Line Coverage**: 2.43%
- **Branch Coverage**: N/A%
- **Files Analyzed**: 48
- **Low Coverage Files**: 48

## Results by Category

### Infrastructure
- Passed: 10
- Failed: 4
- Errors: 2
- Execution Time: 10.52s

### Ruby_implementation
- Passed: 4
- Failed: 2
- Errors: 9
- Execution Time: 7.99s

### Patlang_language
- Passed: 8
- Failed: 5
- Errors: 6
- Execution Time: 10.79s

### Integration
- Passed: 0
- Failed: 1
- Errors: 0
- Execution Time: 0.55s

### Helpers
- Passed: 0
- Failed: 0
- Errors: 1
- Execution Time: 0.42s

### Branch_coverage
- Passed: 2
- Failed: 0
- Errors: 0
- Execution Time: 0.88s

### Root_level
- Passed: 3
- Failed: 0
- Errors: 0
- Execution Time: 1.33s

## Recommendations

### 1. Line coverage is below 80%. Focus on adding tests for uncovered code. (high priority)
**Action**: Add tests for low-coverage files

### 2. 18 files have unknown error errors (high priority)
**Action**: Investigate and fix these errors

## Failed Tests

- **test_complex_logic_queries.rb** (infrastructure)
  - Status: failed
  - Execution Time: 0.501s
  - Error: ...

- **test_goal_resolution_engine.rb** (infrastructure)
  - Status: failed
  - Execution Time: 0.428s
  - Error: ...

- **test_lexer_error_scenarios.rb** (infrastructure)
  - Status: failed
  - Execution Time: 1.201s
  - Error: ...

- **test_parser_edge_cases.rb** (infrastructure)
  - Status: failed
  - Execution Time: 1.714s
  - Error: #<Thread:0x000001ff8a513f48 E:/patlang/src/emergency_timeout.rb:18 run> terminated with exception (report_on_exception is true):
C:/Users/p/.local/share/gem/ruby/3.3.0/gems/minitest-5.25.5/lib/minitest...

- **test_goal_system.rb** (ruby_implementation)
  - Status: failed
  - Execution Time: 0.63s
  - Error: ...

- **test_string_literals.rb** (ruby_implementation)
  - Status: failed
  - Execution Time: 0.586s
  - Error: ...

- **test_cross_paradigm_coordination.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.653s
  - Error: ...

- **test_form_validation.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.675s
  - Error: ...

- **test_goal_declaration_syntax.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.649s
  - Error: ...

- **test_integration.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.657s
  - Error: ...

- **test_performance_optimization.rb** (patlang_language)
  - Status: failed
  - Execution Time: 1.011s
  - Error: ...

- **test_unified_reasoning_integration.rb** (integration)
  - Status: failed
  - Execution Time: 0.549s
  - Error: ...

## Error Tests

- **test_reasoning_coordinator.rb** (infrastructure)
  - Error Type: unknown_error
  - Execution Time: 0.346s
  - Error: ...

- **test_type_constraint_parser.rb** (infrastructure)
  - Error Type: unknown_error
  - Execution Time: 0.439s
  - Error: ...

- **test_evaluator_edge_cases.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.378s
  - Error: ...

- **test_evaluator_stress.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.897s
  - Error: ...

- **test_function_evaluator.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.404s
  - Error: ...

- **test_object_model_comprehensive.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.484s
  - Error: Global event handler error: Global handler error
Event handler error for test: Handler error
...

- **test_object_model_edge_cases.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.505s
  - Error: ...

- **test_reasoning_evaluator_integration.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.4s
  - Error: ...

- **test_string_operations.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.408s
  - Error: ...

- **test_type_constraints.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.386s
  - Error: ...

- **test_type_constraints_clean.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.375s
  - Error: ...

- **test_evaluator.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.417s
  - Error: ...

- **test_evaluator_error_handling.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.463s
  - Error: ...

- **test_function_integration.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.429s
  - Error: ...

- **test_object_evaluation.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.407s
  - Error: ...

- **test_reasoning_integration.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.411s
  - Error: ...

- **test_type_constraint_syntax.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.338s
  - Error: ...

- **test_constants.rb** (helpers)
  - Error Type: unknown_error
  - Execution Time: 0.417s
  - Error: E:/patlang/test/helpers/test_constants.rb:6: warning: already initialized constant TestConstants::TestEvaluatorBranchCoverage
E:/patlang/test/helpers/test_constants.rb:6: warning: previous definition o...
