# Test Directory

This directory contains comprehensive tests for the Patlang language implementation.

## Running Tests

### Main Test Runner

Use the **fixed comprehensive coverage runner** to execute all tests with coverage analysis:

```bash
ruby test/fixed_comprehensive_coverage_runner.rb
```

This runner will:
- Discover and execute all legitimate test files
- Collect comprehensive coverage data with branch analysis
- Generate HTML coverage reports in `test/coverage/`
- Provide detailed execution summaries
- Handle timeouts and errors gracefully

### Test Structure

The tests are organized into the following categories:

#### Core Language Tests (`core/`)
- **test_ast_nodes_comprehensive.rb** - AST node comprehensive testing
- **test_lexer_comprehensive.rb** - Lexer comprehensive testing

#### Infrastructure Tests (`infrastructure/`)
- **test_ast_nodes.rb** - AST node infrastructure
- **test_complex_logic_queries.rb** - Complex logic query testing
- **test_error_handling_coverage.rb** - Error handling coverage
- **test_evaluator_coverage_enhancement.rb** - Evaluator coverage enhancement
- **test_facts_database.rb** - Facts database testing
- **test_function_lexer.rb** - Function lexer testing
- **test_function_parser.rb** - Function parser testing
- **test_goal_resolution_engine.rb** - Goal resolution engine
- **test_lexer_branch_coverage.rb** - Lexer branch coverage
- **test_lexer_comprehensive.rb** - Lexer comprehensive testing
- **test_lexer_coverage_enhancement.rb** - Lexer coverage enhancement
- **test_lexer_error_recovery.rb** - Lexer error recovery
- **test_lexer_error_scenarios.rb** - Lexer error scenarios
- **test_lexer.rb** - Basic lexer testing
- **test_parser_branch_coverage.rb** - Parser branch coverage
- **test_parser_coverage_enhancement.rb** - Parser coverage enhancement
- **test_parser_edge_cases.rb** - Parser edge cases
- **test_parser.rb** - Basic parser testing
- **test_reasoning_coordinator.rb** - Reasoning coordinator
- **test_type_constraint_parser.rb** - Type constraint parser
- **test_type_constraint_system.rb** - Type constraint system
- **test_unification_engine.rb** - Unification engine

#### Patlang Language Tests (`patlang_language/`)
- **test_control_flow_evaluator.rb** - Control flow evaluation
- **test_cross_paradigm_coordination.rb** - Cross-paradigm coordination
- **test_enhanced_reasoning_parser.rb** - Enhanced reasoning parser
- **test_evaluator_branch_coverage.rb** - Evaluator branch coverage
- **test_evaluator_error_handling.rb** - Evaluator error handling
- **test_evaluator_reasoning.rb** - Evaluator reasoning
- **test_evaluator.rb** - Basic evaluator testing
- **test_flexible_function_syntax.rb** - Flexible function syntax
- **test_flexible_with_calls.rb** - Flexible with calls
- **test_form_validation.rb** - Form validation
- **test_function_integration.rb** - Function integration
- **test_function_validation.rb** - Function validation
- **test_goal_declaration_syntax.rb** - Goal declaration syntax
- **test_integration.rb** - Integration testing
- **test_is_keyword_implementation.rb** - Is keyword implementation
- **test_logic_programming_syntax.rb** - Logic programming syntax
- **test_object_evaluation.rb** - Object evaluation
- **test_performance_optimization.rb** - Performance optimization
- **test_reasoning_integration.rb** - Reasoning integration
- **test_regression_core.rb** - Regression testing
- **test_type_constraint_syntax.rb** - Type constraint syntax

#### Ruby Implementation Tests (`ruby_implementation/`)
- **test_advanced_goal_strategies.rb** - Advanced goal strategies
- **test_evaluator_edge_cases.rb** - Evaluator edge cases
- **test_evaluator_stress.rb** - Evaluator stress testing
- **test_extended_string_methods.rb** - Extended string methods
- **test_function_evaluator.rb** - Function evaluator
- **test_goal_system.rb** - Goal system testing
- **test_object_model_comprehensive.rb** - Object model comprehensive
- **test_object_model_edge_cases.rb** - Object model edge cases
- **test_object_model_stress.rb** - Object model stress testing
- **test_object_model.rb** - Basic object model testing
- **test_reasoning_evaluator_integration.rb** - Reasoning evaluator integration
- **test_string_literals.rb** - String literals
- **test_string_operations.rb** - String operations
- **test_type_constraints_clean.rb** - Type constraints (clean)
- **test_type_constraints.rb** - Type constraints

#### Integration Tests (`integration/`)
- **test_unified_reasoning_integration.rb** - Unified reasoning integration

#### Helper Files (`helpers/`)
- **config_loader.rb** - Configuration loading utilities
- **test_constants.rb** - Test constants
- **test_helper.rb** - Test helper utilities

### Configuration

- **test_config.json** - Test configuration settings
- **test_helper.rb** - Global test helper and setup

### Coverage Reports

After running tests, coverage reports are generated in:
- **test/coverage/index.html** - HTML coverage report
- Console output with coverage percentages and statistics

## Test Cleanup History

This directory was cleaned up on 2025-01-17 to remove:
- 76 redundant test runner scripts
- 37 outdated diagnostic and analysis scripts
- Multiple broken validation and debugging tools
- Generated report files and temporary artifacts

All cleanup files were backed up to `test/removed_scripts_backup/` for reference.

## Notes

- The main runner uses SimpleCov for coverage analysis with branch tracking
- Tests are designed to run without external dependencies where possible  
- Coverage thresholds are set to reasonable levels for development (20% line, 10% branch)
- All legitimate test files in subdirectories are preserved and executed