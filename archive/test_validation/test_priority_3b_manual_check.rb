#!/usr/bin/env ruby

# Manual Priority 3B-3 Target Identification - Simple approach without timeout

require 'open3'

puts "🎯 Priority 3B-3: Manual Target Identification"
puts "=" * 50
puts "Previous: 3B-1 (goal keyword), 3B-2 (postcondition syntax)"
puts

# Let's manually test a few key files to find failures
key_test_files = [
  "test/patlang_language/test_reasoning_integration.rb",
  "test/ruby_implementation/test_object_model_comprehensive.rb", 
  "test/infrastructure/test_unification_engine.rb"
]

failures_found = {}

key_test_files.each do |file|
  if File.exist?(file)
    puts "🔍 Testing #{file}..."
    
    # Simple test execution without timeout
    cmd = "ruby -I. -Itest -Isrc #{file}"
    stdout, stderr, status = Open3.capture3(cmd)
    
    combined_output = "#{stdout}\n#{stderr}"
    
    if status.success?
      # Extract pass/fail counts
      if combined_output =~ /(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/
        runs, assertions, failures, errors = $1.to_i, $2.to_i, $3.to_i, $4.to_i
        total_failures = failures + errors
        puts "   ✅ #{runs} tests: #{runs - total_failures} passed, #{total_failures} failed"
        
        if total_failures > 0
          failures_found[file] = {
            total: runs,
            failed: total_failures,
            output: combined_output
          }
        end
      else
        puts "   ✅ Tests passed (no count detected)"
      end
    else
      puts "   ❌ Execution failed"
      failures_found[file] = {
        total: 0,
        failed: 1,
        output: combined_output,
        execution_error: true
      }
    end
  else
    puts "   ⚠️  File not found: #{file}"
  end
end

# Test some root-level diagnostic files
puts "\n🔍 Testing root diagnostic files..."
root_files = Dir.glob("test_*.rb").select { |f| 
  f.include?("priority") || f.include?("validation") || f.include?("error")
}.first(3)

root_files.each do |file|
  next if file.include?("priority_3b")  # Skip our analysis files
  
  puts "🔍 Testing #{file}..."
  cmd = "ruby -I. -Itest -Isrc #{file}"
  stdout, stderr, status = Open3.capture3(cmd)
  
  combined_output = "#{stdout}\n#{stderr}"
  
  if !status.success?
    puts "   ❌ Execution failed"
    failures_found[file] = {
      total: 0,
      failed: 1,
      output: combined_output,
      execution_error: true
    }
  else
    puts "   ✅ Executed successfully"
  end
end

# Analyze findings
puts "\n🎯 ANALYSIS RESULTS"
puts "=" * 30

if failures_found.empty?
  puts "✅ No failures found in tested files!"
  puts "   This suggests most core functionality is working."
  puts "   Recommendation: Focus on edge cases or advanced features."
else
  puts "❌ Found #{failures_found.length} files with issues:"
  
  failures_found.each do |file, info|
    puts "\n📁 #{file}"
    if info[:execution_error]
      puts "   Type: Execution Error"
      puts "   Issue: Cannot run test file"
      
      # Extract specific error patterns
      output = info[:output]
      if output.include?("LoadError")
        puts "   Pattern: LoadError - missing dependencies"
        puts "   Quick Fix: Add missing require statements"
        puts "   Effort: 1/5 (Very Low)"
        puts "   Impact: High (enables test execution)"
      elsif output.include?("uninitialized constant")
        puts "   Pattern: Uninitialized constant"
        puts "   Quick Fix: Define missing constants/classes"
        puts "   Effort: 2/5 (Low)"
        puts "   Impact: High (enables test execution)"
      elsif output.include?("undefined method")
        puts "   Pattern: Undefined method"
        puts "   Quick Fix: Implement missing methods"
        puts "   Effort: 2/5 (Low)"
        puts "   Impact: Medium"
      end
    else
      puts "   Type: Test Failures"
      puts "   Failed: #{info[:failed]}/#{info[:total]} tests"
      puts "   Impact: #{info[:failed]} potential fixes"
    end
  end
  
  # Recommend the best target
  puts "\n🏆 PRIORITY 3B-3 RECOMMENDATION"
  puts "=" * 35
  
  # Find highest impact/lowest effort
  best_target = failures_found.max_by do |file, info|
    if info[:execution_error]
      # Execution errors are quick wins
      output = info[:output]
      if output.include?("LoadError")
        10  # Highest priority - very easy fix
      elsif output.include?("uninitialized constant")
        8   # High priority - easy fix
      elsif output.include?("undefined method")
        6   # Medium priority - medium fix
      else
        4   # Lower priority - unknown effort
      end
    else
      # Test failures - score by number of failures
      info[:failed]
    end
  end
  
  if best_target
    file, info = best_target
    puts "Selected Target: #{file}"
    
    if info[:execution_error]
      puts "Issue Type: Execution Error (Quick Win!)"
      puts "Expected Impact: Enable entire test file"
      puts "Implementation: Fix dependency/loading issues"
      puts "Estimated Effort: 1-2/5"
      puts "Pass Rate Impact: 2-5%"
    else
      puts "Issue Type: Test Failures"
      puts "Expected Impact: #{info[:failed]} test fixes"
      puts "Implementation: Fix specific test assertions"
      puts "Estimated Effort: 2-3/5"
      puts "Pass Rate Impact: 1-3%"
    end
    
    # Show specific error details for implementation
    puts "\n📋 Implementation Guide:"
    output_lines = info[:output].split("\n").first(10)
    output_lines.each { |line| puts "   #{line}" if line.strip.length > 0 }
  end
end