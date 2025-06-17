#!/usr/bin/env ruby
# Coverage Diagnostic Script - Investigate SimpleCov result object

require 'simplecov'
require 'json'

# Configure SimpleCov exactly like the test runner
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  add_filter '/adhoc_scripts/'
  add_filter '/tools/'
  
  track_files 'src/**/*.rb'
  
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
  
  minimum_coverage line: 80, branch: 70
end

# Load a few test files to generate coverage data
puts "🔍 Loading test files to generate coverage data..."

begin
  require_relative 'helpers/test_helper'
  require_relative 'infrastructure/test_lexer'
  puts "✅ Test files loaded"
rescue => e
  puts "⚠️  Error loading test files: #{e.message}"
end

# Examine SimpleCov result object
puts "\n📊 Examining SimpleCov result object..."

if defined?(SimpleCov)
  puts "✅ SimpleCov is defined"
  
  if SimpleCov.result
    result = SimpleCov.result
    puts "✅ SimpleCov.result is available"
    
    puts "\n🔍 SimpleCov Result Object Analysis:"
    puts "  Class: #{result.class}"
    puts "  Methods available: #{result.methods.grep(/coverage|percent|lines/).sort}"
    
    puts "\n📈 Coverage Data:"
    puts "  covered_percent: #{result.covered_percent}"
    puts "  total_lines: #{result.total_lines}" if result.respond_to?(:total_lines)
    puts "  covered_lines: #{result.covered_lines}" if result.respond_to?(:covered_lines)
    puts "  missed_lines: #{result.missed_lines}" if result.respond_to?(:missed_lines)
    
    # Branch coverage
    if result.respond_to?(:branch_coverage_percent)
      puts "  branch_coverage_percent: #{result.branch_coverage_percent}"
    else
      puts "  branch_coverage_percent: Method not available"
    end
    
    # Check if covered_percent returns 0 vs actual value
    puts "\n🔍 Detailed Coverage Calculation:"
    puts "  result.covered_percent: #{result.covered_percent}"
    puts "  result.covered_percent.class: #{result.covered_percent.class}"
    puts "  result.covered_percent.round(2): #{result.covered_percent.round(2)}"
    
    # Files analysis
    puts "\n📁 Files Analysis:"
    puts "  Files count: #{result.files.length}"
    result.files.each_with_index do |file, index|
      puts "  File #{index + 1}: #{file.filename}"
      puts "    Coverage: #{file.covered_percent}%"
      puts "    Lines: #{file.lines.count}" if file.respond_to?(:lines)
      break if index >= 2  # Just show first 3 files
    end
    
    # Raw data inspection
    puts "\n🔍 Raw Coverage Data Inspection:"
    if result.respond_to?(:original_result)
      puts "  Original result available: #{result.original_result.class}"
    end
    
    # Check if there's any difference in calculation
    manual_calculation = if result.total_lines > 0
      (result.covered_lines.to_f / result.total_lines.to_f * 100).round(2)
    else
      0.0
    end
    
    puts "  Manual calculation: #{manual_calculation}%"
    puts "  SimpleCov calculation: #{result.covered_percent}%"
    puts "  Match: #{manual_calculation == result.covered_percent}"
    
  else
    puts "❌ SimpleCov.result is nil"
  end
else
  puts "❌ SimpleCov is not defined"
end

puts "\n🏁 Coverage diagnostic complete"