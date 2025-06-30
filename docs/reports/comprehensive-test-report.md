# Comprehensive Test Suite Report

Generated: 2025-06-17T10:33:37+01:00
Execution Time: 29.5s

## Executive Summary

- **Total Test Files**: 59
- **Passed**: 24 (40.7%)
- **Failed**: 16
- **Errors**: 19

## Coverage Analysis

- **Line Coverage**: 9.38%
- **Branch Coverage**: N/A%
- **Files Analyzed**: 1
- **Low Coverage Files**: 1

## Results by Category

### Infrastructure
- Passed: 9
- Failed: 5
- Errors: 2
- Execution Time: 10.09s

### Ruby_implementation
- Passed: 3
- Failed: 3
- Errors: 9
- Execution Time: 6.99s

### Patlang_language
- Passed: 6
- Failed: 7
- Errors: 7
- Execution Time: 9.7s

### Integration
- Passed: 0
- Failed: 1
- Errors: 0
- Execution Time: 0.36s

### Helpers
- Passed: 0
- Failed: 0
- Errors: 1
- Execution Time: 0.32s

### Branch_coverage
- Passed: 2
- Failed: 0
- Errors: 0
- Execution Time: 0.66s

### Root_level
- Passed: 4
- Failed: 0
- Errors: 0
- Execution Time: 1.37s

## Recommendations

### 1. Line coverage is below 80%. Focus on adding tests for uncovered code. (high priority)
**Action**: Add tests for low-coverage files

### 2. 19 files have unknown error errors (high priority)
**Action**: Investigate and fix these errors

## Failed Tests

- **test_complex_logic_queries.rb** (infrastructure)
  - Status: failed
  - Execution Time: 0.375s
  - Error: ...

- **test_function_parser.rb** (infrastructure)
  - Status: failed
  - Execution Time: 0.743s
  - Error: ...

- **test_lexer_error_scenarios.rb** (infrastructure)
  - Status: failed
  - Execution Time: 0.973s
  - Error: ...

- **test_parser.rb** (infrastructure)
  - Status: failed
  - Execution Time: 1.232s
  - Error: ...

- **test_parser_edge_cases.rb** (infrastructure)
  - Status: failed
  - Execution Time: 1.582s
  - Error: #<Thread:0x000002d57c638630 E:/patlang/ruby-host/bootstrap/emergency_timeout.rb:18 run> terminated with exception (report_on_exception is true):
C:/Users/p/.local/share/gem/ruby/3.3.0/gems/minitest-5.25.5/lib/minitest...

- **test_extended_string_methods.rb** (ruby_implementation)
  - Status: failed
  - Execution Time: 0.603s
  - Error: ...

- **test_goal_system.rb** (ruby_implementation)
  - Status: failed
  - Execution Time: 0.504s
  - Error: ...

- **test_string_literals.rb** (ruby_implementation)
  - Status: failed
  - Execution Time: 0.37s
  - Error: ...

- **test_control_flow_evaluator.rb** (patlang_language)
  - Status: failed
  - Execution Time: 1.706s
  - Error: ...

- **test_cross_paradigm_coordination.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.416s
  - Error: ...

- **test_form_validation.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.492s
  - Error: ...

- **test_function_validation.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.587s
  - Error: ...

- **test_goal_declaration_syntax.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.526s
  - Error: ...

- **test_integration.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.418s
  - Error: ...

- **test_performance_optimization.rb** (patlang_language)
  - Status: failed
  - Execution Time: 0.643s
  - Error: ...

- **test_unified_reasoning_integration.rb** (integration)
  - Status: failed
  - Execution Time: 0.356s
  - Error: ...

## Error Tests

- **test_reasoning_coordinator.rb** (infrastructure)
  - Error Type: unknown_error
  - Execution Time: 0.301s
  - Error: ...

- **test_type_constraint_parser.rb** (infrastructure)
  - Error Type: unknown_error
  - Execution Time: 0.37s
  - Error: ...

- **test_evaluator_edge_cases.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.437s
  - Error: ...

- **test_evaluator_stress.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 1.186s
  - Error: ...

- **test_function_evaluator.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.432s
  - Error: ...

- **test_object_model_comprehensive.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.352s
  - Error: Global event handler error: Global handler error
Event handler error for test: Handler error
...

- **test_object_model_edge_cases.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.298s
  - Error: ...

- **test_reasoning_evaluator_integration.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.315s
  - Error: ...

- **test_string_operations.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.435s
  - Error: ...

- **test_type_constraints.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.297s
  - Error: ...

- **test_type_constraints_clean.rb** (ruby_implementation)
  - Error Type: unknown_error
  - Execution Time: 0.296s
  - Error: ...

- **test_enhanced_reasoning_parser.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.426s
  - Error: ...

- **test_evaluator.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.33s
  - Error: ...

- **test_evaluator_error_handling.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.34s
  - Error: ...

- **test_function_integration.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.542s
  - Error: ...

- **test_object_evaluation.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.344s
  - Error: ...

- **test_reasoning_integration.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.332s
  - Error: ...

- **test_type_constraint_syntax.rb** (patlang_language)
  - Error Type: unknown_error
  - Execution Time: 0.303s
  - Error: ...

- **test_constants.rb** (helpers)
  - Error Type: unknown_error
  - Execution Time: 0.317s
  - Error: E:/patlang/test/helpers/test_constants.rb:6: warning: already initialized constant TestConstants::TestEvaluatorBranchCoverage
E:/patlang/test/helpers/test_constants.rb:6: warning: previous definition o...
