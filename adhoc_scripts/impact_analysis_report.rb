#!/usr/bin/env ruby

puts "=== IMPACT ANALYSIS: FIXING :NOT TOKEN ==="
puts

puts "CURRENT TEST FAILURES (8 total):"
puts

failures = [
  {
    test: "test_single_vs_double_character_disambiguation",
    type: "ERROR", 
    issue: "Missing :NOT token for '!' character",
    related_to_not: true
  },
  {
    test: "test_boolean_and_comparison_operators", 
    type: "FAILURE",
    issue: "Expected :IDENTIFIER, got :A",
    related_to_not: false
  },
  {
    test: "test_arithmetic_expressions",
    type: "FAILURE", 
    issue: "Expected :IDENTIFIER, got :A",
    related_to_not: false
  },
  {
    test: "test_edge_case_tokenization",
    type: "FAILURE",
    issue: "Expected :IDENTIFIER, got :A", 
    related_to_not: false
  },
  {
    test: "test_identifier_edge_cases",
    type: "FAILURE",
    issue: "Expected :IDENTIFIER, got :A",
    related_to_not: false
  },
  {
    test: "test_error_handling_comprehensive",
    type: "FAILURE",
    issue: "Expected RuntimeError for invalid chars, but none raised",
    related_to_not: false
  },
  {
    test: "test_error_handling", 
    type: "FAILURE",
    issue: "Expected RuntimeError for invalid chars, but none raised",
    related_to_not: false
  },
  {
    test: "test_comprehensive_token_values",
    type: "FAILURE",
    issue: "Expected nil for PLUS value, got '+'",
    related_to_not: false
  }
]

not_related = failures.select { |f| f[:related_to_not] }
other_failures = failures.reject { |f| f[:related_to_not] }

puts "1. FAILURES DIRECTLY RELATED TO :NOT TOKEN:"
not_related.each do |f|
  puts "   ✓ #{f[:test]} - #{f[:issue]}"
end

puts
puts "2. FAILURES NOT RELATED TO :NOT TOKEN (#{other_failures.length}):"
other_failures.each do |f|
  puts "   • #{f[:test]} - #{f[:issue]}"
end

puts
puts "3. ANALYSIS:"
puts "   - Only 1 test directly affected by missing :NOT token"
puts "   - 7 other failures are unrelated AmbiguousToken issues"
puts "   - Fixing :NOT token will resolve 1/8 failures (12.5%)"
puts "   - Safe to proceed with :NOT fix without affecting other tests"

puts
puts "4. RECOMMENDED FIX STRATEGY:"
puts "   STEP 1: Add :NOT token support (safe, isolated change)"
puts "     - Add NOT: :NOT to TOKEN_TYPES hash" 
puts "     - Modify lexer line 128 to return :NOT token"
puts "     - Test: Should fix test_single_vs_double_character_disambiguation"
puts
puts "   STEP 2: Address AmbiguousToken :A issues separately"
puts "     - Multiple tests expect :IDENTIFIER but get :A token"
puts "     - This is a broader AmbiguousToken resolution issue"
puts "     - Should be handled in separate investigation"

puts
puts "5. RISK ASSESSMENT FOR :NOT TOKEN FIX:"
puts "   - LOW RISK: Isolated change, follows existing patterns"
puts "   - NO IMPACT: Won't affect other failing tests"
puts "   - SAFE: Only adds new functionality, doesn't change existing"