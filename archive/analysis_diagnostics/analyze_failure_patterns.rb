#!/usr/bin/env ruby

# Phase 1C: Systematic Failure Pattern Analysis
# Categorize the 205 failures + 23 errors by priority patterns

puts "🔍 PHASE 1C: FAILURE PATTERN ANALYSIS"
puts "=" * 60

# Pattern categories from task description
patterns = {
  reasoning_mode_required: {
    count: 0,
    examples: [],
    keywords: ["reasoning mode to be enabled", "Goal declarations require", "Logic rules require"]
  },
  lexer_error_handling: {
    count: 0,
    examples: [],
    keywords: ["RuntimeError expected but nothing was raised", "unterminated string", "lexer"]
  },
  parser_syntax_errors: {
    count: 0,
    examples: [],
    keywords: ["Expected EQUALS", "Expected RPAREN", "Expected type constraint", "ParseError"]
  },
  number_object_edge_cases: {
    count: 0,
    examples: [],
    keywords: ["Infinity", "NaN", "conversion", "coerced into Float"]
  },
  string_index_bounds: {
    count: 0,
    examples: [],
    keywords: ["String index", "out of bounds", "1-based indexing"]
  },
  type_constraint_issues: {
    count: 0,
    examples: [],
    keywords: ["TypeConstraintSystem", "constraint", "ArgumentError", "wrong number of arguments"]
  },
  other_failures: {
    count: 0,
    examples: []
  }
}

# Sample failures from the test output (extracted manually for analysis)
sample_failures = [
  "Goal declarations require reasoning mode to be enabled",
  "Logic rules require reasoning mode to be enabled", 
  "RuntimeError expected but nothing was raised",
  "String index 0 out of bounds for string of length 5 (1-based indexing)",
  "nil can't be coerced into Float",
  "ArgumentError: wrong number of arguments (given 4, expected 3)",
  "Expected EQUALS, got RPAREN",
  "Expected constraint_created event to fire",
  "unterminated string error",
  "ParseError expected but nothing was raised"
]

# Categorize each failure
sample_failures.each do |failure|
  categorized = false
  
  patterns.each do |category, data|
    next if category == :other_failures
    
    if data[:keywords].any? { |keyword| failure.include?(keyword) }
      data[:count] += 1
      data[:examples] << failure
      categorized = true
      break
    end
  end
  
  unless categorized
    patterns[:other_failures][:count] += 1
    patterns[:other_failures][:examples] << failure
  end
end

# Report findings
puts "\n📊 FAILURE PATTERN BREAKDOWN:"
puts "-" * 40

patterns.each do |category, data|
  category_name = category.to_s.gsub('_', ' ').upcase
  puts "\n#{category_name}: #{data[:count]} failures"
  
  if data[:examples].any?
    puts "  Examples:"
    data[:examples].first(3).each do |example|
      puts "    - #{example}"
    end
    puts "    ..." if data[:examples].length > 3
  end
end

puts "\n" + "=" * 60
puts "🎯 PRIORITY ANALYSIS FOR PHASE 1C:"
puts "=" * 60

# Priority 1 estimates from task
priority_1_estimate = patterns[:reasoning_mode_required][:count] + 
                     patterns[:lexer_error_handling][:count] + 
                     patterns[:parser_syntax_errors][:count]

priority_2_estimate = patterns[:number_object_edge_cases][:count] + 
                     patterns[:string_index_bounds][:count]

puts "Priority 1 (High-Impact): ~#{priority_1_estimate} failures"
puts "  - Reasoning mode requirements: #{patterns[:reasoning_mode_required][:count]}"
puts "  - Lexer error handling: #{patterns[:lexer_error_handling][:count]}"
puts "  - Parser syntax errors: #{patterns[:parser_syntax_errors][:count]}"

puts "\nPriority 2 (Object Model): ~#{priority_2_estimate} failures"
puts "  - Number object edge cases: #{patterns[:number_object_edge_cases][:count]}"
puts "  - String index bounds: #{patterns[:string_index_bounds][:count]}"

puts "\nType Constraint Issues: #{patterns[:type_constraint_issues][:count]} failures"
puts "Other failures: #{patterns[:other_failures][:count]} failures"

total_categorized = patterns.values.sum { |data| data[:count] }
puts "\nTotal sample failures analyzed: #{total_categorized}"

puts "\n🚀 RECOMMENDED ATTACK STRATEGY:"
puts "1. Start with reasoning mode requirement failures (highest impact)"
puts "2. Fix lexer error handling expectation mismatches"  
puts "3. Address parser syntax error messages"
puts "4. Handle number object edge cases"
puts "5. Fix string indexing logic"