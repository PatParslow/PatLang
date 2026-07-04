# Test-Driven Reasoning Implementation Strategy

## Executive Summary

This document establishes **Test-Driven Development (TDD)** as the primary implementation methodology for Patlang's unified reasoning features. The strategy emphasizes writing comprehensive tests FIRST to clarify requirements, encapsulate specifications, and enable confident implementation of Type Inference, Goal-Oriented Programming, and Logic Programming systems.

## Test-First Philosophy

### Core Principle: Tests as Living Documentation

Tests serve as the authoritative specification for reasoning features:

1. **Executable Requirements**: Tests define exactly what each feature must do
2. **Regression Protection**: Comprehensive coverage prevents existing functionality from breaking
3. **Refactoring Confidence**: Well-tested code can be optimized safely
4. **Implementation Guidance**: Tests guide the development process step-by-step

### TDD Cycle for Reasoning Features

```
┌─────────────────────────────────────────────────────────┐
│                    TDD Cycle for Reasoning              │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│ 1. RED: Write failing test that captures requirement    │
│    • Define expected behavior precisely                 │
│    • Include edge cases and error conditions           │
│    • Use meaningful test names and descriptions        │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│ 2. GREEN: Write minimal code to make test pass         │
│    • Implement just enough to satisfy the test         │
│    • Focus on correctness, not optimization            │
│    • Maintain existing test suite passing              │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│ 3. REFACTOR: Improve code while keeping tests green    │
│    • Optimize performance and readability              │
│    • Extract common patterns and utilities             │
│    • Maintain all tests passing throughout             │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│ 4. INTEGRATE: Ensure cross-paradigm compatibility      │
│    • Run full test suite across all categories         │
│    • Verify event system integration                   │
│    • Test cross-paradigm interactions                  │
└─────────────────────────────────────────────────────────┘
```

## Test Infrastructure Integration

### Existing Test Categories

Reasoning tests integrate seamlessly with Patlang's established test infrastructure:

```
test/
├── infrastructure/              # Core engine tests (134 existing + ~100 new)
├── patlang_language/           # Language feature tests (217 existing + ~150 new) 
└── ruby_implementation/        # Implementation tests (183 existing + ~50 new)
```

**Growth Strategy**: Expand from 534 existing tests to ~834 tests (~56% increase)

### Test Category Guidelines

#### Infrastructure Tests (`test/infrastructure/`)
**Purpose**: Test core reasoning engines and algorithms
**Scope**: Engine implementation details, performance, memory management

```ruby
# Example: test/infrastructure/test_unification_engine.rb
class TestUnificationEngine < Minitest::Test
  def setup
    @engine = UnificationEngine.new
    @event_log = []
    
    # Subscribe to unification events for testing
    @engine.on_event(:unification_started) { |e| @event_log << e }
    @engine.on_event(:unification_completed) { |e| @event_log << e }
  end
  
  def test_unify_identical_atoms_succeeds
    substitution = {}
    result = @engine.unify(:hello, :hello, substitution)
    
    assert result, "Identical atoms should unify successfully"
    assert_empty substitution, "No substitution needed for identical atoms"
    assert_equal 2, @event_log.length, "Should fire start and complete events"
  end
  
  def test_unify_different_atoms_fails
    substitution = {}
    result = @engine.unify(:hello, :world, substitution)
    
    refute result, "Different atoms should not unify"
    assert_empty substitution, "No substitution for failed unification"
  end
  
  def test_unify_variable_with_atom_creates_binding
    var = TypeVariable.new(:X)
    substitution = {}
    result = @engine.unify(var, :hello, substitution)
    
    assert result, "Variable should unify with atom"
    assert_equal :hello, substitution[:X], "Should bind variable to atom"
  end
  
  def test_unify_fires_appropriate_events
    var = TypeVariable.new(:X)
    substitution = {}
    @engine.unify(var, :hello, substitution)
    
    start_event = @event_log.find { |e| e[:event_type] == :unification_started }
    complete_event = @event_log.find { |e| e[:event_type] == :unification_completed }
    
    assert start_event, "Should fire unification_started event"
    assert complete_event, "Should fire unification_completed event"
    assert complete_event[:success], "Should indicate success in completion event"
  end
end
```

#### Patlang Language Tests (`test/patlang_language/`)
**Purpose**: Test language syntax, semantics, and integration
**Scope**: Parser integration, evaluator behavior, language features

```ruby
# Example: test/patlang_language/test_type_constraint_syntax.rb
class TestTypeConstraintSyntax < Minitest::Test
  def setup
    @evaluator = Evaluator.new
    @evaluator.enable_object_mode
    @evaluator.enable_reasoning_mode
  end
  
  def test_basic_type_constraint_declaration
    code = "constrain x :: Number"
    
    result = evaluate_patlang_code(code)
    
    assert_instance_of TypeConstraint, result
    assert_equal "x", result.variable
    assert_equal :type, result.constraint_type
    assert_equal :Number, result.constraint_data
  end
  
  def test_constraint_with_range_condition
    code = <<~PATLANG
      constrain age :: Number where age >= 0 and age <= 150
    PATLANG
    
    result = evaluate_patlang_code(code)
    
    assert_instance_of TypeConstraint, result
    assert_equal "age", result.variable
    assert result.has_condition?, "Should have range condition"
    
    # Test constraint validation
    assert result.satisfies?(25), "25 should satisfy age constraint"
    refute result.satisfies?(-5), "-5 should not satisfy age constraint"
    refute result.satisfies?(200), "200 should not satisfy age constraint"
  end
  
  def test_structural_type_constraint
    code = <<~PATLANG
      constrain person :: Object {
        name :: String,
        age :: Number where age >= 0,
        email :: String where email matches /\\w+@\\w+\\.\\w+/
      }
    PATLANG
    
    result = evaluate_patlang_code(code)
    
    assert_instance_of TypeConstraint, result
    assert_equal :structural, result.constraint_type
    
    # Test structural validation
    valid_person = {
      name: "John Doe",
      age: 30,
      email: "john@example.com"
    }
    
    invalid_person = {
      name: "Jane",
      age: -5,  # Invalid age
      email: "invalid-email"  # Invalid format
    }
    
    assert result.satisfies?(valid_person), "Valid person should satisfy constraint"
    refute result.satisfies?(invalid_person), "Invalid person should not satisfy constraint"
  end
  
  def test_constraint_violation_provides_helpful_error
    code = <<~PATLANG
      constrain x :: Number where x > 0
      x = -5
    PATLANG
    
    error = assert_raises(TypeConstraintViolation) do
      evaluate_patlang_code(code)
    end
    
    assert_equal "x", error.variable
    assert_includes error.message, "x > 0"
    assert_equal(-5, error.value)
  end
  
  private
  
  def evaluate_patlang_code(code)
    parser = Parser.new(Lexer.new(code))
    ast = parser.parse
    @evaluator.evaluate(ast)
  end
end
```

#### Ruby Implementation Tests (`test/ruby_implementation/`)
**Purpose**: Test Ruby-specific implementation details
**Scope**: Performance, memory management, Ruby integration

```ruby
# Example: test/ruby_implementation/test_reasoning_performance.rb
class TestReasoningPerformance < Minitest::Test
  def setup
    @coordinator = UnifiedReasoningCoordinator.new
    @performance_threshold = 100  # milliseconds
  end
  
  def test_unification_performance_scales_linearly
    # Test unification performance with increasing term complexity
    small_term = build_term(depth: 3, width: 2)
    medium_term = build_term(depth: 5, width: 3)
    large_term = build_term(depth: 7, width: 4)
    
    small_time = measure_unification_time(small_term, small_term)
    medium_time = measure_unification_time(medium_term, medium_term)
    large_time = measure_unification_time(large_term, large_term)
    
    # Performance should scale reasonably
    assert medium_time < small_time * 5, "Medium terms should not be 5x slower than small"
    assert large_time < medium_time * 3, "Large terms should not be 3x slower than medium"
    
    # All should complete within threshold
    assert small_time < @performance_threshold, "Small unification too slow: #{small_time}ms"
    assert medium_time < @performance_threshold * 2, "Medium unification too slow: #{medium_time}ms"
    assert large_time < @performance_threshold * 4, "Large unification too slow: #{large_time}ms"
  end
  
  def test_memory_usage_bounded_during_reasoning
    # Measure memory before reasoning
    initial_memory = measure_memory_usage
    
    # Perform extensive reasoning operations
    1000.times do |i|
      goal = Goal.new("test_goal_#{i}", [], [])
      @coordinator.goal_system.pursue_goal(goal)
    end
    
    # Force garbage collection
    GC.start
    
    final_memory = measure_memory_usage
    memory_increase = final_memory - initial_memory
    
    # Memory increase should be bounded (less than 10MB for 1000 operations)
    assert memory_increase < 10_000_000, "Memory usage increased too much: #{memory_increase} bytes"
  end
  
  private
  
  def measure_unification_time(term1, term2)
    start_time = Time.now
    @coordinator.type_system.unification_engine.unify(term1, term2, {})
    ((Time.now - start_time) * 1000).round(2)  # Convert to milliseconds
  end
  
  def measure_memory_usage
    GC.start  # Ensure clean measurement
    ObjectSpace.count_objects[:TOTAL] * 40  # Rough bytes estimation
  end
  
  def build_term(depth:, width:)
    return :atom if depth == 0
    
    args = width.times.map { |i| build_term(depth: depth - 1, width: width) }
    Term.new("func_#{depth}", args)
  end
end
```

## Phase-Specific Test Requirements

### Phase 1: Foundation and Type Inference Tests

#### Week 1: Unification Engine Tests (25-30 tests)

**Required Test Coverage:**
```ruby
# Core unification algorithm tests
def test_unify_identical_atoms
def test_unify_different_atoms_fails
def test_unify_variable_with_atom
def test_unify_variable_with_variable
def test_unify_compound_terms_same_functor
def test_unify_compound_terms_different_functor
def test_unify_nested_terms
def test_unify_with_existing_substitution
def test_unify_occurs_check_prevents_infinite_terms
def test_unify_with_partially_instantiated_terms

# Event system integration tests
def test_unification_fires_started_event
def test_unification_fires_completed_event
def test_unification_event_contains_correct_data
def test_multiple_unifications_generate_unique_events

# Error handling tests
def test_unify_handles_malformed_terms_gracefully
def test_unify_respects_type_constraints
def test_unify_fails_on_incompatible_types

# Performance tests
def test_unification_completes_within_time_limit
def test_deep_term_unification_performance
def test_memory_usage_bounded_during_unification
```

#### Week 2: Type Constraint System Tests (35-40 tests)

**Required Test Coverage:**
```ruby
# Basic constraint tests
def test_create_simple_type_constraint
def test_create_range_constraint
def test_create_pattern_constraint
def test_create_structural_constraint

# Constraint validation tests
def test_constraint_validates_correct_values
def test_constraint_rejects_incorrect_values
def test_constraint_provides_helpful_error_messages
def test_multiple_constraints_on_same_variable

# Propagation network tests
def test_constraint_propagation_updates_related_variables
def test_propagation_fires_type_refined_events
def test_propagation_handles_constraint_conflicts
def test_propagation_performance_scales_with_network_size

# Integration tests
def test_constraints_integrate_with_object_system
def test_constraints_respect_patlang_object_metadata
def test_constraint_cleanup_on_object_destruction
```

#### Week 3: Parser Integration Tests (20-25 tests)

**Required Test Coverage:**
```ruby
# Syntax parsing tests
def test_parse_basic_constraint_declaration
def test_parse_constraint_with_conditions
def test_parse_structural_type_constraints
def test_parse_nested_type_constraints
def test_parse_constraint_with_pattern_matching

# Error handling tests
def test_parse_invalid_constraint_syntax_reports_error
def test_parse_malformed_type_expression_reports_location
def test_parse_constraint_with_undefined_type_reports_error

# AST generation tests
def test_parser_creates_correct_ast_nodes
def test_ast_nodes_contain_complete_constraint_information
def test_ast_nodes_integrate_with_existing_node_hierarchy
```

#### Week 4: Evaluator Integration Tests (15-20 tests)

**Required Test Coverage:**
```ruby
# Basic evaluation tests
def test_evaluate_type_constraint_creates_constraint_object
def test_evaluate_constraint_in_object_mode_returns_object
def test_evaluate_constraint_in_value_mode_returns_boolean

# Integration tests
def test_constraints_affect_subsequent_assignments
def test_constraint_violations_provide_helpful_messages
def test_constraints_integrate_with_existing_evaluation_modes

# Performance tests
def test_constraint_evaluation_performance_acceptable
def test_constraint_checking_during_evaluation_efficient
```

### Phase 2: Goal-Oriented Programming Tests

#### Week 5: Goal System Foundation Tests (30-35 tests)

**Required Test Coverage:**
```ruby
# Goal lifecycle tests
def test_create_goal_with_preconditions_and_postconditions
def test_goal_status_transitions_correctly
def test_goal_fires_lifecycle_events
def test_goal_metadata_stored_in_patlang_object

# Goal pursuit tests
def test_pursue_simple_goal_succeeds
def test_pursue_goal_with_failing_precondition
def test_pursue_goal_with_unmet_postcondition
def test_goal_pursuit_fires_appropriate_events

# Error handling tests
def test_goal_failure_provides_helpful_information
def test_goal_timeout_handled_gracefully
def test_goal_stack_overflow_protection
```

#### Week 6: Goal Resolution Engine Tests (40-45 tests)

**Required Test Coverage:**
```ruby
# Basic resolution tests
def test_resolve_goal_with_simple_strategy
def test_resolution_respects_goal_preconditions
def test_resolution_validates_postconditions
def test_resolution_handles_strategy_failures

# Backtracking tests
def test_backtracking_on_goal_failure
def test_choice_point_creation_and_restoration
def test_multiple_choice_points_with_nested_backtracking
def test_backtracking_preserves_goal_stack_state

# Strategy pattern tests
def test_custom_strategy_registration
def test_strategy_selection_based_on_goal_type
def test_strategy_receives_correct_context
def test_multiple_strategies_tried_in_order
```

### Phase 3: Logic Programming Tests

#### Week 9: Facts Database Tests (30-35 tests)

**Required Test Coverage:**
```ruby
# Fact management tests
def test_assert_simple_fact
def test_assert_complex_fact_with_arguments
def test_retract_existing_fact
def test_update_fact_atomically

# Query tests
def test_query_existing_facts
def test_query_with_variable_binding
def test_query_with_multiple_variables
def test_query_returns_all_matching_facts

# Performance tests
def test_fact_assertion_performance
def test_fact_querying_with_large_database
def test_indexing_improves_query_performance
```

#### Week 10: Query Engine Tests (35-40 tests)

**Required Test Coverage:**
```ruby
# SLD resolution tests
def test_resolve_simple_query_against_facts
def test_resolve_query_against_rules
def test_resolve_recursive_queries
def test_resolution_with_unification

# Backtracking tests
def test_query_backtracking_finds_all_solutions
def test_backtracking_preserves_variable_bindings
def test_cut_prevents_backtracking

# Performance tests
def test_query_resolution_performance
def test_deep_recursion_handling
def test_query_termination_detection
```

### Phase 4: Cross-Paradigm Integration Tests

#### Week 13: Unified Coordinator Tests (45-50 tests)

**Required Test Coverage:**
```ruby
# Cross-paradigm communication tests
def test_type_refinement_notifies_goal_system
def test_goal_completion_updates_logic_facts
def test_logic_assertion_triggers_constraint_checking

# Integration scenario tests
def test_type_guided_goal_resolution
def test_logic_enhanced_type_checking
def test_goal_driven_fact_discovery

# Event coordination tests
def test_cross_paradigm_event_ordering
def test_event_loop_termination
def test_circular_dependency_prevention
```

## Test Design Patterns for Reasoning Features

### Pattern 1: Event-Driven Test Setup

```ruby
class ReasoningTestBase < Minitest::Test
  def setup
    @event_log = []
    @system_under_test = create_reasoning_system
    
    # Subscribe to all reasoning events for testing
    setup_event_logging
  end
  
  private
  
  def setup_event_logging
    [:type_refined, :goal_started, :goal_completed, :fact_asserted].each do |event_type|
      @system_under_test.on_event(event_type) do |event|
        @event_log << event.merge(timestamp: Time.now, event_type: event_type)
      end
    end
  end
  
  def assert_event_fired(event_type, **expected_data)
    matching_events = @event_log.select { |e| e[:event_type] == event_type }
    assert !matching_events.empty?, "Expected #{event_type} event to fire"
    
    if expected_data.any?
      matching_event = matching_events.find do |event|
        expected_data.all? { |key, value| event[key] == value }
      end
      assert matching_event, "Expected #{event_type} event with data #{expected_data}"
    end
  end
  
  def assert_event_sequence(*event_types)
    actual_sequence = @event_log.map { |e| e[:event_type] }
    assert_equal event_types, actual_sequence, "Event sequence mismatch"
  end
end
```

### Pattern 2: Cross-Paradigm Integration Testing

```ruby
class CrossParadigmTestHelper
  def self.test_type_goal_interaction
    # Set up type constraint
    constraint = create_type_constraint("x", :Number, range: 1..100)
    
    # Define goal that depends on type
    goal = Goal.new("find_valid_x") do |context|
      # Goal strategy uses type constraint to guide search
      (1..100).find { |value| constraint.satisfies?(value) && meets_goal_criteria(value) }
    end
    
    # Test interaction
    result = pursue_goal(goal)
    assert result.success?, "Goal should succeed with type guidance"
    assert constraint.satisfies?(result.value), "Result should satisfy type constraint"
  end
  
  def self.test_logic_type_interaction
    # Assert type-related facts
    assert_fact("typeof", ["x", :Number])
    assert_fact("range", [:Number, 1, 100])
    
    # Query should trigger type constraint creation
    result = query("typeof(x, Type) and range(Type, Min, Max)")
    
    # Verify type constraint was created
    constraint = get_type_constraint("x")
    assert constraint, "Type constraint should be created from logic facts"
    assert_equal 1..100, constraint.range, "Constraint should have correct range"
  end
end
```

### Pattern 3: Performance and Memory Testing

```ruby
module PerformanceTesting
  def measure_performance(description, max_time_ms: 100, &block)
    start_time = Time.now
    result = block.call
    duration_ms = ((Time.now - start_time) * 1000).round(2)
    
    assert duration_ms <= max_time_ms, 
           "#{description} took #{duration_ms}ms, expected <= #{max_time_ms}ms"
    
    result
  end
  
  def measure_memory_usage(description, max_increase_mb: 1, &block)
    GC.start
    initial_memory = get_memory_usage
    
    result = block.call
    
    GC.start
    final_memory = get_memory_usage
    increase_mb = (final_memory - initial_memory) / (1024.0 * 1024.0)
    
    assert increase_mb <= max_increase_mb,
           "#{description} increased memory by #{increase_mb}MB, expected <= #{max_increase_mb}MB"
    
    result
  end
  
  private
  
  def get_memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i * 1024  # Convert KB to bytes
  end
end
```

## Test Data Generation

### Property-Based Testing for Reasoning

```ruby
# Generate random terms for unification testing
class TermGenerator
  def self.random_term(max_depth: 3, variables: [:X, :Y, :Z])
    if max_depth == 0 || rand < 0.3
      if rand < 0.5
        # Generate atom
        "atom_#{rand(100)}"
      else
        # Generate variable
        TypeVariable.new(variables.sample)
      end
    else
      # Generate compound term
      functor = "func_#{rand(10)}"
      arity = rand(1..4)
      args = arity.times.map { random_term(max_depth: max_depth - 1, variables: variables) }
      Term.new(functor, args)
    end
  end
  
  def self.unifiable_pair
    base_term = random_term
    # Create a term that should unify with base_term
    modified_term = substitute_variables(base_term, random_substitution)
    [base_term, modified_term]
  end
end

# Generate random goals for testing
class GoalGenerator
  def self.random_goal
    Goal.new(
      "random_goal_#{rand(1000)}",
      preconditions: random_conditions,
      postconditions: random_conditions
    )
  end
  
  def self.solvable_goal
    # Generate a goal that has a known solution
    target_value = rand(1..100)
    Goal.new("find_target") do |context|
      (1..100).find { |x| x == target_value }
    end
  end
end
```

## Integration with Existing Test Infrastructure

### Leveraging Current Test Patterns

```ruby
# Follow existing test naming conventions
class TestUnifiedReasoning < Minitest::Test
  # Use existing helper methods
  include TestHelpers
  
  def setup
    # Initialize like existing evaluator tests
    @evaluator = Evaluator.new
    @evaluator.enable_object_mode
    
    # Add reasoning-specific setup
    @evaluator.enable_reasoning_mode
    @reasoning_coordinator = @evaluator.reasoning_coordinator
  end
  
  def test_reasoning_integrates_with_object_mode
    # Test follows existing object mode testing patterns
    code = <<~PATLANG
      obj = Object.new
      constrain obj.value :: Number where value > 0
      goal find_positive(obj) {
        postcondition: obj.value > 0 and obj.value < 100
      }
    PATLANG
    
    result = evaluate_code(code)
    assert_object_mode_result(result)
    assert_reasoning_constraints_satisfied(result)
  end
  
  # Use existing assertion patterns
  def test_reasoning_preserves_existing_functionality
    # Ensure all existing tests still pass
    run_subset_of_existing_tests([
      :test_basic_arithmetic,
      :test_object_creation,
      :test_function_calls
    ])
    
    # Add reasoning features
    code_with_reasoning = existing_code + reasoning_extensions
    result = evaluate_code(code_with_reasoning)
    
    assert_no_regression(result)
    assert_reasoning_features_work(result)
  end
end
```

### Test Organization Strategy

```ruby
# Use existing test runner infrastructure
class ReasoningTestRunner
  def self.run_all_reasoning_tests
    # Run in same pattern as existing test runner
    test_categories = [
      'test/infrastructure/test_unification_*.rb',
      'test/infrastructure/test_type_*.rb',
      'test/infrastructure/test_goal_*.rb',
      'test/infrastructure/test_logic_*.rb',
      'test/patlang_language/test_*_reasoning.rb',
      'test/ruby_implementation/test_reasoning_*.rb'
    ]
    
    test_categories.each do |pattern|
      Dir.glob(pattern).each { |file| require file }
    end
    
    # Use existing minitest runner
    Minitest.run([])
  end
  
  def self.run_integration_tests
    # Run tests that verify reasoning doesn't break existing functionality
    existing_test_files = Dir.glob('test/**/test_*.rb') - reasoning_test_files
    
    existing_test_files.each { |file| require file }
    Minitest.run([])
  end
end
```

## Continuous Integration Strategy

### Pre-Implementation Test Writing

Before implementing any reasoning feature:

1. **Write Comprehensive Tests**: Cover all expected behavior
2. **Include Edge Cases**: Test boundary conditions and error cases
3. **Add Performance Tests**: Ensure acceptable performance characteristics
4. **Write Integration Tests**: Verify compatibility with existing features
5. **Document Test Intent**: Clear test names and descriptions

### Implementation Verification

During implementation:

1. **Run Tests Frequently**: Verify progress with each small change
2. **Maintain Green State**: Keep all tests passing throughout development
3. **Add Tests for Bugs**: Write test first when bugs are discovered
4. **Refactor with Confidence**: Use tests to enable safe code improvements

### Post-Implementation Validation

After feature completion:

1. **Full Test Suite**: Run all tests including existing functionality
2. **Performance Benchmarks**: Verify performance targets are met
3. **Memory Usage**: Check for memory leaks and excessive usage
4. **Integration Scenarios**: Test real-world usage patterns

## Success Metrics for Test-Driven Implementation

### Quantitative Metrics

- **Test Coverage**: >95% code coverage for all reasoning features
- **Test Count**: ~300 new tests across all categories
- **Test Performance**: All tests complete in <5 minutes
- **Test Reliability**: <1% flaky test rate

### Qualitative Metrics

- **Test Clarity**: Tests serve as clear documentation
- **Test Maintainability**: Tests are easy to update and extend
- **Test Completeness**: Edge cases and error conditions covered
- **Test Integration**: Seamless with existing test infrastructure

## Implementation Timeline with Test-First Emphasis

### Week-by-Week Test Requirements

**Week 1**: Write 25-30 unification engine tests → Implement engine to pass
**Week 2**: Write 35-40 type constraint tests → Implement constraint system
**Week 3**: Write 20-25 parser integration tests → Implement syntax support
**Week 4**: Write 15-20 evaluator integration tests → Complete Phase 1

Continue this pattern through all phases, always writing tests first and implementing to satisfy them.

## Conclusion

This test-driven approach ensures that:

1. **Requirements are Clear**: Tests define exactly what needs to be built
2. **Implementation is Guided**: Tests provide step-by-step development direction
3. **Quality is Maintained**: Comprehensive testing prevents regressions
4. **Refactoring is Safe**: Good test coverage enables confident optimization
5. **Integration is Smooth**: Tests verify compatibility with existing systems

The test-first methodology transforms the complex task of implementing unified reasoning into a series of well-defined, verifiable steps, ensuring high-quality results and maintainable code throughout the development process.