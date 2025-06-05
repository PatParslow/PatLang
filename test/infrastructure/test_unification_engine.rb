# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/reasoning/unification_engine'

# Test the core unification engine for type inference and reasoning
class TestUnificationEngine < Minitest::Test
  def setup
    @engine = UnificationEngine.new
    @event_log = []
    
    # Subscribe to unification events for testing
    @engine.on_event(:unification_started) { |e| @event_log << e }
    @engine.on_event(:unification_completed) { |e| @event_log << e }
    @engine.on_event(:unification_failed) { |e| @event_log << e }
  end

  # === Core Unification Algorithm Tests ===

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
    assert_events_fired [:unification_started, :unification_failed]
  end

  def test_unify_variable_with_atom_creates_binding
    var = TypeVariable.new(:X)
    substitution = {}
    result = @engine.unify(var, :hello, substitution)
    
    assert result, "Variable should unify with atom"
    assert_equal :hello, substitution[:X], "Should bind variable to atom"
    assert_events_fired [:unification_started, :unification_completed]
  end

  def test_unify_variable_with_variable_creates_chain
    var1 = TypeVariable.new(:X)
    var2 = TypeVariable.new(:Y)
    substitution = {}
    result = @engine.unify(var1, var2, substitution)
    
    assert result, "Variables should unify with each other"
    assert substitution.key?(:X) || substitution.key?(:Y), "Should create variable binding"
    assert_events_fired [:unification_started, :unification_completed]
  end

  def test_unify_compound_terms_same_functor
    term1 = Term.new(:likes, [:alice, :bob])
    term2 = Term.new(:likes, [:alice, :bob])
    substitution = {}
    result = @engine.unify(term1, term2, substitution)
    
    assert result, "Identical compound terms should unify"
    assert_empty substitution, "No substitution needed for identical compound terms"
  end

  def test_unify_compound_terms_different_functor_fails
    term1 = Term.new(:likes, [:alice, :bob])
    term2 = Term.new(:hates, [:alice, :bob])
    substitution = {}
    result = @engine.unify(term1, term2, substitution)
    
    refute result, "Compound terms with different functors should not unify"
    assert_empty substitution, "No substitution for failed unification"
  end

  def test_unify_compound_terms_different_arity_fails
    term1 = Term.new(:likes, [:alice, :bob])
    term2 = Term.new(:likes, [:alice])
    substitution = {}
    result = @engine.unify(term1, term2, substitution)
    
    refute result, "Compound terms with different arity should not unify"
    assert_empty substitution, "No substitution for failed unification"
  end

  def test_unify_nested_terms_with_variables
    var_x = TypeVariable.new(:X)
    var_y = TypeVariable.new(:Y)
    term1 = Term.new(:f, [Term.new(:g, [var_x]), :a])
    term2 = Term.new(:f, [Term.new(:g, [:b]), var_y])
    substitution = {}
    result = @engine.unify(term1, term2, substitution)
    
    assert result, "Nested terms with variables should unify"
    assert_equal :b, substitution[:X], "X should be bound to :b"
    assert_equal :a, substitution[:Y], "Y should be bound to :a"
  end

  def test_unify_with_existing_substitution
    var_x = TypeVariable.new(:X)
    existing_substitution = { X: :alice }
    result = @engine.unify(var_x, :alice, existing_substitution)
    
    assert result, "Should unify with consistent existing substitution"
    assert_equal :alice, existing_substitution[:X], "Substitution should remain unchanged"
  end

  def test_unify_with_conflicting_substitution_fails
    var_x = TypeVariable.new(:X)
    existing_substitution = { X: :alice }
    result = @engine.unify(var_x, :bob, existing_substitution)
    
    refute result, "Should fail with conflicting existing substitution"
    assert_equal :alice, existing_substitution[:X], "Original substitution should be preserved"
  end

  def test_unify_occurs_check_prevents_infinite_terms
    var_x = TypeVariable.new(:X)
    term = Term.new(:f, [var_x])
    substitution = {}
    result = @engine.unify(var_x, term, substitution)
    
    refute result, "Occurs check should prevent X = f(X)"
    assert_empty substitution, "No substitution should be created"
  end

  def test_unify_complex_occurs_check
    var_x = TypeVariable.new(:X)
    var_y = TypeVariable.new(:Y)
    term = Term.new(:f, [var_y, Term.new(:g, [var_x])])
    substitution = { Y: var_x }
    result = @engine.unify(var_x, term, substitution)
    
    refute result, "Complex occurs check should prevent infinite terms"
  end

  # === Event System Integration Tests ===

  def test_unification_fires_started_event
    @engine.unify(:a, :a, {})
    
    start_event = @event_log.find { |e| e[:event_type] == :unification_started }
    assert start_event, "Should fire unification_started event"
    assert_equal :a, start_event[:term1], "Event should contain first term"
    assert_equal :a, start_event[:term2], "Event should contain second term"
  end

  def test_unification_fires_completed_event
    @engine.unify(:a, :a, {})
    
    complete_event = @event_log.find { |e| e[:event_type] == :unification_completed }
    assert complete_event, "Should fire unification_completed event"
    assert complete_event[:success], "Should indicate success in completion event"
    assert_instance_of Hash, complete_event[:substitution], "Should include substitution"
  end

  def test_unification_fires_failed_event
    @engine.unify(:a, :b, {})
    
    failed_event = @event_log.find { |e| e[:event_type] == :unification_failed }
    assert failed_event, "Should fire unification_failed event"
    assert_equal :a, failed_event[:term1], "Should include terms that failed to unify"
    assert_equal :b, failed_event[:term2], "Should include terms that failed to unify"
  end

  def test_multiple_unifications_generate_unique_events
    @engine.unify(:a, :a, {})
    @engine.unify(:b, :b, {})
    
    assert_operator @event_log.length, :>=, 4, "Should have events for both unifications"
    
    # Each unification should have unique event IDs
    event_ids = @event_log.map { |e| e[:event_id] }.compact
    assert_equal event_ids.uniq.length, event_ids.length, "Event IDs should be unique"
  end

  # === Error Handling Tests ===

  def test_unify_handles_malformed_terms_gracefully
    malformed_term = Object.new
    
    error = assert_raises(UnificationError) do
      @engine.unify(malformed_term, :atom, {})
    end
    
    assert_includes error.message, "malformed"
    assert_includes error.message, "term"
  end

  def test_unify_handles_nil_terms
    error = assert_raises(UnificationError) do
      @engine.unify(nil, :atom, {})
    end
    
    assert_includes error.message, "nil"
  end

  def test_unify_requires_valid_substitution_hash
    error = assert_raises(UnificationError) do
      @engine.unify(:a, :a, "not a hash")
    end
    
    assert_includes error.message, "substitution"
    assert_includes error.message, "Hash"
  end

  # === Performance Tests ===

  def test_unification_completes_within_time_limit
    start_time = Time.now
    
    # Perform multiple unifications
    100.times do |i|
      var = TypeVariable.new("X#{i}".to_sym)
      @engine.unify(var, "value#{i}".to_sym, {})
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 0.1, "100 unifications should complete in <100ms"
  end

  def test_deep_term_unification_performance
    # Create deeply nested terms
    deep_term1 = build_deep_term(depth: 10, base: :a)
    deep_term2 = build_deep_term(depth: 10, base: :a)
    
    start_time = Time.now
    result = @engine.unify(deep_term1, deep_term2, {})
    duration = Time.now - start_time
    
    assert result, "Deep terms should unify successfully"
    assert_operator duration, :<, 0.05, "Deep unification should complete in <50ms"
  end

  def test_memory_usage_bounded_during_unification
    # This is a basic memory test - in practice you'd use more sophisticated tools
    initial_object_count = ObjectSpace.count_objects[:TOTAL]
    
    # Perform many unifications
    1000.times do |i|
      var = TypeVariable.new("temp#{i}".to_sym)
      @engine.unify(var, :value, {})
    end
    
    GC.start
    final_object_count = ObjectSpace.count_objects[:TOTAL]
    object_increase = final_object_count - initial_object_count
    
    # Allow some object creation but not excessive
    assert_operator object_increase, :<, 5000, "Memory usage should be bounded"
  end

  # === Integration Tests ===

  def test_unification_integrates_with_type_constraints
    # This test requires type constraints to be implemented
    skip "Type constraints not yet implemented"
    
    constraint = TypeConstraint.new(:X, :Number)
    var_x = TypeVariable.new(:X)
    
    result = @engine.unify(var_x, 42, {}, constraints: [constraint])
    assert result, "Should unify variable with number when constraint allows"
    
    result = @engine.unify(var_x, "string", {}, constraints: [constraint])
    refute result, "Should not unify variable with string when number constraint exists"
  end

  def test_unification_respects_object_system_metadata
    # This test requires object system integration
    skip "Object system integration not yet implemented"
    
    patlang_object = PatlangObject.new
    patlang_object.set_metadata(:type, :Number)
    
    result = @engine.unify(patlang_object, 42, {})
    assert result, "Should respect object system type metadata"
  end

  private

  def assert_events_fired(expected_event_types)
    actual_event_types = @event_log.map { |e| e[:event_type] }
    assert_equal expected_event_types, actual_event_types,
                 "Expected events #{expected_event_types}, got #{actual_event_types}"
  end

  def build_deep_term(depth:, base:)
    return base if depth == 0
    Term.new(:f, [build_deep_term(depth: depth - 1, base: base)])
  end
end

# Real implementation is now loaded from src/reasoning/unification_engine.rb