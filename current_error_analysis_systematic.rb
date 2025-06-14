#!/usr/bin/env ruby

puts "🔍 SYSTEMATIC ERROR ANALYSIS"
puts "=" * 50

# Run test suite and capture detailed error information
puts "\n📊 Running test suite for detailed error analysis..."

start_time = Time.now
result = `timeout 60 rake test 2>&1`
end_time = Time.now

puts "   Duration: #{(end_time - start_time).round(1)}s"

# Parse test summary
summary_match = result.match(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/)
if summary_match
  runs, assertions, failures, errors = summary_match.captures
  puts "\n📈 CURRENT STATUS:"
  puts "   Runs: #{runs}, Failures: #{failures}, Errors: #{errors}"
  puts "   Success Rate: #{((runs.to_i - failures.to_i - errors.to_i).to_f / runs.to_i * 100).round(1)}%"
end

# Analyze specific error patterns
puts "\n🎯 TOP ERROR PATTERNS:"

error_patterns = [
  { pattern: /wrong number of arguments/, name: "Constructor Signature Issues" },
  { pattern: /undefined method `([^']+)'/, name: "Missing Methods", capture: true },
  { pattern: /NoMethodError/, name: "NoMethodError Issues" },
  { pattern: /ArgumentError/, name: "Argument Errors" },
  { pattern: /NameError/, name: "Name Errors" },
  { pattern: /TypeError/, name: "Type Errors" },
  { pattern: /NotImplementedError/, name: "NotImplemented Stubs" },
  { pattern: /RuntimeError/, name: "Runtime Errors" },
  { pattern: /LocalJumpError/, name: "Local Jump Errors" },
  { pattern: /SyntaxError/, name: "Syntax Errors" }
]

error_counts = {}
captured_methods = []

error_patterns.each do |pattern_info|
  matches = result.scan(pattern_info[:pattern])
  count = matches.size
  error_counts[pattern_info[:name]] = count
  
  if pattern_info[:capture] && count > 0
    captured_methods.concat(matches.flatten.uniq)
  end
end

# Sort by frequency and display
sorted_errors = error_counts.sort_by { |name, count| -count }
sorted_errors.first(8).each_with_index do |(name, count), index|
  next if count == 0
  puts "   #{index + 1}. #{name}: #{count} occurrences"
end

# Show missing methods
if captured_methods.any?
  puts "\n🔧 TOP MISSING METHODS:"
  method_counts = captured_methods.tally.sort_by { |method, count| -count }
  method_counts.first(10).each_with_index do |(method, count), index|
    puts "   #{index + 1}. `#{method}`: #{count} times"
  end
end

# Analyze test file patterns
puts "\n📁 ERRORS BY TEST CATEGORY:"
test_categories = {
  'infrastructure' => 0,
  'patlang_language' => 0,
  'ruby_implementation' => 0,
  'integration' => 0
}

result.scan(/test\/(\w+)\/[^:]+:\d+/).each do |matches|
  category = matches[0]
  test_categories[category] = (test_categories[category] || 0) + 1
end

test_categories.sort_by { |cat, count| -count }.each do |category, count|
  next if count == 0
  puts "   #{category}: #{count} errors"
end

# Find specific high-impact fixes
puts "\n🎯 HIGH-IMPACT FIX OPPORTUNITIES:"

# Check for constructor signature issues
if result.include?("wrong number of arguments")
  constructor_errors = result.scan(/([^:\s]+):\d+:in `(?:new|initialize)'.*wrong number of arguments/)
  if constructor_errors.any?
    puts "   🔧 Constructor Issues:"
    constructor_errors.flatten.uniq.first(5).each do |file|
      puts "      - #{file}"
    end
  end
end

# Check for missing method implementations
common_missing = ['match?', '[]', 'value', 'type', 'evaluate', 'call']
common_missing.each do |method|
  count = result.scan(/undefined method `#{Regexp.escape(method)}'/).size
  if count > 5
    puts "   🔧 Critical Missing Method: `#{method}` (#{count} failures)"
  end
end

puts "\n✅ ANALYSIS COMPLETE"
puts "Next: Focus on top 3 error patterns for maximum impact"