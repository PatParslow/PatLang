# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/reasoning/reasoning_coordinator'
require_relative '../../src/reasoning/facts_database'

# Comprehensive tests for logic programming syntax and semantics in the Patlang language
class TestLogicProgrammingSyntax < Minitest::Test
  def setup
    @evaluator = MockEvaluator.new
    @coordinator = ReasoningCoordinator.new(@evaluator)
    @coordinator.enable_reasoning_mode
    @event_log = []
    
    # Subscribe to logic programming events
    @coordinator.on_event(:fact_asserted) { |e| @event_log << e }
    @coordinator.on_event(:rule_defined) { |e| @event_log << e }
    @coordinator.on_event(:query_executed) { |e| @event_log << e }
  end

  # === Basic Fact Assertion Syntax Tests ===

  def test_simple_fact_assertion_syntax
    # Test: likes(alice, bob).
    @coordinator.assert_fact("likes(alice, bob)")
    
    facts = @coordinator.get_facts
    assert_includes facts, "likes(alice, bob)"
    assert_equal 1, facts.length
    assert_events_fired [:fact_asserted]
  end

  def test_multiple_fact_assertions_syntax
    # Test: Multiple facts about relationships
    facts_to_assert = [
      "likes(alice, bob)",
      "likes(bob, alice)",
      "likes(charlie, alice)",
      "knows(alice, charlie)"
    ]
    
    facts_to_assert.each { |fact| @coordinator.assert_fact(fact) }
    
    stored_facts = @coordinator.get_facts
    facts_to_assert.each do |fact|
      assert_includes stored_facts, fact
    end
    assert_equal 4, stored_facts.length
  end

  def test_fact_with_single_argument_syntax
    # Test: person(alice).
    @coordinator.assert_fact("person(alice)")
    @coordinator.assert_fact("person(bob)")
    @coordinator.assert_fact("person(charlie)")
    
    facts = @coordinator.get_facts
    assert_includes facts, "person(alice)"
    assert_includes facts, "person(bob)"
    assert_includes facts, "person(charlie)"
  end

  def test_fact_with_multiple_arguments_syntax
    # Test: parent(john, alice, 1965).
    @coordinator.assert_fact("parent(john, alice, 1965)")
    @coordinator.assert_fact("location(alice, newyork, usa)")
    @coordinator.assert_fact("score(bob, math, 95)")
    
    facts = @coordinator.get_facts
    assert_includes facts, "parent(john, alice, 1965)"
    assert_includes facts, "location(alice, newyork, usa)"
    assert_includes facts, "score(bob, math, 95)"
  end

  def test_fact_with_no_arguments_syntax
    # Test: true. / empty().
    @coordinator.assert_fact("database_connected")
    @coordinator.assert_fact("system_initialized")
    
    facts = @coordinator.get_facts
    assert_includes facts, "database_connected"
    assert_includes facts, "system_initialized"
  end

  def test_fact_with_numeric_arguments_syntax
    # Test: age(alice, 30).
    @coordinator.assert_fact("age(alice, 30)")
    @coordinator.assert_fact("height(bob, 180.5)")
    @coordinator.assert_fact("temperature(room1, 22.5)")
    
    facts = @coordinator.get_facts
    assert_includes facts, "age(alice, 30)"
    assert_includes facts, "height(bob, 180.5)"
    assert_includes facts, "temperature(room1, 22.5)"
  end

  def test_fact_with_string_arguments_syntax
    # Test: name(person1, "Alice Smith").
    @coordinator.assert_fact('name(person1, "Alice Smith")')
    @coordinator.assert_fact('email(alice, "alice@example.com")')
    @coordinator.assert_fact('message(system, "Hello, World!")')
    
    facts = @coordinator.get_facts
    assert_includes facts, 'name(person1, "Alice Smith")'
    assert_includes facts, 'email(alice, "alice@example.com")'
    assert_includes facts, 'message(system, "Hello, World!")'
  end

  # === Rule Definition Syntax Tests ===

  def test_simple_rule_definition_syntax
    # Test: friend(X, Y) :- likes(X, Y), likes(Y, X).
    @coordinator.define_rule("friend(X, Y) :- likes(X, Y), likes(Y, X)")
    
    rules = @coordinator.get_rules
    assert_includes rules, "friend(X, Y) :- likes(X, Y), likes(Y, X)"
    assert_equal 1, rules.length
    assert_events_fired [:rule_defined]
  end

  def test_rule_with_single_condition_syntax
    # Test: adult(X) :- age(X, A), A >= 18.
    @coordinator.define_rule("adult(X) :- age(X, A), A >= 18")
    
    rules = @coordinator.get_rules
    assert_includes rules, "adult(X) :- age(X, A), A >= 18"
  end

  def test_rule_with_multiple_conditions_syntax
    # Test: grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
    @coordinator.define_rule("grandparent(X, Z) :- parent(X, Y), parent(Y, Z)")
    @coordinator.define_rule("sibling(X, Y) :- parent(Z, X), parent(Z, Y), X != Y")
    
    rules = @coordinator.get_rules
    assert_includes rules, "grandparent(X, Z) :- parent(X, Y), parent(Y, Z)"
    assert_includes rules, "sibling(X, Y) :- parent(Z, X), parent(Z, Y), X != Y"
  end

  def test_rule_with_complex_conditions_syntax
    # Test: eligible(X) :- age(X, A), A >= 18, A <= 65, citizen(X), not(criminal(X)).
    @coordinator.define_rule("eligible(X) :- age(X, A), A >= 18, A <= 65, citizen(X), not(criminal(X))")
    
    rules = @coordinator.get_rules
    assert_includes rules, "eligible(X) :- age(X, A), A >= 18, A <= 65, citizen(X), not(criminal(X))"
  end

  def test_rule_with_arithmetic_conditions_syntax
    # Test: total_score(Student, Total) :- score(Student, math, M), score(Student, english, E), Total is M + E.
    @coordinator.define_rule("total_score(Student, Total) :- score(Student, math, M), score(Student, english, E), Total is M + E")
    
    rules = @coordinator.get_rules
    assert_includes rules, "total_score(Student, Total) :- score(Student, math, M), score(Student, english, E), Total is M + E"
  end

  def test_recursive_rule_definition_syntax
    # Test: ancestor(X, Y) :- parent(X, Y).
    # Test: ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).
    @coordinator.define_rule("ancestor(X, Y) :- parent(X, Y)")
    @coordinator.define_rule("ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y)")
    
    rules = @coordinator.get_rules
    assert_includes rules, "ancestor(X, Y) :- parent(X, Y)"
    assert_includes rules, "ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y)"
  end

  def test_fact_rule_combination_syntax
    # Test: Combining facts and rules
    @coordinator.define_rule("path(X, Y) :- edge(X, Y)")
    @coordinator.define_rule("path(X, Y) :- edge(X, Z), path(Z, Y)")
    
    rules = @coordinator.get_rules
    assert_includes rules, "path(X, Y) :- edge(X, Y)"
    assert_includes rules, "path(X, Y) :- edge(X, Z), path(Z, Y)"
  end

  # === Query Syntax Tests ===

  def test_simple_query_syntax
    # Setup facts for querying
    @coordinator.assert_fact("likes(alice, bob)")
    @coordinator.assert_fact("likes(alice, charlie)")
    @coordinator.assert_fact("likes(bob, alice)")
    
    # Test: ?- likes(alice, X).
    results = @coordinator.query("likes(alice, X)")
    
    assert_instance_of Array, results
    assert_events_fired [:query_executed]
  end

  def test_ground_query_syntax
    # Test: Query with all ground terms
    @coordinator.assert_fact("likes(alice, bob)")
    @coordinator.assert_fact("likes(bob, charlie)")
    
    # Test: ?- likes(alice, bob).
    results = @coordinator.query("likes(alice, bob)")
    
    assert_instance_of Array, results
  end

  def test_variable_query_syntax
    # Test: Query with variables
    @coordinator.assert_fact("parent(john, alice)")
    @coordinator.assert_fact("parent(john, bob)")
    @coordinator.assert_fact("parent(mary, alice)")
    
    # Test: ?- parent(john, X).
    results = @coordinator.query("parent(john, X)")
    
    assert_instance_of Array, results
  end

  def test_multiple_variable_query_syntax
    # Test: Query with multiple variables
    @coordinator.assert_fact("works_at(alice, company_a)")
    @coordinator.assert_fact("works_at(bob, company_b)")
    @coordinator.assert_fact("works_at(charlie, company_a)")
    
    # Test: ?- works_at(X, Y).
    results = @coordinator.query("works_at(X, Y)")
    
    assert_instance_of Array, results
  end

  def test_complex_query_syntax
    # Test: Complex query with constraints
    @coordinator.assert_fact("age(alice, 25)")
    @coordinator.assert_fact("age(bob, 30)")
    @coordinator.assert_fact("age(charlie, 20)")
    @coordinator.define_rule("adult(X) :- age(X, A), A >= 18")
    
    # Test: ?- adult(X), age(X, A), A < 30.
    results = @coordinator.query("adult(X)")
    
    assert_instance_of Array, results
  end

  # === Type Constraint Integration Syntax Tests ===

  def test_type_fact_assertion_syntax
    # Test: typeof(X, Type) facts
    @coordinator.assert_fact("typeof(x, number)")
    @coordinator.assert_fact("typeof(name, string)")
    @coordinator.assert_fact("typeof(flag, boolean)")
    
    facts = @coordinator.get_facts
    assert_includes facts, "typeof(x, number)"
    assert_includes facts, "typeof(name, string)"
    assert_includes facts, "typeof(flag, boolean)"
  end

  def test_range_fact_assertion_syntax
    # Test: range(Variable, Min, Max) facts
    @coordinator.assert_fact("range(age, 0, 120)")
    @coordinator.assert_fact("range(score, 0, 100)")
    @coordinator.assert_fact("range(temperature, -273, 1000)")
    
    facts = @coordinator.get_facts
    assert_includes facts, "range(age, 0, 120)"
    assert_includes facts, "range(score, 0, 100)"
    assert_includes facts, "range(temperature, -273, 1000)"
  end

  def test_constraint_rule_definition_syntax
    # Test: Rules that work with type constraints
    @coordinator.define_rule("valid_age(X) :- typeof(X, number), range(age, Min, Max), X >= Min, X <= Max")
    @coordinator.define_rule("valid_score(S) :- typeof(S, number), S >= 0, S <= 100")
    
    rules = @coordinator.get_rules
    assert_includes rules, "valid_age(X) :- typeof(X, number), range(age, Min, Max), X >= Min, X <= Max"
    assert_includes rules, "valid_score(S) :- typeof(S, number), S >= 0, S <= 100"
  end

  def test_cross_paradigm_integration_syntax
    # Test: Integration between logic programming and type constraints
    @coordinator.assert_fact("typeof(score, number)")
    @coordinator.create_constraint(:score, :type, :Number)
    @coordinator.create_constraint(:score, :range, 0..100)
    
    # The type fact should be consistent with the constraint
    inferred_type = @coordinator.infer_type_from_facts(:score)
    assert_equal :Number, inferred_type
    
    constraint = @coordinator.get_constraint(:score)
    assert_instance_of TypeConstraint, constraint
    assert_equal :type, constraint.constraint_type
  end

  # === Event Generation Tests ===

  def test_fact_assertion_events
    @coordinator.assert_fact("test_fact(value)")
    
    fact_events = @event_log.select { |e| e[:event_type] == :fact_asserted }
    assert fact_events.any?
    
    fact_event = fact_events.first
    assert_equal "test_fact(value)", fact_event[:fact]
    assert_equal 1, fact_event[:total_facts]
  end

  def test_rule_definition_events
    @coordinator.define_rule("test_rule(X) :- test_fact(X)")
    
    rule_events = @event_log.select { |e| e[:event_type] == :rule_defined }
    assert rule_events.any?
    
    rule_event = rule_events.first
    assert_equal "test_rule(X) :- test_fact(X)", rule_event[:rule]
    assert_equal 1, rule_event[:total_rules]
  end

  def test_query_execution_events
    @coordinator.assert_fact("query_test(data)")
    @coordinator.query("query_test(X)")
    
    query_events = @event_log.select { |e| e[:event_type] == :query_executed }
    assert query_events.any?
    
    query_event = query_events.first
    assert_equal "query_test(X)", query_event[:query]
    assert_instance_of Array, query_event[:results]
    assert_instance_of Integer, query_event[:result_count]
  end

  # === Logic Programming Database Tests ===

  def test_facts_database_integration
    # Test that facts are properly stored and retrievable
    facts_to_store = [
      "student(alice)",
      "student(bob)",
      "course(math)",
      "course(english)",
      "enrolled(alice, math)",
      "enrolled(bob, english)"
    ]
    
    facts_to_store.each { |fact| @coordinator.assert_fact(fact) }
    
    stored_facts = @coordinator.get_facts
    assert_equal facts_to_store.length, stored_facts.length
    facts_to_store.each { |fact| assert_includes stored_facts, fact }
  end

  def test_rules_database_integration
    # Test that rules are properly stored and retrievable
    rules_to_store = [
      "takes_course(Student, Course) :- enrolled(Student, Course)",
      "classmate(X, Y) :- enrolled(X, Course), enrolled(Y, Course), X != Y",
      "eligible_for_advanced(Student) :- grade(Student, Course, Grade), Grade >= 85"
    ]
    
    rules_to_store.each { |rule| @coordinator.define_rule(rule) }
    
    stored_rules = @coordinator.get_rules
    assert_equal rules_to_store.length, stored_rules.length
    rules_to_store.each { |rule| assert_includes stored_rules, rule }
  end

  # === Complex Logic Programming Scenarios ===

  def test_family_relationship_scenario
    # Define family facts
    family_facts = [
      "parent(john, alice)",
      "parent(john, bob)",
      "parent(mary, alice)",
      "parent(mary, bob)",
      "parent(alice, charlie)",
      "parent(bob, diana)",
      "male(john)",
      "male(bob)",
      "male(charlie)",
      "female(mary)",
      "female(alice)",
      "female(diana)"
    ]
    
    family_facts.each { |fact| @coordinator.assert_fact(fact) }
    
    # Define family rules
    family_rules = [
      "father(X, Y) :- parent(X, Y), male(X)",
      "mother(X, Y) :- parent(X, Y), female(X)",
      "grandparent(X, Z) :- parent(X, Y), parent(Y, Z)",
      "sibling(X, Y) :- parent(Z, X), parent(Z, Y), X != Y"
    ]
    
    family_rules.each { |rule| @coordinator.define_rule(rule) }
    
    # Verify facts and rules are stored
    assert_equal family_facts.length, @coordinator.get_facts.length
    assert_equal family_rules.length, @coordinator.get_rules.length
    
    # Test queries
    father_query_results = @coordinator.query("father(john, X)")
    assert_instance_of Array, father_query_results
    
    grandparent_query_results = @coordinator.query("grandparent(X, Y)")
    assert_instance_of Array, grandparent_query_results
  end

  def test_course_enrollment_scenario
    # Define academic facts
    academic_facts = [
      "student(alice)",
      "student(bob)",
      "student(charlie)",
      "course(math101)",
      "course(english101)",
      "course(physics101)",
      "enrolled(alice, math101)",
      "enrolled(alice, english101)",
      "enrolled(bob, math101)",
      "enrolled(charlie, physics101)",
      "grade(alice, math101, 95)",
      "grade(alice, english101, 88)",
      "grade(bob, math101, 92)",
      "grade(charlie, physics101, 78)"
    ]
    
    academic_facts.each { |fact| @coordinator.assert_fact(fact) }
    
    # Define academic rules
    academic_rules = [
      "taking(Student, Course) :- enrolled(Student, Course)",
      "passed(Student, Course) :- grade(Student, Course, Grade), Grade >= 70",
      "honor_student(Student) :- grade(Student, Course, Grade), Grade >= 90",
      "classmates(X, Y) :- enrolled(X, Course), enrolled(Y, Course), X != Y"
    ]
    
    academic_rules.each { |rule| @coordinator.define_rule(rule) }
    
    # Test academic queries
    passed_query = @coordinator.query("passed(alice, X)")
    assert_instance_of Array, passed_query
    
    honor_query = @coordinator.query("honor_student(X)")
    assert_instance_of Array, honor_query
  end

  # === Performance Tests ===

  def test_fact_assertion_performance
    start_time = Time.now
    
    1000.times do |i|
      @coordinator.assert_fact("performance_fact_#{i}(test_data)")
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 1.0, "1000 fact assertions should complete in <1s"
    
    facts = @coordinator.get_facts
    assert_equal 1000, facts.length
  end

  def test_rule_definition_performance
    start_time = Time.now
    
    100.times do |i|
      @coordinator.define_rule("performance_rule_#{i}(X) :- performance_fact_#{i}(X)")
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 0.5, "100 rule definitions should complete in <500ms"
    
    rules = @coordinator.get_rules
    assert_equal 100, rules.length
  end

  def test_query_execution_performance
    # Setup facts for querying
    50.times do |i|
      @coordinator.assert_fact("query_perf_fact_#{i}(data_#{i})")
    end
    
    start_time = Time.now
    
    50.times do |i|
      @coordinator.query("query_perf_fact_#{i}(X)")
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 0.5, "50 queries should complete in <500ms"
  end

  def test_large_database_performance
    # Create a large knowledge base
    start_time = Time.now
    
    # Add many facts
    500.times do |i|
      @coordinator.assert_fact("large_fact_#{i}(value_#{i})")
    end
    
    # Add many rules
    50.times do |i|
      @coordinator.define_rule("large_rule_#{i}(X) :- large_fact_#{i}(X)")
    end
    
    # Execute queries
    10.times do |i|
      @coordinator.query("large_fact_#{i * 10}(X)")
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 2.0, "Large database operations should complete in <2s"
    
    # Verify database size
    assert_equal 500, @coordinator.get_facts.length
    assert_equal 50, @coordinator.get_rules.length
  end

  # === Error Handling Tests ===

  def test_malformed_fact_handling
    # Test that malformed facts don't crash the system
    malformed_facts = [
      "malformed fact without parentheses",
      "incomplete(",
      ")",
      ""
    ]
    
    malformed_facts.each do |fact|
      assert_nothing_raised do
        @coordinator.assert_fact(fact)
      end
    end
    
    # All malformed facts should still be stored (garbage in, garbage out principle)
    facts = @coordinator.get_facts
    assert_equal malformed_facts.length, facts.length
  end

  def test_malformed_rule_handling
    # Test that malformed rules don't crash the system
    malformed_rules = [
      "malformed rule without proper syntax",
      "incomplete_rule(X) :-",
      ":- missing_head",
      ""
    ]
    
    malformed_rules.each do |rule|
      assert_nothing_raised do
        @coordinator.define_rule(rule)
      end
    end
    
    # All malformed rules should still be stored
    rules = @coordinator.get_rules
    assert_equal malformed_rules.length, rules.length
  end

  def test_empty_query_handling
    # Test queries with empty or malformed syntax
    empty_queries = ["", "malformed query", "?()", "incomplete("]
    
    empty_queries.each do |query|
      assert_nothing_raised do
        results = @coordinator.query(query)
        assert_instance_of Array, results
      end
    end
  end

  private

  def assert_events_fired(expected_event_types)
    actual_event_types = @event_log.map { |e| e[:event_type] }
    expected_event_types.each do |expected_type|
      assert_includes actual_event_types, expected_type,
                     "Expected event #{expected_type} to be fired"
    end
  end

  # Mock evaluator for testing
  class MockEvaluator
    def object_mode_enabled?
      false
    end
  end
end