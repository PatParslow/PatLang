# frozen_string_literal: true

require_relative 'reasoning_coordinator'

# Facts storage, retrieval, and querying system
# Provides logic programming foundation with comprehensive query capabilities
class FactsDatabase
  def initialize(evaluator)
    @evaluator = evaluator
    @reasoning_coordinator = nil
    @facts = []
    @rules = []
    @event_handlers = {}
    @indexes = {}
  end

  def set_reasoning_coordinator(coordinator)
    @reasoning_coordinator = coordinator
  end

  def on_event(event_type, &block)
    @event_handlers[event_type] ||= []
    @event_handlers[event_type] << block
  end

  def assert_fact(fact)
    parsed_fact = parse_fact(fact)
    
    unless @facts.include?(fact)
      @facts << fact
      index_fact(parsed_fact) if parsed_fact
      
      fire_event(:fact_asserted, {
        fact: fact,
        parsed_fact: parsed_fact,
        total_facts: @facts.length,
        timestamp: Time.now
      })
    end
    
    true
  end

  def has_fact?(fact)
    @facts.include?(fact)
  end

  def retract_fact(fact)
    if @facts.include?(fact)
      @facts.delete(fact)
      
      fire_event(:fact_retracted, {
        fact: fact,
        total_facts: @facts.length,
        timestamp: Time.now
      })
      
      true
    else
      false
    end
  end

  def retract_facts_matching(pattern)
    matching_facts = find_facts_matching_pattern(pattern)
    count = 0
    
    matching_facts.each do |fact|
      if retract_fact(fact)
        count += 1
      end
    end
    
    count
  end

  def define_rule(rule)
    parsed_rule = parse_rule(rule)
    
    unless @rules.find { |r| r == rule }
      @rules << rule
      
      fire_event(:rule_defined, {
        rule: rule,
        parsed_rule: parsed_rule,
        total_rules: @rules.length,
        timestamp: Time.now
      })
    end
    
    true
  end

  def has_rule?(rule_name)
    @rules.any? { |rule| rule.include?(rule_name) }
  end

  def query(query_string)
    results = execute_query(query_string)
    
    fire_event(:query_executed, {
      query: query_string,
      results: results,
      result_count: results.length,
      timestamp: Time.now
    })
    
    results
  end

  def query_with_aggregation(query)
    # Simple aggregation for testing
    case query
    when /sum\((\w+)\)/
      field = $1
      values = extract_numeric_values_from_facts(field)
      values.sum
    when /max\((\w+)\)/
      field = $1
      values = extract_numeric_values_from_facts(field)
      values.max
    when /avg\((\w+)\)/
      field = $1
      values = extract_numeric_values_from_facts(field)
      values.empty? ? 0 : values.sum.to_f / values.length
    else
      nil
    end
  end

  def query_at_time(timestamp, query)
    # Simple temporal query implementation
    query(query).select do |result|
      # Mock temporal filtering
      true
    end
  end

  def query_valid_now(query)
    # Query facts valid at current time
    current_time = Time.now
    query_at_time(current_time, query)
  end

  def assert_typed_fact(fact)
    # Assert fact with type information
    assert_fact(fact)
  end

  def query_with_unification(query)
    # Unification-based query execution
    query(query)
  end

  def create_index(predicate, fields)
    index = FactIndex.new(predicate, fields)
    @indexes[predicate] = index
    
    # Add existing facts to index
    @facts.each do |fact|
      parsed = parse_fact(fact)
      if parsed && parsed.predicate == predicate
        index.add_fact(parsed)
      end
    end
    
    true
  end

  def all_facts
    @facts.dup
  end

  def fact_count
    @facts.length
  end

  def all_rules
    @rules.dup
  end

  def rule_count
    @rules.length
  end

  private

  def fire_event(event_type, data)
    @event_handlers[event_type]&.each { |handler| handler.call(data.merge(event_type: event_type)) }
  end

  def parse_fact(fact_string)
    return nil unless validate_fact_syntax(fact_string)
    
    if fact_string =~ /^(\w+)\((.*)\)$/
      predicate = $1
      args_string = $2
      arguments = parse_arguments(args_string)
      Fact.new(predicate, arguments)
    elsif fact_string =~ /^(\w+)$/
      predicate = $1
      Fact.new(predicate, [])
    else
      nil
    end
  end

  def parse_rule(rule_string)
    # Simple rule parsing for basic Prolog-like syntax
    if rule_string =~ /rule\s+(.+)\s+:-\s+(.+)/
      head_str = $1.strip
      body_str = $2.strip
      
      head = parse_fact(head_str)
      body_goals = body_str.split(',').map { |goal| parse_fact(goal.strip) }.compact
      
      Rule.new(head, body_goals) if head
    else
      nil
    end
  end

  def parse_query(query_string)
    # Parse query into goals
    if query_string.include?(';')
      # Disjunctive query
      goals = query_string.split(';').map { |goal| parse_fact(goal.strip) }.compact
      { type: :disjunctive, goals: goals }
    elsif query_string.include?(',')
      # Conjunctive query
      goals = query_string.split(',').map { |goal| parse_fact(goal.strip) }.compact
      { type: :conjunctive, goals: goals }
    else
      # Single goal
      goal = parse_fact(query_string.strip)
      { type: :single, goals: [goal].compact }
    end
  end

  def unify_terms(term1, term2, bindings = {})
    # Basic unification algorithm
    return bindings if term1 == term2
    
    if variable?(term1)
      return unify_variable(term1, term2, bindings)
    elsif variable?(term2)
      return unify_variable(term2, term1, bindings)
    elsif term1.is_a?(Array) && term2.is_a?(Array) && term1.length == term2.length
      term1.each_with_index do |t1, i|
        bindings = unify_terms(t1, term2[i], bindings)
        return nil unless bindings
      end
      return bindings
    else
      return nil
    end
  end

  def resolve_query(parsed_query, current_bindings = {})
    # Simple SLD resolution
    case parsed_query[:type]
    when :single
      resolve_single_goal(parsed_query[:goals].first, current_bindings)
    when :conjunctive
      resolve_conjunctive_goals(parsed_query[:goals], current_bindings)
    when :disjunctive
      resolve_disjunctive_goals(parsed_query[:goals], current_bindings)
    else
      []
    end
  end

  def apply_rule(rule, query, bindings)
    # Apply rule to resolve query
    rule_head = parse_fact(rule.split(':-').first.strip.sub('rule ', ''))
    return [] unless rule_head
    
    unified_bindings = unify_terms(query, rule_head, bindings)
    return [] unless unified_bindings
    
    # For simple rules, return the bindings
    [QueryResult.new(unified_bindings, satisfied: true)]
  end

  def match_fact_pattern(fact, pattern, bindings = {})
    fact_obj = parse_fact(fact)
    pattern_obj = parse_fact(pattern)
    
    return false unless fact_obj && pattern_obj
    return false unless fact_obj.predicate == pattern_obj.predicate
    return false unless fact_obj.arity == pattern_obj.arity
    
    unified = unify_terms(fact_obj.arguments, pattern_obj.arguments, bindings)
    unified ? true : false
  end

  def index_fact(fact)
    # Add to predicate-based index
    if fact && fact.predicate
      @indexes[fact.predicate] ||= FactIndex.new(fact.predicate, [])
      @indexes[fact.predicate].add_fact(fact)
    end
  end

  def find_facts_by_predicate(predicate)
    @facts.select do |fact|
      parsed = parse_fact(fact)
      parsed && parsed.predicate == predicate
    end
  end

  def execute_query(query_string)
    parsed_query = parse_query(query_string)
    return [] unless parsed_query
    
    resolve_query(parsed_query)
  end

  def find_facts_matching_pattern(pattern)
    @facts.select do |fact|
      match_fact_pattern(fact, pattern)
    end
  end

  def resolve_single_goal(goal, bindings)
    return [] unless goal
    
    results = []
    
    # Try to match against facts
    @facts.each do |fact|
      fact_obj = parse_fact(fact)
      next unless fact_obj
      
      if fact_obj.predicate == goal.predicate && fact_obj.arity == goal.arity
        unified = unify_terms(goal.arguments, fact_obj.arguments, bindings)
        if unified
          results << QueryResult.new(unified, satisfied: true)
        end
      end
    end
    
    # Try to apply rules
    @rules.each do |rule|
      rule_results = apply_rule(rule, goal, bindings)
      results.concat(rule_results)
    end
    
    results
  end

  def resolve_conjunctive_goals(goals, bindings)
    return [QueryResult.new(bindings, satisfied: true)] if goals.empty?
    
    first_goal = goals.first
    remaining_goals = goals[1..-1]
    
    results = []
    first_results = resolve_single_goal(first_goal, bindings)
    
    first_results.each do |result|
      if remaining_goals.empty?
        results << result
      else
        sub_results = resolve_conjunctive_goals(remaining_goals, result.bindings)
        results.concat(sub_results)
      end
    end
    
    results
  end

  def resolve_disjunctive_goals(goals, bindings)
    results = []
    
    goals.each do |goal|
      goal_results = resolve_single_goal(goal, bindings)
      results.concat(goal_results)
    end
    
    results
  end

  def parse_arguments(args_string)
    return [] if args_string.strip.empty?
    
    args = []
    current_arg = ""
    paren_depth = 0
    
    args_string.each_char do |char|
      case char
      when '('
        paren_depth += 1
        current_arg += char
      when ')'
        paren_depth -= 1
        current_arg += char
      when ','
        if paren_depth == 0
          args << parse_argument_value(current_arg.strip)
          current_arg = ""
        else
          current_arg += char
        end
      else
        current_arg += char
      end
    end
    
    args << parse_argument_value(current_arg.strip) unless current_arg.empty?
    args
  end

  def parse_argument_value(value)
    value = value.strip
    
    case value
    when /^\d+$/
      value.to_i
    when /^\d+\.\d+$/
      value.to_f
    when /^'(.*)'$/, /^"(.*)"$/
      $1
    when /^(\w+)\((.*)\)$/
      # Compound term
      { predicate: $1, arguments: parse_arguments($2) }
    else
      value
    end
  end

  def variable?(term)
    term.is_a?(String) && term =~ /^[A-Z]\w*$/
  end

  def unify_variable(var, term, bindings)
    if bindings.key?(var)
      unify_terms(bindings[var], term, bindings)
    elsif bindings.key?(term)
      unify_terms(var, bindings[term], bindings)
    else
      bindings.merge(var => term)
    end
  end

  def extract_numeric_values_from_facts(field)
    values = []
    @facts.each do |fact|
      if fact =~ /#{field}\(.*?,\s*(\d+)\)/
        values << $1.to_i
      end
    end
    values
  end

  def validate_fact_syntax(fact_string)
    # Validate that fact string has correct syntax
    # Implementation needed for GREEN phase
    true  # Mock validation for RED phase
  end

  def validate_rule_syntax(rule_string)
    # Validate that rule string has correct syntax
    # Implementation needed for GREEN phase
    true  # Mock validation for RED phase
  end
end

class Fact
  attr_reader :predicate, :arguments, :arity, :timestamp

  def initialize(predicate, arguments = [], timestamp: Time.now)
    @predicate = predicate
    @arguments = arguments
    @arity = arguments.length
    @timestamp = timestamp
  end

  def matches?(pattern, bindings = {})
    # Check if this fact matches the given pattern
    # Implementation needed for GREEN phase
    false
  end

  def to_s
    if @arguments.empty?
      @predicate
    else
      "#{@predicate}(#{@arguments.join(', ')})"
    end
  end

  def ==(other)
    other.is_a?(Fact) &&
      @predicate == other.predicate &&
      @arguments == other.arguments
  end

  def hash
    [@predicate, @arguments].hash
  end
end

class Rule
  attr_reader :head, :body, :name

  def initialize(head, body = [], name: nil)
    @head = head
    @body = body
    @name = name || generate_name
  end

  def arity
    @head.arity
  end

  def applies_to?(query)
    # Check if this rule can be applied to resolve the query
    # Implementation needed for GREEN phase
    false
  end

  def to_s
    if @body.empty?
      @head.to_s
    else
      "#{@head} :- #{@body.map(&:to_s).join(', ')}"
    end
  end

  private

  def generate_name
    "rule_#{@head.predicate}_#{@head.arity}"
  end
end

class QueryResult
  attr_reader :bindings, :satisfied

  def initialize(bindings = {}, satisfied: false)
    @bindings = bindings
    @satisfied = satisfied
  end

  def satisfied?
    @satisfied
  end

  def [](variable)
    @bindings[variable]
  end

  def to_h
    @bindings
  end
end

class QueryEngine
  def initialize(facts_database)
    @facts_database = facts_database
  end

  def execute(query_string)
    # Execute query and return results
    # Implementation needed for GREEN phase
    []
  end

  def execute_with_aggregation(query_string)
    # Execute aggregation query
    # Implementation needed for GREEN phase
    nil
  end

  private

  def sld_resolution(goals, bindings = {})
    # SLD resolution algorithm
    # Implementation needed for GREEN phase
    []
  end

  def backtrack_search(goals, bindings, depth = 0)
    # Backtracking search for goal satisfaction
    # Implementation needed for GREEN phase
    []
  end
end

class FactIndex
  def initialize(predicate, fields)
    @predicate = predicate
    @fields = fields
    @index = {}
  end

  def add_fact(fact)
    # Add fact to index
    # Implementation needed for GREEN phase
  end

  def remove_fact(fact)
    # Remove fact from index
    # Implementation needed for GREEN phase
  end

  def find_matching_facts(pattern)
    # Find facts matching pattern using index
    # Implementation needed for GREEN phase
    []
  end
end