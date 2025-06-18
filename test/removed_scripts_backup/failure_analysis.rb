#!/usr/bin/env ruby

require_relative 'test_helper'

# Failure analysis script to categorize and understand test failures
class FailureAnalyzer
  def self.analyze
    puts "🔍 SYSTEMATIC FAILURE ANALYSIS"
    puts "=" * 50
    
    # Run individual test files to identify patterns
    test_files = [
      'test_object_evaluation.rb',
      'test_object_model.rb', 
      'test_object_model_comprehensive.rb',
      'test_object_model_stress.rb'
    ]
    
    test_files.each do |file|
      puts "\n📂 Analyzing #{file}:"
      puts "-" * 30
      
      # Run the test file and capture output
      result = `ruby test/#{file} 2>&1`
      
      if result.include?("Failure:")
        failures = result.scan(/Failure:\s*([^:]+):([^:]+):\s*(.+?)(?=\n\n|\nFinished|\z)/m)
        
        failures.each do |test_class, test_method, error_msg|
          puts "❌ #{test_class}##{test_method.strip}"
          puts "   Error: #{error_msg.strip.split("\n").first}"
          
          # Categorize the failure
          if error_msg.include?("Expected: 42")
            puts "   Category: EVENT_SUBSCRIPTION_ISSUE"
          elsif error_msg.include?("Expected: :string") || error_msg.include?("Expected: :number")
            puts "   Category: TYPE_EXPECTATION_MISMATCH"
          elsif error_msg.include?("DEPRECATED")
            puts "   Category: MINITEST_COMPATIBILITY"
          elsif error_msg.include?("event")
            puts "   Category: EVENT_SYSTEM_ISSUE"
          else
            puts "   Category: OTHER"
          end
          puts
        end
      else
        puts "✅ No failures found"
      end
    end
    
    puts "\n🎯 RUNNING PATTERN DETECTION"
    puts "=" * 50
    
    # Check for common patterns in failing tests
    check_event_system_issues
    check_type_expectation_issues
    check_minitest_compatibility
  end
  
  def self.check_event_system_issues
    puts "\n🔥 Event System Analysis:"
    # Test basic event firing
    require_relative '../src/object_model/event_system'
    
    event_fired = false
    EventSystem.subscribe(:test_event) do |data|
      event_fired = true
    end
    
    EventSystem.fire_global_event(:test_event, { test: true })
    
    if event_fired
      puts "✅ Basic event system working"
    else
      puts "❌ Event system not firing events"
    end
  end
  
  def self.check_type_expectation_issues
    puts "\n🎯 Type Expectation Analysis:"
    require_relative '../patlang-core/evaluator/evaluator'
    
    evaluator = Evaluator.new
    
    # Test what type we actually get for "42"
    result = evaluator.evaluate("42")
    puts "   Evaluating '42' returns: #{result.inspect} (class: #{result.class})"
    
    # Test object mode
    evaluator.enable_object_mode
    result = evaluator.evaluate("42")
    puts "   Object mode '42' returns: #{result.inspect} (class: #{result.class})"
    
    if result.respond_to?(:type)
      puts "   Object type: #{result.type}"
    end
  end
  
  def self.check_minitest_compatibility
    puts "\n⚠️  MiniTest Compatibility:"
    puts "   Fixed: assert_equal nil -> assert_nil"
    puts "   Need to check for other deprecation patterns"
  end
end

if __FILE__ == $0
  FailureAnalyzer.analyze
end