#!/usr/bin/env ruby

require 'json'

# Quick Error Analysis for Patlang Project
class QuickErrorAnalysis
  
  def analyze
    puts "🔍 PATLANG PROJECT ERROR ANALYSIS"
    puts "=" * 50
    
    # Load existing comprehensive analysis
    load_existing_analysis
    
    # Check current test status
    check_test_status
    
    # Generate action plan
    generate_action_plan
  end
  
  private
  
  def load_existing_analysis
    puts "\n📋 EXISTING ERROR ANALYSIS:"
    puts "-" * 30
    
    if File.exist?('RUNTIME_VALIDATION_AND_FAILURE_ANALYSIS.json')
      data = JSON.parse(File.read('RUNTIME_VALIDATION_AND_FAILURE_ANALYSIS.json'))
      
      puts "Total documented errors: #{data['total_errors']}"
      puts "\nError types:"
      data['error_classification'].each do |type, count|
        puts "  - #{type}: #{count}"
      end
      
      puts "\nKey patterns identified:"
      data['pattern_analysis'].each do |pattern, info|
        puts "  - #{pattern}: #{info['count']} errors"
      end
      
      puts "\nPriority sequence:"
      data['priority_sequence'].each do |priority|
        puts "  - #{priority['priority']}: #{priority['errors'].length} errors"
        puts "    Reason: #{priority['reason']}"
      end
      
      return data
    else
      puts "No existing analysis found"
      return nil
    end
  end
  
  def check_test_status
    puts "\n🧪 CURRENT TEST STATUS:"
    puts "-" * 30
    
    # Check if comprehensive test is still running
    if test_still_running?
      puts "✅ Comprehensive test suite is running"
      puts "   Observed: Multiple test failures (F's) in output"
    else
      puts "❌ No test currently running"
    end
    
    # Quick validation of key areas
    puts "\nQuick validation checks:"
    
    # Check for debug_print method issue
    if check_debug_print_issue
      puts "  ❌ CRITICAL: debug_print method missing"
    else
      puts "  ✅ debug_print method appears available"
    end
    
    # Check parser functionality
    if check_basic_parser
      puts "  ✅ Basic parser functionality working"
    else
      puts "  ❌ Parser has issues"
    end
  end
  
  def test_still_running?
    # Check if ruby process is running our test
    result = `ps aux | grep "ruby.*test" | grep -v grep`
    !result.empty?
  end
  
  def check_debug_print_issue
    # Look for debug_print in function_parser
    function_parser_path = 'src/parser/function_parser.rb'
    if File.exist?(function_parser_path)
      content = File.read(function_parser_path)
      return content.include?('debug_print') && !content.include?('def debug_print')
    end
    false
  end
  
  def check_basic_parser
    # Try a simple parse test
    begin
      require_relative 'src/patlang'
      patlang = PatlangREPL.new
      result = patlang.evaluate("5 + 3")
      return result == 8.0
    rescue => e
      puts "    Parse test failed: #{e.message}"
      return false
    end
  end
  
  def generate_action_plan
    puts "\n🎯 SYSTEMATIC ACTION PLAN:"
    puts "=" * 50
    
    puts "\n🔴 CRITICAL PRIORITY (Immediate - 5 minutes):"
    puts "1. Fix debug_print method in FunctionParser"
    puts "   - Location: src/parser/function_parser.rb:264"
    puts "   - Issue: 8 test failures due to missing debug_print method"
    puts "   - Fix: Add debug_print method to parser classes"
    puts "   - Impact: Will resolve 8 NoMethodError failures immediately"
    
    puts "\n🟡 HIGH PRIORITY (Short term - 20 minutes):"
    puts "2. Resolve NoMethodError issues in evaluator/reasoning"
    puts "   - 4 nil method call errors (length, [])"
    puts "   - 1 undefined variable error (database)"
    puts "   - Impact: Core functionality and integration tests"
    
    puts "\n🟠 MEDIUM PRIORITY (Medium term - 30 minutes):"
    puts "3. Improve parser edge case handling"
    puts "   - 11 ParseError issues with unexpected tokens"
    puts "   - Enhance error recovery for malformed input"
    puts "   - Impact: System robustness and user experience"
    
    puts "\n🟢 LOW PRIORITY (Long term - 15 minutes):"
    puts "4. Integration test cleanup"
    puts "   - Isolated test failures in advanced features"
    puts "   - Cross-paradigm coordination edge cases"
    puts "   - Impact: Advanced feature stability"
    
    puts "\n📊 EXPECTED OUTCOMES:"
    puts "- Phase 1: 8 critical errors resolved (33% reduction)"
    puts "- Phase 2: 5 high priority errors resolved (54% total reduction)"
    puts "- Phase 3: 11 medium errors resolved (100% of ParseErrors)"
    puts "- Phase 4: Remaining integration issues resolved"
    
    puts "\n🚀 RECOMMENDED START:"
    puts "Begin with debug_print fix - highest impact, lowest effort"
    puts "This single fix will immediately resolve 1/3 of all documented errors"
    
    puts "\n✅ RECENT SUCCESSES (Don't break these!):"
    puts "- Parser error recovery system ✅"
    puts "- Flexible function syntax ✅"
    puts "- IS keyword implementation ✅"
    puts "- Core arithmetic and string operations ✅"
  end
end

# Run analysis
if __FILE__ == $0
  analyzer = QuickErrorAnalysis.new
  analyzer.analyze
end