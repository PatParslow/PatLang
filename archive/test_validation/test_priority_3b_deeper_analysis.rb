#!/usr/bin/env ruby

# Priority 3B-3 Deeper Analysis - Looking for actual failing tests

require 'open3'

class Priority3BDeeperAnalysis
  def initialize
    @test_results = []
    @failure_patterns = Hash.new(0)
  end

  def find_failing_tests
    puts "🔍 Priority 3B-3: Deeper Analysis of Actual Test Failures"
    puts "=" * 60
    
    # Test areas more likely to have failures based on complexity
    complex_test_areas = [
      { name: "Reasoning Integration", files: ["test/patlang_language/test_reasoning_integration.rb"] },
      { name: "Cross Paradigm", files: ["test/patlang_language/test_cross_paradigm_coordination.rb"] },
      { name: "Function Integration", files: ["test/patlang_language/test_function_integration.rb"] },
      { name: "Advanced Goal Strategies", files: ["test/ruby_implementation/test_advanced_goal_strategies.rb"] },
      { name: "Object Model Comprehensive", files: ["test/ruby_implementation/test_object_model_comprehensive.rb"] },
      { name: "Type Constraint System", files: ["test/infrastructure/test_type_constraint_system.rb"] },
      { name: "Goal Resolution Engine", files: ["test/infrastructure/test_goal_resolution_engine.rb"] },
      { name: "Unification Engine", files: ["test/infrastructure/test_unification_engine.rb"] }
    ]
    
    complex_test_areas.each do |area|
      puts "\n🔍 Testing #{area[:name]}..."
      area[:files].each do |file|
        if File.exist?(file)
          result = run_test_detailed(file)
          analyze_detailed_failures(result, area[:name])
        else
          puts "   ⚠️  File not found: #{file}"
        end
      end
    end
    
    # Also test some files from root that might have issues
    puts "\n🔍 Testing Root Test Files..."
    root_tests = Dir.glob("test_*.rb").sort
    root_tests.first(5).each do |file|  # Test first 5 to avoid timeout
      puts "\n🔍 Testing #{file}..."
      result = run_test_detailed(file)
      analyze_detailed_failures(result, "Root Tests")
    end
    
    identify_priority_3b_targets
  end

  private

  def run_test_detailed(file)
    puts "   Running: #{file}"
    cmd = "ruby -I. -Itest -Isrc #{file}"
    
    begin
      stdout, stderr, status = Open3.capture3(cmd, timeout: 15)  # Shorter timeout
      
      {
        file: file,
        stdout: stdout,
        stderr: stderr,
        success: status.success?,
        combined: "#{stdout}\n#{stderr}"
      }
    rescue Timeout::Error
      puts "   ⏰ Timeout - test may hang"
      {
        file: file,
        stdout: "",
        stderr: "Test execution timeout",
        success: false,
        combined: "Test execution timeout"
      }
    rescue => e
      puts "   ❌ Error: #{e.message}"
      {
        file: file,
        stdout: "",
        stderr: e.message,
        success: false,
        combined: e.message
      }
    end
  end

  def analyze_detailed_failures(result, area_name)
    output = result[:combined]
    
    # Extract test counts first
    if output =~ /(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/
      runs, assertions, failures, errors = $1.to_i, $2.to_i, $3.to_i, $4.to_i
      total_failures = failures + errors
      
      puts "   📊 #{runs} tests: #{runs - total_failures} passed, #{total_failures} failed"
      
      if total_failures > 0
        @test_results << {
          area: area_name,
          file: result[:file],
          total: runs,
          passed: runs - total_failures,
          failed: total_failures,
          failure_rate: (total_failures.to_f / runs * 100).round(1)
        }
        
        # This has failures - extract specific patterns
        extract_failure_patterns(output, area_name, total_failures)
      end
    else
      # No test count - check for load/execution errors
      if !result[:success] && !output.include?("Test execution timeout")
        puts "   ❌ Execution error detected"
        extract_execution_error_patterns(output, area_name)
      end
    end
  end

  def extract_failure_patterns(output, area_name, failure_count)
    # Look for specific error types that are quick wins
    patterns = [
      { name: "NotImplementedError", regex: /NotImplementedError: (.+)/, effort: 4 },
      { name: "NoMethodError", regex: /NoMethodError: (.+)/, effort: 2 },
      { name: "NameError", regex: /NameError: (.+)/, effort: 2 },
      { name: "ArgumentError", regex: /ArgumentError: (.+)/, effort: 1 },
      { name: "LoadError", regex: /LoadError: (.+)/, effort: 1 },
      { name: "ParseError", regex: /ParseError: (.+)/, effort: 3 },
      { name: "TypeError", regex: /TypeError: (.+)/, effort: 2 },
      { name: "assert_raises mismatch", regex: /Expected (.+) to be raised/, effort: 1 }
    ]
    
    patterns.each do |pattern|
      matches = output.scan(pattern[:regex])
      if matches.length > 0
        pattern_key = "#{area_name}: #{pattern[:name]}"
        @failure_patterns[pattern_key] += matches.length
        puts "   🔴 #{pattern[:name]}: #{matches.length} occurrences"
        
        # Show specific examples for quick wins (effort <= 2)
        if pattern[:effort] <= 2 && matches.length <= 3
          matches.each { |match| puts "      • #{match.first}" }
        end
      end
    end
  end

  def extract_execution_error_patterns(output, area_name)
    # Look for load/require errors that prevent test execution
    if output.include?("LoadError")
      @failure_patterns["#{area_name}: LoadError"] += 1
      puts "   🔴 LoadError preventing test execution"
    elsif output.include?("uninitialized constant")
      @failure_patterns["#{area_name}: Uninitialized constant"] += 1
      puts "   🔴 Uninitialized constant error"
    elsif output.include?("undefined method")
      @failure_patterns["#{area_name}: Undefined method"] += 1
      puts "   🔴 Undefined method error"
    end
  end

  def identify_priority_3b_targets
    puts "\n🎯 PRIORITY 3B-3 TARGET IDENTIFICATION"
    puts "=" * 50
    
    if @failure_patterns.empty?
      puts "✅ All tested areas appear to be working!"
      puts "   This suggests previous Priority 3B fixes were very effective."
      puts "   Consider testing edge case scenarios or advanced features."
      return
    end
    
    # Calculate impact scores (failures / estimated effort)
    scored_patterns = @failure_patterns.map do |pattern, count|
      effort = estimate_effort(pattern)
      impact_score = count.to_f / effort
      
      {
        pattern: pattern,
        count: count,
        effort: effort,
        impact_score: impact_score,
        fix_type: get_fix_type(pattern)
      }
    end
    
    # Sort by impact score (highest first)
    scored_patterns.sort_by! { |p| -p[:impact_score] }
    
    puts "\n🏆 TOP PRIORITY 3B TARGETS (by Impact/Effort ratio):"
    scored_patterns.first(3).each_with_index do |target, index|
      puts "\n#{index + 1}. #{target[:pattern]}"
      puts "   Failures: #{target[:count]}"
      puts "   Effort: #{target[:effort]}/5"
      puts "   Impact Score: #{target[:impact_score].round(2)}"
      puts "   Fix: #{target[:fix_type]}"
    end
    
    if scored_patterns.any?
      # Select the highest impact target
      selected = scored_patterns.first
      
      puts "\n🎯 SELECTED PRIORITY 3B-3 TARGET:"
      puts "=" * 40
      puts "Target: #{selected[:pattern]}"
      puts "Expected Impact: #{selected[:count]} test fixes"
      puts "Implementation Effort: #{selected[:effort]}/5"
      puts "Quick Win Potential: #{selected[:effort] <= 2 ? 'HIGH' : 'MEDIUM'}"
      puts "Action: #{selected[:fix_type]}"
      
      puts "\n📈 Expected Pass Rate Improvement: #{estimate_improvement(selected[:count])}%"
    end
  end

  def estimate_effort(pattern)
    case pattern.downcase
    when /argumenterror/
      1  # Usually method signature fixes
    when /loaderror/
      1  # Require statement fixes
    when /assert_raises/
      1  # Test expectation fixes
    when /nomethoderror/
      2  # Method implementation needed
    when /nameerror/
      2  # Variable/constant definition
    when /typeerror/
      2  # Type handling fixes
    when /parseerror/
      3  # Parser grammar changes
    when /notimplementederror/
      4  # Feature implementation needed
    else
      3  # Default medium effort
    end
  end

  def get_fix_type(pattern)
    case pattern.downcase
    when /argumenterror/
      "Fix method signatures/parameter handling"
    when /loaderror/
      "Fix require statements and file paths"
    when /assert_raises/
      "Update test expectations to match implementation"
    when /nomethoderror/
      "Implement missing methods"
    when /nameerror/
      "Fix variable/constant definitions"
    when /typeerror/
      "Improve type checking and conversion"
    when /parseerror/
      "Fix parser grammar rules"
    when /notimplementederror/
      "Implement missing features"
    else
      "Investigate and fix specific issue"
    end
  end

  def estimate_improvement(failure_count)
    # Rough estimate based on typical test suite size
    estimated_total_tests = 200  # Conservative estimate
    (failure_count.to_f / estimated_total_tests * 100).round(1)
  end
end

# Run the analysis
if __FILE__ == $0
  analyzer = Priority3BDeeperAnalysis.new
  analyzer.find_failing_tests
end