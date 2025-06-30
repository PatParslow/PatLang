#!/usr/bin/env ruby

puts "🔍 DETAILED REMAINING ERROR ANALYSIS"  
puts "=" * 50

# Run tests and capture full output
puts "Running test suite to capture current errors..."
result = `timeout 45 rake test 2>&1`

# Extract different error patterns
puts "\n📊 SEARCHING FOR SPECIFIC ERROR PATTERNS:"

# Look for constructor signature issues
constructor_patterns = [
  /wrong number of arguments.*FactsDatabase/i,
  /wrong number of arguments.*GoalSystem/i, 
  /wrong number of arguments.*UnificationEngine/i,
  /wrong number of arguments.*ParameterNode/i
]

missing_method_patterns = [
  /undefined method.*assert_nothing_raised/i,
  /undefined method.*visit_error_node/i,
  /NoMethodError.*assert_nothing_raised/i,
  /NoMethodError.*visit_error_node/i
]

# Count pattern matches
constructor_errors = []
missing_method_errors = []

constructor_patterns.each do |pattern|
  matches = result.scan(pattern)
  constructor_errors += matches
  if matches.length > 0
    puts "✓ Found constructor errors: #{matches.length} matches for #{pattern}"
  end
end

missing_method_patterns.each do |pattern|
  matches = result.scan(pattern)  
  missing_method_errors += matches
  if matches.length > 0
    puts "✓ Found missing method errors: #{matches.length} matches for #{pattern}"
  end
end

# Look for specific error messages in the output
puts "\n🔍 SCANNING FOR SPECIFIC ERRORS:"

if result.include?("assert_nothing_raised")
  puts "✓ Found assert_nothing_raised references"
end

if result.include?("visit_error_node")
  puts "✓ Found visit_error_node references"  
end

if result.include?("FactsDatabase")
  puts "✓ Found FactsDatabase references"
end

if result.include?("GoalSystem")
  puts "✓ Found GoalSystem references"
end

if result.include?("wrong number of arguments")
  puts "✓ Found 'wrong number of arguments' errors"
  # Extract lines with this error
  result.lines.select { |line| line.include?("wrong number of arguments") }.first(5).each do |line|
    puts "   → #{line.strip}"
  end
end

if result.include?("undefined method")
  puts "✓ Found 'undefined method' errors"
  result.lines.select { |line| line.include?("undefined method") }.first(5).each do |line|
    puts "   → #{line.strip}"
  end
end

# Extract final test summary
summary_match = result.match(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/)
if summary_match
  runs, assertions, failures, errors = summary_match.captures
  puts "\n📈 CURRENT TEST RESULTS:"
  puts "   Runs: #{runs}"
  puts "   Failures: #{failures}"  
  puts "   Errors: #{errors}"
  
  total_issues = failures.to_i + errors.to_i
  success_rate = ((runs.to_i - total_issues).to_f / runs.to_i * 100).round(1)
  puts "   Success Rate: #{success_rate}%"
  
  puts "\n✅ PROGRESS UPDATE:"
  puts "   LocalJumpError fix reduced errors from ~419 to #{errors}"
  puts "   This is a #{((419 - errors.to_i).to_f / 419 * 100).round(1)}% error reduction!"
end