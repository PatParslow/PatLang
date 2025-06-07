#!/usr/bin/env ruby

require 'json'

puts "🔍 PHASE 3: ANALYZING REMAINING 59 ERRORS"
puts "=" * 60

# Run comprehensive test suite to capture current error state
puts "\n📊 Running comprehensive test analysis..."

# Capture test output
test_output = `ruby test/run_all_tests.rb 2>&1`

# Parse errors vs failures
error_lines = test_output.split("\n").select { |line| 
  line.match?(/^\s*\d+\)\s+Error:/) || 
  line.match?(/Error:/) ||
  line.match?(/NotImplementedError/) ||
  line.match?(/undefined method/) ||
  line.match?(/uninitialized constant/) ||
  line.match?(/NoMethodError/) ||
  line.match?(/NameError/)
}

failure_lines = test_output.split("\n").select { |line| 
  line.match?(/^\s*\d+\)\s+Failure:/) ||
  line.match?(/Failure:/)
}

puts "Found #{error_lines.length} error-related lines"
puts "Found #{failure_lines.length} failure-related lines"

# Categorize errors by type
error_categories = {
  "NotImplementedError" => [],
  "NameError/Undefined" => [],
  "NoMethodError" => [],
  "SyntaxError" => [],
  "ArgumentError" => [],
  "Other" => []
}

# Parse each error line
error_lines.each do |line|
  case line
  when /NotImplementedError/
    error_categories["NotImplementedError"] << line
  when /undefined method|NoMethodError/
    error_categories["NoMethodError"] << line
  when /uninitialized constant|NameError/
    error_categories["NameError/Undefined"] << line
  when /SyntaxError/
    error_categories["SyntaxError"] << line
  when /ArgumentError/
    error_categories["ArgumentError"] << line
  else
    error_categories["Other"] << line
  end
end

puts "\n🏷️  ERROR CATEGORIZATION:"
puts "-" * 40

error_categories.each do |category, errors|
  if errors.any?
    puts "#{category}: #{errors.length} errors"
    errors.first(3).each do |error|
      puts "  • #{error.strip}"
    end
    puts "  ..." if errors.length > 3
    puts
  end
end

# Look for specific patterns mentioned in the task
puts "\n🎯 SPECIFIC PATTERN ANALYSIS:"
puts "-" * 40

# Reasoning Integration Issues
reasoning_errors = test_output.scan(/.*postcondition.*|.*goal parsing.*|.*facts database.*|.*rule definition.*/i)
puts "Reasoning Integration Issues: #{reasoning_errors.length}"
reasoning_errors.first(5).each { |error| puts "  • #{error.strip}" }

# Cross-Paradigm Coordination
coordination_errors = test_output.scan(/.*event.*integration.*|.*constraint satisfaction.*|.*cross.*paradigm.*/i)
puts "\nCross-Paradigm Coordination: #{coordination_errors.length}"
coordination_errors.first(5).each { |error| puts "  • #{error.strip}" }

# Object Model Issues
object_errors = test_output.scan(/.*Object.*undefined.*|.*object.*integration.*|.*Object class.*/i)
puts "\nObject Model Issues: #{object_errors.length}"
object_errors.first(5).each { |error| puts "  • #{error.strip}" }

# Advanced Features NotImplementedError
advanced_errors = test_output.scan(/.*NotImplementedError.*advanced.*|.*NotImplementedError.*performance.*|.*NotImplementedError.*enterprise.*/i)
puts "\nAdvanced Features NotImplementedError: #{advanced_errors.length}"
advanced_errors.first(5).each { |error| puts "  • #{error.strip}" }

# Look for specific file locations with high error density
puts "\n📁 ERROR HOTSPOTS BY FILE:"
puts "-" * 40

file_error_counts = {}
test_output.scan(/in `.*?' \(([^)]+)\)/).each do |match|
  file = match[0]
  file_error_counts[file] = (file_error_counts[file] || 0) + 1
end

file_error_counts.sort_by { |k, v| -v }.first(10).each do |file, count|
  puts "#{file}: #{count} errors" if count > 1
end

# Identify specific NotImplementedError stubs that could be implemented
puts "\n🚧 NOTIMPLEMENTEDERROR IMPLEMENTATION CANDIDATES:"
puts "-" * 50

not_implemented_lines = test_output.split("\n").select { |line| 
  line.match?(/NotImplementedError/) 
}

# Group by likely implementation complexity
easy_stubs = []
medium_stubs = []
hard_stubs = []

not_implemented_lines.each do |line|
  case line
  when /basic|simple|trivial/i
    easy_stubs << line
  when /advanced|enterprise|ml|machine|learning|performance|optimization/i
    hard_stubs << line
  else
    medium_stubs << line
  end
end

puts "Easy Implementation Candidates: #{easy_stubs.length}"
easy_stubs.first(3).each { |stub| puts "  • #{stub.strip}" }

puts "\nMedium Implementation Candidates: #{medium_stubs.length}"
medium_stubs.first(3).each { |stub| puts "  • #{stub.strip}" }

puts "\nHard Implementation Candidates: #{hard_stubs.length}"
hard_stubs.first(3).each { |stub| puts "  • #{stub.strip}" }

# Get final count verification
puts "\n🔢 CURRENT STATE VERIFICATION:"
puts "-" * 40

final_summary = test_output.split("\n").last(5).join("\n")
puts final_summary

puts "\n✅ Phase 3 Error Analysis Complete"
puts "📋 Use this data to prioritize the 59 remaining errors"