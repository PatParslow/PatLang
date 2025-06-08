require_relative '../helpers/test_helper'
require_relative '../../src/reasoning/unification_engine'

class TestUnificationEngine < Minitest::Test
  def setup
    @engine = UnificationEngine.new
    @event_log = []
    
    # Subscribe to unification events for testing using the PatlangObject event system
    # The event system wraps our data in a :data key, so we need to extract it
    @engine.on_event(:unification_started) { |event| @event_log << event[:data].merge(event_type: :unification_started) }
    @engine.on_event(:unification_completed) { |event| @event_log << event[:data].merge(event_type: :unification_completed) }
    @engine.on_event(:unification_failed) { |event| @event_log << event[:data].merge(event_type: :unification_failed) }
  end

  # === Core Unification Algorithm Tests ===

  def test_unify_identical_atoms_succeeds
    substitution = {}
    result = @engine.unify(:hello, :hello, substitution)
    
    assert result, "Identical atoms should unify successfully"
    assert_empty substitution, "No substitution needed for identical atoms"
    assert_equal 2, @event_log.length, "Should fire start and complete events"
    
    assert_event_fired(:unification_started)
    assert_event_fired(:unification_completed, success: true)
  end

  def test_unify_different_atoms_fails
    substitution = {}
    result = @engine.unify(:hello, :world, substitution)
    
    refute result, "Different atoms should not unify"
    assert_empty substitution, "No substitution for failed unification"
    
    assert_event_fired(:unification_started)
    assert_event_fired(:unification_failed)
  end

  def test_unify_variable_with_atom_creates_binding
    var = TypeVariable.new(:X)
    substitution = {}
    result = @engine.unify(var, :hello, substitution)
    
    assert result, "Variable should unify with atom"
    assert_equal :hello, substitution[:X], "Should bind variable to atom"
    assert_event_fired(:unification_completed, success: true)
  end

  def test_unify_variable_with_variable_creates_alias
    var1 = TypeVariable.new(:X)
    var2 = TypeVariable.new(:Y)
    substitution = {}
    result = @engine.unify(var1, var2, substitution)
    
    assert result, "Variables should unify with each other"
    # Either X maps to Y or Y maps to X
    assert(substitution[:X] == var2 || substitution[:Y] == var1, 
           "One variable should map to the other")
  end

  def test_unify_compound_terms_same_functor
    term1 = Term.new("parent", [:john, :mary])
    term2 = Term.new("parent", [:john, :mary])
    substitution = {}
    result = @engine.unify(term1, term2, substitution)
    
    assert result, "Identical compound terms should unify"
    assert_empty substitution, "No substitution needed for identical terms"
  end

  def test_unify_compound_terms_different_functor_fails
    term1 = Term.new("parent", [:john, :mary])
    term2 = Term.new("child", [:john, :mary])
    substitution = {}
    result = @engine.unify(term1, term2, substitution)
    
    refute result, "Terms with different functors should not unify"
    assert_empty substitution, "No substitution for failed unification"
  end

  def test_unify_compound_terms_different_arity_fails
    term1 = Term.new("parent", [:john, :mary])
    term2 = Term.new("parent", [:john, :mary, :bob])
    substitution = {}
    result = @engine.unify(term1, term2, substitution)
    
    refute result, "Terms with different arity should not unify"
    assert_empty substitution, "No substitution for failed unification"
  end

  def test_unify_nested_terms
    var_x = TypeVariable.new(:X)
    var_y = TypeVariable.new(:Y)
    
    term1 = Term.new("loves", [:mary, Term.new("father", [var_x])])
    term2 = Term.new("loves", [var_y, Term.new("father", [:john])])
    
    substitution = {}
    result = @engine.unify(term1, term2, substitution)
    
    assert result, "Nested terms should unify when possible"
    assert_equal :john, substitution[:X], "X should be bound to john"
    assert_equal :mary, substitution[:Y], "Y should be bound to mary"
  end

  def test_unify_with_existing_substitution
    var_x = TypeVariable.new(:X)
    existing_substitution = { X: :john }
    
    result = @engine.unify(var_x, :john, existing_substitution)
    assert result, "Should unify variable with value already in substitution"
    
    result = @engine.unify(var_x, :mary, existing_substitution)
    refute result, "Should fail to unify variable with different value"
  end

  def test_unify_occurs_check_prevents_infinite_terms
    var_x = TypeVariable.new(:X)
    term = Term.new("f", [var_x])
    substitution = {}
    
    result = @engine.unify(var_x, term, substitution)
    
    # Should fail occurs check (X cannot unify with f(X))
    refute result, "Occurs check should prevent infinite term creation"
    assert_empty substitution, "No substitution when occurs check fails"
  end

  def test_unify_with_partially_instantiated_terms
    var_x = TypeVariable.new(:X)
    var_y = TypeVariable.new(:Y)
    
    # First unify X with a value
    substitution = { X: :john }
    
    # Now try to unify a term containing X with another term
    term1 = Term.new("parent", [var_x, var_y])
    term2 = Term.new("parent", [:john, :mary])
    
    result = @engine.unify(term1, term2, substitution)
    
    assert result, "Should unify partially instantiated terms"
    assert_equal :john, substitution[:X], "X should remain bound to john"
    assert_equal :mary, substitution[:Y], "Y should be bound to mary"
  end

  # === Event System Integration Tests ===

  def test_unification_fires_started_event
    @engine.unify(:a, :b, {})
    
    started_events = @event_log.select { |e| e[:event_type] == :unification_started }
    assert_equal 1, started_events.length, "Should fire exactly one started event"
    
    event = started_events.first
    assert_equal :a, event[:term1], "Event should contain first term"
    assert_equal :b, event[:term2], "Event should contain second term"
    assert event[:timestamp], "Event should have timestamp"
  end

  def test_unification_fires_completed_event_on_success
    result = @engine.unify(:hello, :hello, {})
    assert result, "Unification should succeed"
    
    completed_events = @event_log.select { |e| e[:event_type] == :unification_completed }
    assert_equal 1, completed_events.length, "Should fire exactly one completed event"
    
    event = completed_events.first
    assert_equal true, event[:success], "Event should indicate success"
    assert event[:substitution], "Event should contain substitution"
  end

  def test_unification_fires_failed_event_on_failure
    result = @engine.unify(:hello, :world, {})
    refute result, "Unification should fail"
    
    failed_events = @event_log.select { |e| e[:event_type] == :unification_failed }
    assert_equal 1, failed_events.length, "Should fire exactly one failed event"
    
    event = failed_events.first
    assert_equal :hello, event[:term1], "Event should contain first term"
    assert_equal :world, event[:term2], "Event should contain second term"
    assert event[:reason], "Event should contain failure reason"
  end

  def test_unification_event_contains_correct_data
    var_x = TypeVariable.new(:X)
    substitution = {}
    
    @engine.unify(var_x, :hello, substitution)
    
    completed_event = @event_log.find { |e| e[:event_type] == :unification_completed }
    assert completed_event, "Should have completion event"
    
    assert_equal true, completed_event[:success], "Should indicate success"
    assert_equal({ X: :hello }, completed_event[:substitution], "Should contain substitution")
    assert completed_event[:term1].is_a?(TypeVariable), "Should contain original variable"
    assert_equal :hello, completed_event[:term2], "Should contain unified atom"
  end

  def test_multiple_unifications_generate_unique_events
    @engine.unify(:a, :a, {})
    @engine.unify(:b, :b, {})
    @engine.unify(:c, :d, {})  # This one fails
    
    assert_equal 6, @event_log.length, "Should have 6 events total (2 success + 1 failure × 2)"
    
    started_events = @event_log.select { |e| e[:event_type] == :unification_started }
    completed_events = @event_log.select { |e| e[:event_type] == :unification_completed }
    failed_events = @event_log.select { |e| e[:event_type] == :unification_failed }
    
    assert_equal 3, started_events.length, "Should have 3 started events"
    assert_equal 2, completed_events.length, "Should have 2 completed events"
    assert_equal 1, failed_events.length, "Should have 1 failed event"
  end

  # === Error Handling Tests ===

  def test_unify_handles_nil_terms_gracefully
    error = assert_raises(ArgumentError) do
      @engine.unify(nil, :hello, {})
    end
    assert_includes error.message, "nil", "Error should mention nil term"
  end

  def test_unify_handles_malformed_terms_gracefully
    malformed_term = Object.new  # Not a valid term type
    
    error = assert_raises(ArgumentError) do
      @engine.unify(malformed_term, :hello, {})
    end
    assert_includes error.message.downcase, "invalid term", "Error should mention invalid term"
  end

  def test_unify_requires_hash_substitution
    error = assert_raises(ArgumentError) do
      @engine.unify(:a, :b, "not a hash")
    end
    assert_includes error.message.downcase, "substitution", "Error should mention substitution"
  end

  # === Performance Tests ===

  def test_unification_completes_within_time_limit
    start_time = Time.now
    
    # Perform many simple unifications
    1000.times do |i|
      @engine.unify("atom_#{i}".to_sym, "atom_#{i}".to_sym, {})
    end
    
    duration = Time.now - start_time
    assert duration < 1.0, "1000 simple unifications should complete in under 1 second, took #{duration}s"
  end

  def test_deep_term_unification_performance
    # Create deeply nested terms
    deep_term1 = build_deep_term(depth: 10)
    deep_term2 = build_deep_term(depth: 10)
    
    start_time = Time.now
    result = @engine.unify(deep_term1, deep_term2, {})
    duration = Time.now - start_time
    
    assert result, "Deep terms should unify successfully"
    assert duration < 0.1, "Deep term unification should complete in under 100ms, took #{duration}s"
  end

  def test_memory_usage_bounded_during_unification
    # Measure memory before
    GC.start
    initial_objects = ObjectSpace.count_objects[:TOTAL]
    
    # Perform many unifications
    500.times do |i|
      var = TypeVariable.new("X_#{i}".to_sym)
      @engine.unify(var, "value_#{i}", {})
    end
    
    # Measure memory after
    GC.start
    final_objects = ObjectSpace.count_objects[:TOTAL]
    object_increase = final_objects - initial_objects
    
    # Should not create excessive objects (reasonable bound for 500 operations)
    assert object_increase < 10000, "Memory usage increased by #{object_increase} objects, should be < 10000"
  end

  private

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

  def build_deep_term(depth:)
    return :leaf if depth == 0
    Term.new("f", [build_deep_term(depth: depth - 1)])
  end
end