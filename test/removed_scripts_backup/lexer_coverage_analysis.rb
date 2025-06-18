require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
  enable_coverage :line
end

require_relative '../patlang-core/lexer/lexer'
require_relative '../patlang-core/lexer/token'

# Test current lexer functionality to see what's covered
def test_basic_lexer_coverage
  puts "=== Testing Basic Lexer Coverage ==="
  
  # Test numbers
  lexer = Lexer.new("42 3.14")
  tokens = lexer.tokenize
  
  # Test operators
  lexer = Lexer.new("+ - * / = == != < > <= >=")
  tokens = lexer.tokenize
  
  # Test parentheses and brackets
  lexer = Lexer.new("( ) [ ] . ,")
  tokens = lexer.tokenize
  
  # Test identifiers and keywords
  lexer = Lexer.new("x true false if then else end while do")
  tokens = lexer.tokenize
  
  # Test strings
  lexer = Lexer.new('"hello world"')
  tokens = lexer.tokenize
  
  puts "Basic coverage test complete"
end

def test_string_edge_cases
  puts "=== Testing String Edge Cases ==="
  
  # Test escape sequences
  lexer = Lexer.new('"hello\\nworld\\t\\"quote\\""')
  tokens = lexer.tokenize
  
  # Test empty string
  lexer = Lexer.new('""')
  tokens = lexer.tokenize
  
  puts "String edge cases test complete"
end

def test_error_conditions
  puts "=== Testing Error Conditions ==="
  
  # Test invalid characters
  begin
    lexer = Lexer.new("@")
    tokens = lexer.tokenize
  rescue RuntimeError => e
    puts "Caught expected error: #{e.message}"
  end
  
  # Test invalid exclamation mark
  begin
    lexer = Lexer.new("!")
    tokens = lexer.tokenize
  rescue RuntimeError => e
    puts "Caught expected error: #{e.message}"
  end
  
  # Test unterminated string
  begin
    lexer = Lexer.new('"unterminated')
    tokens = lexer.tokenize
  rescue RuntimeError => e
    puts "Caught expected error: #{e.message}"
  end
  
  puts "Error conditions test complete"
end

def test_whitespace_handling
  puts "=== Testing Whitespace Handling ==="
  
  # Test various whitespace
  lexer = Lexer.new("  \t\n\r  42")
  tokens = lexer.tokenize
  
  # Test empty input
  lexer = Lexer.new("")
  tokens = lexer.tokenize
  
  # Test only whitespace
  lexer = Lexer.new("   \t  \n  ")
  tokens = lexer.tokenize
  
  puts "Whitespace handling test complete"
end

def test_decimal_number_edge_cases
  puts "=== Testing Decimal Number Edge Cases ==="
  
  # Test decimal without leading digit
  lexer = Lexer.new(".5")
  tokens = lexer.tokenize
  
  # Test number followed by dot (not decimal)
  lexer = Lexer.new("42.method")
  tokens = lexer.tokenize
  
  puts "Decimal number edge cases test complete"
end

# Run all tests
test_basic_lexer_coverage
test_string_edge_cases
test_error_conditions
test_whitespace_handling
test_decimal_number_edge_cases

puts "\n=== GENERATING COVERAGE REPORT ==="
SimpleCov.result.format!

# Show detailed line coverage for lexer
result = SimpleCov.result
lexer_file = result.files.find { |file| file.filename.include?('lexer.rb') }

if lexer_file
  puts "\n=== LEXER LINE COVERAGE DETAILS ==="
  puts "Total lines: #{lexer_file.lines.count}"
  puts "Covered lines: #{lexer_file.covered_lines.count}"
  puts "Missed lines: #{lexer_file.missed_lines.count}"
  puts "Coverage percentage: #{lexer_file.covered_percent.round(2)}%"
  
  if lexer_file.missed_lines.any?
    puts "\nMISSED LINES:"
    lexer_file.missed_lines.each do |line_num|
      puts "Line #{line_num}: #{lexer_file.source_lines[line_num - 1]}"
    end
  end
else
  puts "Could not find lexer.rb in coverage results"
end