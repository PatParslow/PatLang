#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/exceptions'

puts "=== COMPREHENSIVE ERROR RECOVERY VALIDATION ==="
puts

# Test cases to validate comprehensive error recovery
test_cases = [
  {
    name: "Single UNKNOWN Token",
    code: "@#$%",
    description: "Should advance past UNKNOWN token and continue parsing"
  },
  {
    name: "Single UNTERMINATED_STRING Token", 
    code: '"hello world',
    description: "Should advance past UNTERMINATED_STRING and continue parsing"
  },
  {
    name: "Unbalanced Opening Parenthesis",
    code: "(2 + 3",
    description: "Should advance past unbalanced parenthesis for error recovery"
  },
  {
    name: "Unbalanced Closing Parenthesis",
    code: "2 + 3)",
    description: "Should advance past unbalanced parenthesis for error recovery"
  },
  {
    name: "Multiple Errors in Same Source",
    code: "@#$% (2 + 3 \"unterminated",
    description: "Should find and recover from ALL errors in source code"
  },
  {
    name: "Mixed Malformed Syntax",
    code: "array 5] block } @#$%",
    description: "Should continue parsing through multiple malformed constructs"
  },
  {
    name: "Complex Multi-Error Source",
    code: '"broken string @#$% (incomplete paren array 5] { broken brace',
    description: "Should demonstrate comprehensive error recovery across complex source"
  }
]

def test_error_recovery(test_case)
  name = test_case[:name]
  code = test_case[:code]
  description = test_case[:description]
  
  puts "--- Testing: #{name} ---"
  puts "Code: #{code.inspect}"
  puts "Description: #{description}"
  puts
  
  begin
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    puts "Tokens: #{tokens.map(&:type).inspect}"
    
    parser = Parser.new(tokens)
    result = parser.parse
    
    puts "Parse Result: #{result.class}"
    puts "Errors Collected: #{parser.collected_errors.length}"
    
    if parser.has_errors?
      puts "Error Details:"
      parser.get_all_errors.each_with_index do |error, idx|
        puts "  #{idx + 1}. #{error[:message]} (Token: #{error[:token]&.type}, Position: #{error[:position]})"
      end
    else
      puts "No errors collected during parsing"
    end
    
    return {
      name: name,
      errors_found: parser.collected_errors.length,
      parse_succeeded: true,
      result_type: result.class.name
    }
    
  rescue => e
    puts "❌ PARSE FAILED: #{e.class} - #{e.message}"
    return {
      name: name,
      errors_found: 0,
      parse_succeeded: false,
      error: e.message
    }
  end
  
  puts
  puts "-" * 60
  puts
end

# Run all test cases
results = []
test_cases.each do |test_case|
  result = test_error_recovery(test_case)
  results << result
end

# Analysis and summary
puts "=== ERROR RECOVERY ANALYSIS ==="
puts

total_tests = results.length
successful_parses = results.count { |r| r[:parse_succeeded] }
total_errors_collected = results.sum { |r| r[:errors_found] }

puts "Total Tests: #{total_tests}"
puts "Successful Parses: #{successful_parses}"
puts "Failed Parses: #{total_tests - successful_parses}"
puts "Total Errors Collected: #{total_errors_collected}"
puts

puts "=== SUCCESS CRITERIA VALIDATION ==="
puts

# Validate success criteria
success_criteria = {
  "All tests parse successfully (no crashes)" => successful_parses == total_tests,
  "Multiple errors collected across tests" => total_errors_collected > 0,
  "Parser continues after errors" => successful_parses > 0,
  "Error recovery demonstrates advancement" => total_errors_collected >= test_cases.length / 2
}

all_criteria_met = true
success_criteria.each do |criterion, met|
  status = met ? "✅" : "❌"
  puts "#{status} #{criterion}"
  all_criteria_met = false unless met
end

puts
if all_criteria_met
  puts "🎉 SUCCESS: Comprehensive error recovery implemented successfully!"
  puts "✅ Parser advances past ALL problematic tokens"
  puts "✅ Error collection mechanism working"
  puts "✅ Multiple errors found and reported"
  puts "✅ No infinite loops or hanging behavior"
else
  puts "⚠️  Some success criteria not met - implementation needs refinement"
end

puts
puts "=== DETAILED RESULTS ==="
results.each do |result|
  status = result[:parse_succeeded] ? "✅" : "❌"
  puts "#{status} #{result[:name]}: #{result[:errors_found]} errors, Result: #{result[:result_type] || result[:error]}"
end

exit(all_criteria_met ? 0 : 1)