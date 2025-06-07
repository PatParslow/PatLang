#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/parse_error'

def test_parse_error_fixes
  puts "=== Testing Priority 3 ParseError Fixes ==="
  
  test_cases = [
    # Test case 1: Rule definition should work
    {
      "name" => "Rule definition parsing",
      "code" => "rule ancestor(X, Y) :- parent(X, Y)"
    },
    
    # Test case 2: WHERE in query expression should work
    {
      "name" => "Query with WHERE clause", 
      "code" => "query number(X) where X > 500"
    },
    
    # Test case 3: Method call after dot should work
    {
      "name" => "Method call after dot",
      "code" => "obj.method"
    },
    
    # Test case 4: Complex WHERE expression
    {
      "name" => "Complex WHERE clause",
      "code" => "query number(X) where X > 500 and X < 600"
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
      
    rescue ParseError => e
      puts "✗ ParseError: #{e.message}"
      puts "  Line: #{e.line}, Column: #{e.column}" if e.line && e.column
    rescue => e
      puts "✗ Other Error: #{e.message}"
      puts "  Error class: #{e.class}"
    end
  end
end

def test_parse_error_class
  puts "\n=== Testing ParseError Class ==="
  
  begin
    # Test basic ParseError creation
    error = ParseError.new("Test error", line: 1, column: 5, position: 10)
    puts "✓ ParseError created: #{error.message}"
    puts "✓ Line: #{error.line}, Column: #{error.column}, Position: #{error.position}"
    
    # Test ParseError inheritance
    if error.is_a?(StandardError)
      puts "✓ ParseError correctly inherits from StandardError"
    else
      puts "✗ ParseError inheritance issue"
    end
    
    # Test ParseError can be raised and caught
    begin
      raise ParseError.new("Test exception", line: 2, column: 3)
    rescue ParseError => pe
      puts "✓ ParseError can be raised and caught: #{pe.message}"
    end
    
  rescue => e
    puts "✗ Error testing ParseError class: #{e.message}"
  end
end

# Test malformed syntax that should raise ParseError
def test_parse_error_handling
  puts "\n=== Testing ParseError Handling ==="
  
  malformed_cases = [
    {
      "name" => "Missing colon in goal",
      "code" => "goal malformed { postcondition missing colon }"
    }
  ]
  
  malformed_cases.each_with_index do |test_case, i|
    puts "\n--- Error Test #{i+1}: #{test_case['name']} ---"
    puts "Code: #{test_case['code']}"
    
    begin
      lexer = Lexer.new(test_case['code'])
      tokens = lexer.tokenize
      parser = Parser.new(tokens)
      ast = parser.parse
      puts "⚠️ Expected error but parsing succeeded: #{ast.class}"
      
    rescue ParseError => e
      puts "✓ ParseError properly raised: #{e.message}"
      puts "  Line: #{e.line}, Column: #{e.column}" if e.line && e.column
    rescue => e
      puts "✗ Other Error (expected ParseError): #{e.message}"
      puts "  Error class: #{e.class}"
    end
  end
end

# Run tests
test_parse_error_fixes
test_parse_error_class
test_parse_error_handling