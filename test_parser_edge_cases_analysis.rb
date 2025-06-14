#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/exceptions'

# Test script to identify specific ParseError cases and edge case handling
class ParseErrorAnalysis
  def initialize
    @errors = []
    @test_cases = []
  end

  def test_case(description, code)
    @test_cases << { description: description, code: code }
    
    begin
      lexer = Lexer.new(code)
      parser = Parser.new(lexer)
      result = parser.parse
      puts "✓ PASS: #{description}"
      return true
    rescue ParseError => e
      puts "✗ ParseError: #{description}"
      puts "  Code: #{code.inspect}"
      puts "  Error: #{e.message}"
      puts "  Line: #{e.line}, Column: #{e.column}" if e.line && e.column
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

  def run_comprehensive_tests
    puts "=== PARSER EDGE CASE ANALYSIS ==="
    puts "Testing for ParseError instances and edge cases..."
    puts
    
    # Malformed expressions
    test_case("Incomplete expression", "x +")
    test_case("Missing operand", "* 5")
    test_case("Unmatched parentheses - missing close", "(x + y")
    test_case("Unmatched parentheses - missing open", "x + y)")
    test_case("Incomplete function call", "func(")
    test_case("Incomplete function call args", "func(x,")
    test_case("Empty parentheses in expression", "x + ()")
    test_case("Malformed method call", "obj.")
    test_case("Incomplete method call", "obj.method(")
    test_case("Missing identifier after dot", "x.")
    
    # Assignment edge cases
    test_case("Assignment without value", "x =")
    test_case("Make without value", "make x")
    test_case("Assignment to nothing", "= 5")
    test_case("Incomplete property assignment", "obj.prop =")
    test_case("Property assignment without object", ".prop = 5")
    
    # Control flow edge cases
    test_case("If without condition", "if")
    test_case("If without then", "if x")
    test_case("If without end", "if x then y")
    test_case("While without condition", "while")
    test_case("While without end", "while x do y")
    
    # Function definition edge cases
    test_case("Function without name", "make function")
    test_case("Function without body", "make function test")
    test_case("Incomplete function params", "make function test(")
    test_case("Function with malformed params", "make function test(x,)")
    
    # Goal/constraint edge cases
    test_case("Goal without name", "goal")
    test_case("Goal without body", "goal test")
    test_case("Incomplete goal body", "goal test {")
    test_case("Constraint without variable", "constrain")
    test_case("Constraint without type", "constrain x ::")
    test_case("Constraint with malformed type", "constrain x :: ")
    
    # Reasoning constructs edge cases
    test_case("Assert without expression", "assert")
    test_case("Query without pattern", "query")
    test_case("Rule without head", "rule")
    test_case("Rule without body", "rule head(x)")
    test_case("Pursue without goal", "pursue")
    
    # Block and brace edge cases
    test_case("Unmatched braces", "{x + y")
    test_case("Empty block incomplete", "{")
    test_case("Block with malformed content", "{x +}")
    
    # Array and hash edge cases
    test_case("Incomplete array", "[x,")
    test_case("Array without close", "[x, y")
    test_case("Incomplete hash", "{key:")
    test_case("Hash without close", "{key: value")
    test_case("Hash with malformed key", "{: value}")
    
    # Expression operator edge cases
    test_case("Double operators", "x ++ y")
    test_case("Operator at end", "x + y +")
    test_case("Operator at start", "+ x + y")
    test_case("Malformed comparison", "x > > y")
    test_case("Incomplete logical", "x and")
    test_case("Incomplete logical or", "x or")
    
    # Type annotation edge cases
    test_case("Incomplete type annotation", "x ::")
    test_case("Type annotation without expression", ":: String")
    test_case("Malformed type annotation", "x :: ")
    
    # String and number edge cases
    test_case("Incomplete string method", "\"hello\".")
    test_case("String method without params", "\"hello\".length(")
    test_case("Number with incomplete operation", "42.")
    
    # Null/nil edge cases
    test_case("Empty input", "")
    test_case("Only whitespace", "   ")
    test_case("Only operators", "+ - * /")
    test_case("Only punctuation", "( ) { } [ ]")
    
    # Complex nested edge cases
    test_case("Nested incomplete expressions", "func(x + (y *")
    test_case("Nested unmatched parens", "func((x + y)")
    test_case("Mixed incomplete structures", "if func( then")
    test_case("Complex malformed expression", "obj.method(x +).prop =")
    
    puts "\n=== ANALYSIS SUMMARY ==="
    puts "Total test cases: #{@test_cases.length}"
    puts "Total errors found: #{@errors.length}"
    parse_errors = @errors.select { |e| e[:type] == :parse_error }
    puts "ParseError instances: #{parse_errors.length}"
    
    puts "\n=== PARSE ERROR DETAILS ==="
    parse_errors.each_with_index do |error, i|
      puts "#{i+1}. #{error[:description]}"
      puts "   Code: #{error[:code].inspect}"
      puts "   Error: #{error[:error]}"
      puts "   Location: Line #{error[:line]}, Column #{error[:column]}" if error[:line]
      puts
    end
    
    return parse_errors
  end
end

# Run the analysis
analysis = ParseErrorAnalysis.new
parse_errors = analysis.run_comprehensive_tests

puts "Found #{parse_errors.length} ParseError instances to fix."