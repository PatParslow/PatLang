#!/usr/bin/env ruby

require 'minitest/autorun'
require 'timeout'

# Simple direct error analysis to find specific errors
class DirectErrorAnalysis
  def initialize
    @specific_errors = []
  end

  def run_analysis
    puts "🔍 DIRECT ERROR ANALYSIS FOR PHASE 1B"
    puts "="*60
    
    # Check for Priority 1: NoMethodError Issues
    puts "\n🎯 PRIORITY 1: NoMethodError Issues"
    check_cross_paradigm_coordination_error
    check_fire_event_error
    
    # Check for Priority 2: ArgumentError Issues  
    puts "\n🎯 PRIORITY 2: ArgumentError Issues"
    check_symbol_comparison_error
    check_invalid_term_type_error
    
    # Check for Priority 3: RuntimeError Issues
    puts "\n🎯 PRIORITY 3: RuntimeError Issues"
    check_string_evaluator_errors
    check_function_evaluator_errors
    
    puts "\n📊 SUMMARY:"
    puts "Total specific errors found: #{@specific_errors.length}"
    @specific_errors.each_with_index do |error, i|
      puts "#{i+1}. #{error}"
    end
  end

  private

  def check_cross_paradigm_coordination_error
    begin
      # Try to reproduce the '>=' for nil error
      require_relative 'src/reasoning/cross_paradigm_coordination'
      puts "✅ cross_paradigm_coordination.rb loads without immediate error"
    rescue => e
      puts "❌ cross_paradigm_coordination.rb error: #{e.class}: #{e.message}"
      @specific_errors << "cross_paradigm_coordination.rb:526 - #{e.message}"
    end
  end

  def check_fire_event_error
    begin
      require_relative 'src/reasoning/type_constraint_system'
      puts "✅ type_constraint_system.rb loads without immediate error"
    rescue => e
      puts "❌ type_constraint_system.rb error: #{e.class}: #{e.message}"
      @specific_errors << "type_constraint_system.rb - #{e.message}"
    end
  end

  def check_symbol_comparison_error
    begin
      require_relative 'src/reasoning/reasoning_integration'
      puts "✅ reasoning_integration.rb loads without immediate error"
    rescue => e
      puts "❌ reasoning_integration.rb error: #{e.class}: #{e.message}"
      @specific_errors << "reasoning_integration.rb:393 - #{e.message}"
    end
  end

  def check_invalid_term_type_error
    begin
      require_relative 'src/reasoning/unification_engine'
      puts "✅ unification_engine.rb loads without immediate error"
    rescue => e
      puts "❌ unification_engine.rb error: #{e.class}: #{e.message}"
      @specific_errors << "unification_engine.rb:208 - #{e.message}"
    end
  end

  def check_string_evaluator_errors
    begin
      require_relative 'src/evaluators/string_evaluator'
      puts "✅ string_evaluator.rb loads without immediate error"
    rescue => e
      puts "❌ string_evaluator.rb error: #{e.class}: #{e.message}"
      @specific_errors << "string_evaluator.rb - #{e.message}"
    end
  end

  def check_function_evaluator_errors
    begin
      require_relative 'src/evaluators/function_evaluator'
      puts "✅ function_evaluator.rb loads without immediate error"
    rescue => e
      puts "❌ function_evaluator.rb error: #{e.class}: #{e.message}"
      @specific_errors << "function_evaluator.rb - #{e.message}"
    end
  end
end

# Run the analysis
DirectErrorAnalysis.new.run_analysis