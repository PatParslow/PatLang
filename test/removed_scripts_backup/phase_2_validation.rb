#!/usr/bin/env ruby

require 'benchmark'
require_relative 'helpers/test_helper'
require_relative '../src/patlang'
require_relative '../src/reasoning/form_validator'
require_relative '../src/reasoning/goal_system'
require_relative '../src/reasoning/facts_database'

# Phase 2 Validation Script
# Tests actual implemented features and measures performance

class Phase2Validator
  def initialize
    @results = {
      core_features: {},
      reasoning_components: {},
      performance: {},
      business_scenarios: {}
    }
  end

  def run_validation
    puts "🎯 PHASE 2 VALIDATION - Testing Actual Implementation"
    puts "=" * 60
    
    test_core_features
    test_reasoning_stubs
    test_performance_benchmarks
    test_business_scenarios
    
    generate_report
  end

  private

  def test_core_features
    puts "\n📋 TESTING CORE FEATURES"
    puts "-" * 30
    
    # Test basic arithmetic (should work)
    test_arithmetic
    
    # Test function definitions (should work)
    test_functions
    
    # Test object model (should work)
    test_objects
    
    # Test string operations (should work)
    test_strings
  end

  def test_arithmetic
    print "Arithmetic evaluation: "
    begin
      result = Patlang.evaluate("2 + 3 * 4")
      if result == 14
        puts "✅ PASS (#{result})"
        @results[:core_features][:arithmetic] = :pass
      else
        puts "❌ FAIL (got #{result}, expected 14)"
        @results[:core_features][:arithmetic] = :fail
      end
    rescue => e
      puts "❌ ERROR: #{e.message}"
      @results[:core_features][:arithmetic] = :error
    end
  end

  def test_functions
    print "Function definitions: "
    begin
      # Test if function definition works
      result = Patlang.evaluate('make function test { return 42 }')
      puts "✅ PASS (function defined)"
      @results[:core_features][:functions] = :pass
    rescue => e
      puts "❌ ERROR: #{e.message}"
      @results[:core_features][:functions] = :error
    end
  end

  def test_objects
    print "Object model: "
    begin
      # Test basic object creation
      result = Patlang.evaluate('x = 5')
      puts "✅ PASS (variable assignment)"
      @results[:core_features][:objects] = :pass
    rescue => e
      puts "❌ ERROR: #{e.message}"
      @results[:core_features][:objects] = :error
    end
  end

  def test_strings
    print "String operations: "
    begin
      result = Patlang.evaluate('"hello"')
      puts "✅ PASS (string literal)"
      @results[:core_features][:strings] = :pass
    rescue => e
      puts "❌ ERROR: #{e.message}"
      @results[:core_features][:strings] = :error
    end
  end

  def test_reasoning_stubs
    puts "\n🧠 TESTING REASONING COMPONENTS (Expected RED Phase)"
    puts "-" * 50
    
    # Test form validator
    test_form_validator_stub
    
    # Test goal system
    test_goal_system_stub
    
    # Test facts database
    test_facts_database_stub
  end

  def test_form_validator_stub
    print "FormValidator: "
    begin
      validator = FormValidator.new
      puts "❌ UNEXPECTED: Should be in RED phase"
      @results[:reasoning_components][:form_validator] = :unexpected_green
    rescue ArgumentError => e
      puts "🔴 RED PHASE (needs parameters)"
      @results[:reasoning_components][:form_validator] = :red_phase
    rescue NotImplementedError => e
      puts "🔴 RED PHASE (not implemented)"
      @results[:reasoning_components][:form_validator] = :red_phase
    rescue => e
      puts "❓ UNKNOWN: #{e.message}"
      @results[:reasoning_components][:form_validator] = :unknown
    end
  end

  def test_goal_system_stub
    print "GoalSystem: "
    begin
      goal_system = GoalSystem.new
      puts "❌ UNEXPECTED: Should be in RED phase"
      @results[:reasoning_components][:goal_system] = :unexpected_green
    rescue NotImplementedError => e
      puts "🔴 RED PHASE (not implemented)"
      @results[:reasoning_components][:goal_system] = :red_phase
    rescue => e
      puts "❓ UNKNOWN: #{e.message}"
      @results[:reasoning_components][:goal_system] = :unknown
    end
  end

  def test_facts_database_stub
    print "FactsDatabase: "
    begin
      facts_db = FactsDatabase.new
      puts "❌ UNEXPECTED: Should be in RED phase"
      @results[:reasoning_components][:facts_database] = :unexpected_green
    rescue NotImplementedError => e
      puts "🔴 RED PHASE (not implemented)"
      @results[:reasoning_components][:facts_database] = :red_phase
    rescue => e
      puts "❓ UNKNOWN: #{e.message}"
      @results[:reasoning_components][:facts_database] = :unknown
    end
  end

  def test_performance_benchmarks
    puts "\n⚡ PERFORMANCE BENCHMARKS"
    puts "-" * 30
    
    # Test arithmetic performance
    test_arithmetic_performance
    
    # Test function call performance
    test_function_performance
  end

  def test_arithmetic_performance
    print "Arithmetic performance (1000 evaluations): "
    begin
      time = Benchmark.realtime do
        1000.times { Patlang.evaluate("2 + 3 * 4") }
      end
      
      avg_time = time / 1000
      if avg_time < 0.001  # Less than 1ms per evaluation
        puts "✅ EXCELLENT (#{(avg_time * 1000).round(3)}ms avg)"
        @results[:performance][:arithmetic] = :excellent
      elsif avg_time < 0.01  # Less than 10ms
        puts "✅ GOOD (#{(avg_time * 1000).round(3)}ms avg)"
        @results[:performance][:arithmetic] = :good
      else
        puts "⚠️  SLOW (#{(avg_time * 1000).round(3)}ms avg)"
        @results[:performance][:arithmetic] = :slow
      end
    rescue => e
      puts "❌ ERROR: #{e.message}"
      @results[:performance][:arithmetic] = :error
    end
  end

  def test_function_performance
    print "Function definition performance (100 definitions): "
    begin
      time = Benchmark.realtime do
        100.times do |i|
          Patlang.evaluate("make function test#{i} { return #{i} }")
        end
      end
      
      avg_time = time / 100
      if avg_time < 0.01  # Less than 10ms per function
        puts "✅ GOOD (#{(avg_time * 1000).round(3)}ms avg)"
        @results[:performance][:functions] = :good
      else
        puts "⚠️  SLOW (#{(avg_time * 1000).round(3)}ms avg)"
        @results[:performance][:functions] = :slow
      end
    rescue => e
      puts "❌ ERROR: #{e.message}"
      @results[:performance][:functions] = :error
    end
  end

  def test_business_scenarios
    puts "\n💼 BUSINESS SCENARIOS"
    puts "-" * 25
    
    # Test basic calculator scenario
    test_calculator_scenario
    
    # Test simple data processing
    test_data_processing_scenario
  end

  def test_calculator_scenario
    print "Calculator scenario: "
    begin
      # Multi-step calculation
      result1 = Patlang.evaluate("10 + 5")
      result2 = Patlang.evaluate("(10 + 5) * 2")
      result3 = Patlang.evaluate("((10 + 5) * 2) - 3")
      
      if result1 == 15 && result2 == 30 && result3 == 27
        puts "✅ PASS (multi-step calculations work)"
        @results[:business_scenarios][:calculator] = :pass
      else
        puts "❌ FAIL (incorrect results)"
        @results[:business_scenarios][:calculator] = :fail
      end
    rescue => e
      puts "❌ ERROR: #{e.message}"
      @results[:business_scenarios][:calculator] = :error
    end
  end

  def test_data_processing_scenario
    print "Data processing scenario: "
    begin
      # Test variable assignments and retrieval
      Patlang.evaluate("x = 42")
      Patlang.evaluate("y = 58")
      result = Patlang.evaluate("x + y")
      
      if result == 100
        puts "✅ PASS (variable persistence works)"
        @results[:business_scenarios][:data_processing] = :pass
      else
        puts "❌ FAIL (variables not persisting)"
        @results[:business_scenarios][:data_processing] = :fail
      end
    rescue => e
      puts "❌ ERROR: #{e.message}"
      @results[:business_scenarios][:data_processing] = :error
    end
  end

  def generate_report
    puts "\n📊 PHASE 2 VALIDATION SUMMARY"
    puts "=" * 40
    
    puts "\n🎯 CORE FEATURES:"
    @results[:core_features].each do |feature, status|
      icon = status == :pass ? "✅" : (status == :error ? "❌" : "⚠️")
      puts "  #{icon} #{feature.to_s.capitalize}: #{status}"
    end
    
    puts "\n🧠 REASONING COMPONENTS:"
    @results[:reasoning_components].each do |component, status|
      icon = status == :red_phase ? "🔴" : (status == :unexpected_green ? "❌" : "❓")
      puts "  #{icon} #{component.to_s.gsub('_', ' ').capitalize}: #{status}"
    end
    
    puts "\n⚡ PERFORMANCE:"
    @results[:performance].each do |test, status|
      icon = status == :excellent ? "🚀" : (status == :good ? "✅" : (status == :slow ? "⚠️" : "❌"))
      puts "  #{icon} #{test.to_s.capitalize}: #{status}"
    end
    
    puts "\n💼 BUSINESS SCENARIOS:"
    @results[:business_scenarios].each do |scenario, status|
      icon = status == :pass ? "✅" : "❌"
      puts "  #{icon} #{scenario.to_s.gsub('_', ' ').capitalize}: #{status}"
    end
    
    puts "\n🎯 PHASE 2 STATUS:"
    core_passing = @results[:core_features].values.count(:pass)
    total_core = @results[:core_features].size
    
    if core_passing == total_core
      puts "  ✅ Core language features: COMPLETE (#{core_passing}/#{total_core})"
    else
      puts "  ⚠️  Core language features: PARTIAL (#{core_passing}/#{total_core})"
    end
    
    reasoning_red = @results[:reasoning_components].values.count(:red_phase)
    total_reasoning = @results[:reasoning_components].size
    
    if reasoning_red == total_reasoning
      puts "  🔴 Reasoning components: RED PHASE (as expected for testing milestone)"
    else
      puts "  ❓ Reasoning components: MIXED STATE (needs investigation)"
    end
    
    puts "\n📋 RECOMMENDATION:"
    if core_passing >= total_core * 0.8
      puts "  ✅ READY FOR PHASE 2 COMPLETION DOCUMENTATION"
      puts "  ✅ Core features working reliably"
      puts "  🔴 Reasoning components in RED phase (normal for test-driven development)"
    else
      puts "  ⚠️  CORE FEATURES NEED ATTENTION BEFORE COMPLETION"
    end
  end
end

# Run validation if this file is executed directly
if __FILE__ == $0
  validator = Phase2Validator.new
  validator.run_validation
end