#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'

# Define ParseError class if not available
unless defined?(ParseError)
  class ParseError < StandardError
    attr_reader :line, :column, :position
    
    def initialize(message, line: nil, column: nil, position: nil)
      super(message)
      @line = line
      @column = column  
      @position = position
    end
  end
end

def test_parsing_errors
  puts "=== Testing Priority 3 Parser Errors ==="
  
  test_cases = [
    # Test case 1: Rule definition with :- syntax
    {
      "name" => "Rule definition parsing",
      "code" => "rule ancestor(X, Y) :- parent(X, Y)"
    },
    
    # Test case 2: Expression with backslash in string
    {
      "name" => "Backslash in regex pattern", 
      "code" => 'pattern = "\\d+"'
    },
    
    # Test case 3: Method call after dot
    {
      "name" => "Method call after dot",
      "code" => "obj.method"
    },
    
    # Test case 4: Rule with logical operators
    {
      "name" => "Rule with logical syntax",
      "code" => "rule grandparent(X, Z) :- parent(X, Y), parent(Y, Z)"
    }
  ]
  
  test_cases.each_with_index do |test_case, i|
    puts "\n--- Test #{i+1}: #{test_case['name']} ---"
    puts "Code: #{test_case['code']}"
    
    begin
      lexer = Lexer.new(test_case['code'])
      tokens = lexer.tokenize
      puts "Tokens: #{tokens.map { |t| "#{t.type}(#{t.value})" }.join(', ')}"
      
      parser = Parser.new(tokens)
      ast = parser.parse
      puts "✓ Parsing successful: #{ast.class}"
      
    rescue => e
      puts "✗ Error: #{e.message}"
      puts "  Error class: #{e.class}"
    end
  end
end

def test_parse_error_availability
  puts "\n=== Testing ParseError Constant Availability ==="
  
  begin
    # Try to reference ParseError
    if defined?(ParseError)
      puts "✓ ParseError constant is available"
    else
      puts "✗ ParseError constant is NOT available"
    end
    
    # Check if it's a standard error class
    if defined?(StandardError)
      puts "✓ StandardError is available"
    end
    
  rescue => e
    puts "✗ Error testing ParseError: #{e.message}"
  end
end

# Run tests
test_parsing_errors
test_parse_error_availability