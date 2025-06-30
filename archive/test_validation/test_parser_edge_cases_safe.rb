#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/exceptions'

# Safe test script to validate parser edge case handling without infinite loops
class SafeParseErrorAnalysis
  def initialize
    @errors = []
    @test_cases = []
  end

  def test_case(description, code)
    @test_cases << { description: description, code: code }
    
    # Add timeout protection
    begin
      result = nil
      success = false
      
      # Use a timeout to prevent infinite loops
      require 'timeout'
      Timeout::timeout(5) do  # 5 second timeout per test
        lexer = Lexer.new(code)
        parser = Parser.new(lexer)
        result = parser.parse
        success = true
      end
      
      puts "✓ PASS: #{description}"
      return true
    rescue Timeout::Error
      puts "✗ TIMEOUT: #{description} (possible infinite loop)"
      @errors << {
        description: description,
        code: code,
        error: "Timeout - possible infinite loop",
        type: :timeout
      }
      return false
    rescue ParseError => e
      puts "✗ ParseError: #{description}"
      puts "  Code: #{code.inspect}"
      puts "  Error: #{e.message}"
      puts
      @errors << {
        description: description,
        code: code,
        error: e.message,
        line: e.line,
        column: e.column,
        type: :parse_error
      }
      return false
    rescue => e
      puts "✗ Other Error: #{description} - #{e.class}: #{e.message}"
      @errors << {
        description: description,
        code: code,
        error: e.message,
        type: e.class
      }
      return false
    end
  end

  def run_targeted_tests
    puts "=== SAFE PARSER EDGE CASE ANALYSIS ==="
    puts "Testing parser improvements with timeout protection..."
    puts
    
    # Test the original 11 ParseError cases that were identified
    test_case("If without condition", "if")
    test_case("If without then", "if x")
    test_case("While without condition", "while")
    test_case("Function without name", "make function")
    test_case("Function without body", "make function test")
    test_case("Constraint without variable", "constrain")
    test_case("Constraint without type", "constrain x ::")
    test_case("Constraint with malformed type", "constrain x :: ")
    
    # Test some expression edge cases
    test_case("Incomplete expression", "x +")
    test_case("Missing operand", "* 5")
    test_case("Unmatched parentheses", "(x + y")
    test_case("Incomplete function call", "func(")
    test_case("Empty parentheses", "x + ()")
    test_case("Malformed method call", "obj.")
    test_case("Assignment without value", "x =")
    test_case("Make without value", "make x")
    
    # Test some complex cases that might cause loops
    test_case("Nested incomplete expressions", "func(x + (y *")
    test_case("Complex malformed expression", "obj.method(x +).prop =")
    
    puts "\n=== ANALYSIS SUMMARY ==="
    puts "Total test cases: #{@test_cases.length}"
    puts "Total errors found: #{@errors.length}"
    
    parse_errors = @errors.select { |e| e[:type] == :parse_error }
    timeouts = @errors.select { |e| e[:type] == :timeout }
    other_errors = @errors.reject { |e| [:parse_error, :timeout].include?(e[:type]) }
    
    puts "ParseError instances: #{parse_errors.length}"
    puts "Timeout errors (infinite loops): #{timeouts.length}"
    puts "Other errors: #{other_errors.length}"
    
    if timeouts.length > 0
      puts "\n=== TIMEOUT ERRORS (INFINITE LOOPS) ==="
      timeouts.each_with_index do |error, i|
        puts "#{i+1}. #{error[:description]}"
        puts "   Code: #{error[:code].inspect}"
        puts
      end
    end
    
    if parse_errors.length > 0
      puts "\n=== REMAINING PARSE ERRORS ==="
      parse_errors.each_with_index do |error, i|
        puts "#{i+1}. #{error[:description]}"
        puts "   Code: #{error[:code].inspect}"
        puts "   Error: #{error[:error]}"
        puts
      end
    end
    
    return { parse_errors: parse_errors, timeouts: timeouts, other_errors: other_errors }
  end
end

# Run the safe analysis
analysis = SafeParseErrorAnalysis.new
results = analysis.run_targeted_tests

puts "\n=== FINAL SUMMARY ==="
puts "ParseError instances remaining: #{results[:parse_errors].length}"
puts "Infinite loops detected: #{results[:timeouts].length}"
puts "Other errors: #{results[:other_errors].length}"

if results[:timeouts].length == 0
  puts "\n✓ SUCCESS: No infinite loops detected!"
else
  puts "\n✗ WARNING: Infinite loops still present in parser"
end

if results[:parse_errors].length < 11
  improvement = 11 - results[:parse_errors].length
  puts "✓ IMPROVEMENT: Reduced ParseError count by #{improvement} instances"
else
  puts "✗ NO IMPROVEMENT: ParseError count not reduced"
end