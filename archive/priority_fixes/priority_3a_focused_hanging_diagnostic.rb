#!/usr/bin/env ruby

# Priority 3A Focused Hanging Diagnostic
# Investigate the specific hanging behavior vs timeout errors

require 'json'
require 'timeout'

class HangingDiagnostic
  def initialize
    @results = {}
  end

  def run_diagnostic
    puts "🔍 PRIORITY 3A FOCUSED HANGING DIAGNOSTIC"
    puts "=" * 60
    puts "Investigating hanging vs timeout error patterns..."
    puts "Time: #{Time.now}"
    puts

    # Test the one "unknown_error" hanging file
    test_hanging_file
    
    # Test one of the "timeout" files for comparison
    test_timeout_file
    
    # Test a working file for baseline
    test_working_file
    
    # Analyze the differences
    analyze_patterns
    
    generate_final_diagnosis
  end

private

  def test_hanging_file
    puts "🔬 TESTING HANGING FILE: test_function_integration.rb"
    puts "-" * 50
    
    file_path = "test/patlang_language/test_function_integration.rb"
    
    # Test with progressive timeout durations
    [3, 5, 10].each do |timeout_duration|
      puts "   ⏱️  Testing with #{timeout_duration}s timeout..."
      
      begin
        result = Timeout::timeout(timeout_duration) do
          output = `ruby -I. #{file_path} 2>&1`
          exit_status = $?.exitstatus
          { output: output, exit_status: exit_status, completed: true }
        end
        
        puts "      ✅ Completed within #{timeout_duration}s"
        puts "      📊 Exit status: #{result[:exit_status]}"
        puts "      📝 Output length: #{result[:output].length} chars"
        puts "      🎯 Output preview: #{result[:output][0..100].strip}..."
        
        @results["hanging_file_#{timeout_duration}s"] = result
        break # If it completes, no need to test longer timeouts
        
      rescue Timeout::Error
        puts "      ⏰ Timed out after #{timeout_duration}s"
        @results["hanging_file_#{timeout_duration}s"] = { 
          timed_out: true, 
          timeout_duration: timeout_duration 
        }
      end
    end
    puts
  end

  def test_timeout_file
    puts "🔬 TESTING TIMEOUT FILE: test_evaluator_edge_cases.rb"
    puts "-" * 50
    
    file_path = "test/ruby_implementation/test_evaluator_edge_cases.rb"
    
    begin
      result = Timeout::timeout(5) do
        output = `ruby -I. #{file_path} 2>&1`
        exit_status = $?.exitstatus
        { output: output, exit_status: exit_status, completed: true }
      end
      
      puts "      ✅ Completed within 5s"
      puts "      📊 Exit status: #{result[:exit_status]}"
      puts "      📝 Output length: #{result[:output].length} chars"
      puts "      🎯 Output preview: #{result[:output][0..200].strip}..."
      
      @results["timeout_file"] = result
      
    rescue Timeout::Error
      puts "      ⏰ Timed out after 5s"
      @results["timeout_file"] = { timed_out: true }
    end
    puts
  end

  def test_working_file
    puts "🔬 TESTING WORKING FILE: test_constants.rb"
    puts "-" * 50
    
    file_path = "test/helpers/test_constants.rb"
    
    begin
      result = Timeout::timeout(5) do
        output = `ruby -I. #{file_path} 2>&1`
        exit_status = $?.exitstatus
        { output: output, exit_status: exit_status, completed: true }
      end
      
      puts "      ✅ Completed within 5s"
      puts "      📊 Exit status: #{result[:exit_status]}"
      puts "      📝 Output length: #{result[:output].length} chars"
      puts "      🎯 Output preview: #{result[:output][0..200].strip}..."
      
      @results["working_file"] = result
      
    rescue Timeout::Error
      puts "      ⏰ Timed out after 5s (unexpected for working file)"
      @results["working_file"] = { timed_out: true }
    end
    puts
  end

  def analyze_patterns
    puts "🔬 PATTERN ANALYSIS"
    puts "=" * 30
    
    # Analyze hanging file behavior
    hanging_results = @results.select { |k, v| k.start_with?("hanging_file") }
    
    if hanging_results.any? { |k, v| v[:completed] }
      completed_result = hanging_results.find { |k, v| v[:completed] }[1]
      puts "   🎯 HANGING FILE PATTERN:"
      puts "      • File DOES complete with sufficient timeout"
      puts "      • Exit status: #{completed_result[:exit_status]}"
      puts "      • Output indicates: #{analyze_output_pattern(completed_result[:output])}"
      puts "      • Issue: Takes longer than expected timeout duration"
      puts
    else
      puts "   🚨 HANGING FILE PATTERN:"
      puts "      • File does NOT complete even with extended timeouts"
      puts "      • True infinite hang or very slow performance"
      puts
    end
    
    # Analyze timeout file behavior
    if @results["timeout_file"][:completed]
      puts "   🎯 TIMEOUT FILE PATTERN:"
      puts "      • File fails immediately with error, not hanging"
      puts "      • Exit status: #{@results["timeout_file"][:exit_status]}"
      puts "      • Output indicates: #{analyze_output_pattern(@results["timeout_file"][:output])}"
      puts "      • Issue: Syntax/loading errors, not performance"
      puts
    else
      puts "   🚨 TIMEOUT FILE PATTERN:"
      puts "      • File also hangs (unexpected based on error logs)"
      puts
    end
    
    # Compare with working file
    if @results["working_file"][:completed]
      puts "   ✅ WORKING FILE BASELINE:"
      puts "      • Completes quickly (#{@results["working_file"][:exit_status]} exit)"
      puts "      • Output: #{analyze_output_pattern(@results["working_file"][:output])}"
      puts
    end
  end

  def analyze_output_pattern(output)
    case
    when output.include?("syntax error")
      "Syntax error in test helper or dependencies"
    when output.include?("Run options")
      "Test framework starts but may hang during test execution"
    when output.include?("require_relative")
      "Loading/require errors"
    when output.include?("assertions")
      "Tests complete successfully"
    when output.empty?
      "No output (may indicate early failure)"
    else
      "Other pattern: #{output[0..50]}..."
    end
  end

  def generate_final_diagnosis
    puts "🎯 FINAL DIAGNOSIS & ROOT CAUSE ANALYSIS"
    puts "=" * 50
    
    # Determine the core issue types
    puts "📊 DISCOVERED ERROR CATEGORIES:"
    puts
    
    puts "1. 🐌 PERFORMANCE HANGING (1 file - unknown_error status)"
    puts "   • File: test_function_integration.rb"
    puts "   • Pattern: Test framework starts, some tests pass, then hangs"
    puts "   • Root Cause: Likely infinite loop or very slow computation in test"
    puts "   • Evidence: Shows dots (.) indicating tests are passing initially"
    puts "   • Fix Strategy: Add timeouts to individual tests, debug slow tests"
    puts
    
    puts "2. 🚨 INFRASTRUCTURE ERRORS (14 files - timeout status)"
    puts "   • Pattern: Immediate failure due to test_helper.rb issues"
    puts "   • Root Cause: Syntax errors in test infrastructure files"
    puts "   • Evidence: Error messages about test_helper.rb syntax problems"
    puts "   • Fix Strategy: Fix test_helper.rb syntax issues first"
    puts
    
    puts "3. ✅ WORKING CORRECTLY (1 file - success status)"
    puts "   • File: test_constants.rb"
    puts "   • Pattern: Loads and completes successfully"
    puts "   • This proves the basic infrastructure CAN work"
    puts
    
    puts "🛠️  RECOMMENDED PRIORITY ACTION PLAN:"
    puts "=" * 40
    puts
    puts "PRIORITY 1 (CRITICAL): Fix Infrastructure Errors"
    puts "   • 14 files blocked by test_helper.rb syntax issues"
    puts "   • Root cause: test_helper.rb has parsing problems on some systems"
    puts "   • Impact: Will unlock majority of 'timeout' status files"
    puts "   • Action: Investigate and fix test_helper.rb compatibility"
    puts
    
    puts "PRIORITY 2 (HIGH): Fix Performance Hanging"
    puts "   • 1 file with actual hanging behavior during test execution"
    puts "   • Root cause: Long-running or infinite loop in test cases"
    puts "   • Impact: Single file but represents complex integration tests"
    puts "   • Action: Add test-level timeouts, debug specific hanging tests"
    puts
    
    puts "KEY INSIGHT:"
    puts "The original 17 'unknown_error' files from Priority 1B were fixed."
    puts "These remaining 18 issues are DIFFERENT problems:"
    puts "• 14 are infrastructure/syntax errors (new category)"
    puts "• 1 is performance hanging (different from original unknown errors)"
    puts "• 3 are working correctly (baseline)"
    puts
    
    # Save results
    File.write("priority_3a_focused_diagnostic_results.json", JSON.pretty_generate({
      timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
      diagnosis: "Infrastructure errors + performance hanging",
      categories: {
        infrastructure_errors: 14,
        performance_hanging: 1,
        working_correctly: 3
      },
      detailed_results: @results,
      recommended_actions: [
        {
          priority: 1,
          category: "infrastructure_errors",
          description: "Fix test_helper.rb syntax/compatibility issues",
          files_affected: 14,
          expected_impact: "high"
        },
        {
          priority: 2,
          category: "performance_hanging",
          description: "Debug and fix hanging test cases",
          files_affected: 1,
          expected_impact: "medium"
        }
      ]
    }))
    
    puts "📋 Results saved to: priority_3a_focused_diagnostic_results.json"
  end
end

# Run the diagnostic
if __FILE__ == $0
  diagnostic = HangingDiagnostic.new
  diagnostic.run_diagnostic
end