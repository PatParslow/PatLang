#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'src/evaluator'
require_relative 'src/reasoning/facts_database'
require_relative 'src/reasoning/reasoning_coordinator'

puts "🔍 DETAILED UNIFICATION DEBUGGING"
puts "=" * 50

# Initialize the facts database system
evaluator = Evaluator.new
evaluator.enable_object_mode
facts_db = FactsDatabase.new(evaluator)
reasoning_coordinator = ReasoningCoordinator.new(evaluator)
facts_db.set_reasoning_coordinator(reasoning_coordinator)

# Override the resolve_single_goal method to add detailed logging
class << facts_db
  alias_method :original_resolve_single_goal, :resolve_single_goal
  alias_method :original_unify_terms, :unify_terms
  alias_method :original_parse_fact, :parse_fact
  
  def resolve_single_goal(goal, bindings)
    puts "\n🎯 RESOLVE_SINGLE_GOAL DEBUG:"
    puts "  Goal: #{goal.inspect}"
    puts "  Goal predicate: #{goal&.predicate}"
    puts "  Goal arguments: #{goal&.arguments}"
    puts "  Initial bindings: #{bindings}"
    
    return [] unless goal
    
    results = []
    
    # Try to match against facts
    @facts.each_with_index do |fact, index|
      puts "\n  📋 Checking fact #{index + 1}: #{fact}"
      fact_obj = parse_fact(fact)
      puts "    Parsed fact: #{fact_obj.inspect}"
      next unless fact_obj
      
      puts "    Fact predicate: #{fact_obj.predicate}"
      puts "    Fact arguments: #{fact_obj.arguments}"
      puts "    Goal predicate: #{goal.predicate}"
      puts "    Goal arguments: #{goal.arguments}"
      
      if fact_obj.predicate == goal.predicate && fact_obj.arity == goal.arity
        puts "    ✅ Predicate and arity match!"
        puts "    Attempting unification..."
        puts "    Goal args: #{goal.arguments.inspect}"
        puts "    Fact args: #{fact_obj.arguments.inspect}"
        
        unified = unify_terms(goal.arguments, fact_obj.arguments, bindings)
        puts "    Unification result: #{unified.inspect}"
        
        if unified
          puts "    ✅ UNIFICATION SUCCESSFUL: #{unified}"
          result = QueryResult.new(unified, satisfied: true)
          results << result
          puts "    Added result: #{result.inspect}"
        else
          puts "    ❌ Unification failed"
        end
      else
        puts "    ❌ Predicate/arity mismatch"
      end
    end
    
    puts "\n  📊 Final results count: #{results.length}"
    results.each_with_index { |r, i| puts "    Result #{i+1}: #{r.inspect}" }
    
    results
  end
  
  def unify_terms(term1, term2, bindings = {})
    puts "\n    🔗 UNIFY_TERMS:"
    puts "      Term1: #{term1.inspect} (#{term1.class})"
    puts "      Term2: #{term2.inspect} (#{term2.class})"
    puts "      Bindings: #{bindings.inspect}"
    
    result = original_unify_terms(term1, term2, bindings)
    puts "      Result: #{result.inspect}"
    result
  end
  
  def parse_fact(fact_string)
    result = original_parse_fact(fact_string)
    puts "    🔍 PARSE_FACT: '#{fact_string}' → #{result.inspect}"
    result
  end
end

# Test the problematic query
facts_db.assert_fact("likes(alice, bob)")
puts "\n🎯 Testing query: likes(alice, X)"
results = facts_db.query("likes(alice, X)")

puts "\n📋 FINAL ANALYSIS:"
puts "Results count: #{results.length}"
results.each_with_index do |result, i|
  puts "Result #{i+1}:"
  puts "  Class: #{result.class}"
  puts "  Bindings: #{result.bindings.inspect}"
  puts "  Satisfied: #{result.satisfied?}"
end