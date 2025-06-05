# PATLANG TEST SUITE REORGANIZATION PLAN

## Overview
This document outlines the comprehensive reorganization of the Patlang test suite from a flat structure into three distinct categories for better control and meaningful coverage reports.

## Current State
- **534 passing tests** in flat structure
- **Analysis shows**: ~15-20% Patlang language tests, ~50-60% Ruby implementation tests, ~25-30% infrastructure tests
- **Mixed concerns** make coverage reporting and test management difficult

## New Directory Structure

```
test/
├── infrastructure/           # Lexer, parser, AST unit tests (~25-30%)
│   ├── test_lexer.rb
│   ├── test_lexer_comprehensive.rb  
│   ├── test_lexer_error_recovery.rb
│   ├── test_parser.rb
│   ├── test_parser_edge_cases.rb
│   ├── test_ast_nodes.rb
│   ├── test_function_lexer.rb
│   └── test_function_parser.rb
├── ruby_implementation/      # Direct Ruby object/class testing (~50-60%)
│   ├── test_object_model.rb
│   ├── test_object_model_comprehensive.rb
│   ├── test_object_model_stress.rb
│   ├── test_function_evaluator.rb
│   ├── test_evaluator_edge_cases.rb
│   ├── test_evaluator_stress.rb
│   ├── test_string_operations.rb
│   ├── test_string_literals.rb
│   └── test_extended_string_methods.rb
├── patlang_language/         # End-to-end Patlang syntax validation (~15-20%)
│   ├── test_evaluator.rb
│   ├── test_object_evaluation.rb
│   ├── test_flexible_function_syntax.rb
│   ├── test_control_flow_evaluator.rb
│   ├── test_is_keyword_implementation.rb
│   ├── test_integration.rb
│   ├── test_function_integration.rb
│   ├── test_function_validation.rb
│   ├── test_flexible_with_calls.rb
│   └── test_regression_core.rb
└── helpers/                  # Shared test utilities
    ├── test_helper.rb
    ├── category_helper.rb
    ├── coverage_helper.rb
    └── runner_helper.rb
```

## Test Categorization Rules

### Infrastructure Tests
**Definition**: Tests that validate Ruby infrastructure components (lexer, parser, AST)
**Pattern**: Test individual components without full evaluation chain
**Examples**:
- `assert_equal :NUMBER, tokens[0].type`
- `assert_instance_of NumberNode, ast`
- Tokenization correctness
- AST node creation and properties

### Ruby Implementation Tests  
**Definition**: Tests that directly instantiate Ruby classes without Patlang parsing
**Pattern**: Direct object creation and method calls
**Examples**:
- `PatlangObject.create_number(42)`
- `obj.send_message()`
- Direct Ruby class behavior testing
- Internal mechanics validation

### Patlang Language Tests
**Definition**: Tests using `Patlang.evaluate()` or full lexer→parser→evaluator chain
**Pattern**: Test actual Patlang syntax end-to-end
**Examples**:
- `Patlang.evaluate("42")`
- `parse_and_evaluate("x is 42")`
- Natural language syntax validation
- Complete feature integration

## File Migration Map

### Infrastructure Tests (8 files)
```
test_lexer.rb                    → infrastructure/test_lexer.rb
test_lexer_comprehensive.rb      → infrastructure/test_lexer_comprehensive.rb
test_lexer_error_recovery.rb     → infrastructure/test_lexer_error_recovery.rb
test_parser.rb                   → infrastructure/test_parser.rb
test_parser_edge_cases.rb        → infrastructure/test_parser_edge_cases.rb
test_ast_nodes.rb                → infrastructure/test_ast_nodes.rb
test_function_lexer.rb           → infrastructure/test_function_lexer.rb
test_function_parser.rb          → infrastructure/test_function_parser.rb
```

### Ruby Implementation Tests (9 files)
```
test_object_model.rb             → ruby_implementation/test_object_model.rb
test_object_model_comprehensive.rb → ruby_implementation/test_object_model_comprehensive.rb
test_object_model_stress.rb      → ruby_implementation/test_object_model_stress.rb
test_function_evaluator.rb       → ruby_implementation/test_function_evaluator.rb
test_evaluator_edge_cases.rb     → ruby_implementation/test_evaluator_edge_cases.rb
test_evaluator_stress.rb         → ruby_implementation/test_evaluator_stress.rb
test_string_operations.rb        → ruby_implementation/test_string_operations.rb
test_string_literals.rb          → ruby_implementation/test_string_literals.rb
test_extended_string_methods.rb  → ruby_implementation/test_extended_string_methods.rb
```

### Patlang Language Tests (10 files)
```
test_evaluator.rb                → patlang_language/test_evaluator.rb
test_object_evaluation.rb        → patlang_language/test_object_evaluation.rb
test_flexible_function_syntax.rb → patlang_language/test_flexible_function_syntax.rb
test_control_flow_evaluator.rb   → patlang_language/test_control_flow_evaluator.rb
test_is_keyword_implementation.rb → patlang_language/test_is_keyword_implementation.rb
test_integration.rb              → patlang_language/test_integration.rb
test_function_integration.rb     → patlang_language/test_function_integration.rb
test_function_validation.rb      → patlang_language/test_function_validation.rb
test_flexible_with_calls.rb     → patlang_language/test_flexible_with_calls.rb
test_regression_core.rb          → patlang_language/test_regression_core.rb
```

### Helpers (4 files)
```
test_helper.rb                   → helpers/test_helper.rb
                                   helpers/category_helper.rb (new)
                                   helpers/coverage_helper.rb (new)
                                   helpers/runner_helper.rb (new)
```

## New Test Runners

### Category-Specific Runners
- `rake test:infrastructure` - Run infrastructure tests only
- `rake test:ruby` - Run Ruby implementation tests only  
- `rake test:patlang` - Run Patlang language tests only
- `rake test:all` - Run all categories with combined coverage

### Coverage Configuration
- **Separate coverage reports** for each category
- **Combined coverage report** for overall project health
- **Category-specific thresholds** based on test maturity

## Implementation Strategy

### Phase 1: Structure Creation
1. Create new directory structure
2. Move files to appropriate categories
3. Update require paths in all files
4. Verify all tests still pass

### Phase 2: Test Runners & Coverage
1. Create category-specific test runners
2. Configure SimpleCov for category reporting
3. Create Rake tasks for each category
4. Update documentation

### Phase 3: Validation & Documentation
1. Verify 534 tests still pass
2. Generate coverage reports for each category
3. Update README with new test structure
4. Create usage documentation

## Expected Benefits

### Improved Test Management
- **Clear separation** of concerns
- **Independent execution** of test categories
- **Focused debugging** when issues arise
- **Better organization** for new test development

### Meaningful Coverage Reports
- **Infrastructure coverage**: Focus on component robustness
- **Ruby implementation coverage**: Focus on object model correctness  
- **Patlang language coverage**: Focus on end-to-end functionality
- **Category-specific goals** and thresholds

### Development Workflow Enhancement
- **Faster feedback loops** during development
- **Category-focused testing** during feature development
- **Clear test placement** guidelines for new tests
- **Improved CI/CD** pipeline possibilities

## Success Criteria
✅ All 534 tests pass after reorganization
✅ Each category runs independently
✅ Coverage reports are category-specific and meaningful
✅ New test structure is documented and easy to use
✅ Backward compatibility maintained during transition

---
*Reorganization Plan Date: January 6, 2025*
*Target: Transform flat test structure into organized categories*