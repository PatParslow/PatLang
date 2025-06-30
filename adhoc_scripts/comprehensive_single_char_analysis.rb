#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/token'

puts "=== COMPREHENSIVE SINGLE CHARACTER TOKEN ANALYSIS ==="
puts

# Test all single characters that could potentially be tokens
single_char_candidates = [
  # Current working ones from test
  ['<', :LESS],
  ['>', :GREATER], 
  ['=', :ASSIGN],
  
  # The failing one
  ['!', :NOT],
  
  # Other potential single character tokens
  ['+', :PLUS],
  ['-', :MINUS],
  ['*', :STAR],
  ['/', :SLASH],
  ['%', :PERCENT],
  ['(', :LPAREN],
  [')', :RPAREN],
  ['{', :LBRACE],
  ['}', :RBRACE],
  [':', :COLON],
  [',', :COMMA],
  
  # Questionable ones that might need tokens
  ['&', :AND],          # Logical AND?
  ['|', :OR],           # Logical OR?  
  ['^', :XOR],          # XOR?
  ['~', :COMPLEMENT],   # Bitwise complement?
  ['?', :QUESTION],     # Ternary operator?
  ['@', :AT],           # Instance variable?
  ['$', :DOLLAR],       # Global variable?
  ['#', :HASH],         # Comment or hash?
]

puts "1. Testing all potential single character tokens:"
puts

working_tokens = []
missing_tokens = []
erroring_tokens = []

single_char_candidates.each do |input, expected_type|
  print "   Testing '#{input}' expecting #{expected_type}: "
  begin
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    actual_type = tokens[0].type
    
    if actual_type == expected_type
      puts "✓ PASS"
      working_tokens << [input, expected_type]
    else
      puts "✗ FAIL (got #{actual_type})"
      missing_tokens << [input, expected_type, actual_type]
    end
  rescue => e
    puts "✗ ERROR: #{e.message}"
    erroring_tokens << [input, expected_type, e.message]
  end
end

puts
puts "2. Double character tokens to check if single versions work:"
double_char_pairs = [
  ['==', '=', :EQUAL, :ASSIGN],
  ['!=', '!', :NOT_EQUAL, :NOT],
  ['<=', '<', :LESS_EQUAL, :LESS],
  ['>=', '>', :GREATER_EQUAL, :GREATER]
]

puts
double_char_pairs.each do |double_input, single_input, double_expected, single_expected|
  puts "   Testing double '#{double_input}' and single '#{single_input}':"
  
  # Test double character
  begin
    lexer = Lexer.new(double_input)
    tokens = lexer.tokenize
    double_actual = tokens[0].type
    puts "     Double: #{double_actual} (#{double_actual == double_expected ? 'PASS' : 'FAIL'})"
  rescue => e
    puts "     Double: ERROR - #{e.message}"
  end
  
  # Test single character
  begin
    lexer = Lexer.new(single_input)
    tokens = lexer.tokenize
    single_actual = tokens[0].type
    puts "     Single: #{single_actual} (#{single_actual == single_expected ? 'PASS' : 'FAIL'})"
  rescue => e
    puts "     Single: ERROR - #{e.message}"
  end
end

puts
puts "3. SUMMARY:"
puts "   Working tokens: #{working_tokens.length}"
working_tokens.each { |input, type| puts "     '#{input}' → #{type}" }

puts
puts "   Missing/wrong tokens: #{missing_tokens.length}"
missing_tokens.each { |input, expected, actual| puts "     '#{input}' expected #{expected}, got #{actual}" }

puts
puts "   Error tokens: #{erroring_tokens.length}"
erroring_tokens.each { |input, expected, error| puts "     '#{input}' expected #{expected}, ERROR: #{error}" }

puts
puts "4. IMPACT ANALYSIS:"
puts "   Running all lexer tests to see what else might be affected..."