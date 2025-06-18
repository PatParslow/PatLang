#!/usr/bin/env ruby

require 'simplecov'

# Focused Lexer Coverage Runner
# Target: Measure only src/lexer.rb coverage improvement
SimpleCov.configure do
  add_filter '/test/'
  add_filter do |source_file|
    # Only track lexer.rb file
    !source_file.filename.end_with?('src/lexer.rb')
  end
  
  # Don't fail on coverage - just measure
  minimum_coverage 0
end

SimpleCov.start

# Load lexer and dependencies
require_relative 'src/lexer'
require_relative 'src/token'
require_relative 'src/ambiguous_token'

puts "🚀 RUNNING FOCUSED LEXER COVERAGE TEST"
puts "=" * 50

# Run targeted tests to measure specific coverage improvements
class LexerCoverageTest
  def initialize
    @tests_run = 0
    @coverage_strategies = []
  end

  def run_coverage_strategy(name, &block)
    puts "Testing Strategy: #{name}"
    @tests_run += 1
    begin
      yield
      puts "✅ #{name} - Success"
      @coverage_strategies << { name: name, status: 'success' }
    rescue => e
      puts "⚠️  #{name} - #{e.message}"
      @coverage_strategies << { name: name, status: 'error', error: e.message }
    end
    puts ""
  end

  def test_error_method_coverage
    run_coverage_strategy("Error Method Coverage (Lines 30-49)") do
      # Test invalid characters to trigger error method
      invalid_chars = ['@', '#', '$', '&', '~', '`', '§', 'ñ', 'ü']
      
      invalid_chars.each do |char|
        lexer = Lexer.new(char)
        token = lexer.get_next_token
        raise "Expected UNKNOWN token" unless token.type == Token::TOKEN_TYPES[:UNKNOWN]
        
        # Get EOF to ensure position advancement
        eof_token = lexer.get_next_token
        raise "Expected EOF after UNKNOWN" unless eof_token.type == Token::TOKEN_TYPES[:EOF]
      end
    end
  end

  def test_string_edge_cases
    run_coverage_strategy("String Tokenization Edge Cases (Lines 460-475)") do
      # Test all escape sequences
      escapes = {
        '"\\n"' => "\n",
        '"\\t"' => "\t", 
        '"\\r"' => "\r",
        '"\\\\"' => "\\",
        '"\\"' => '"',
        '"\\\'"' => "'",
      }
      
      escapes.each do |input, expected|
        lexer = Lexer.new(input)
        token = lexer.get_next_token
        raise "Expected STRING token for #{input}" unless token.type == Token::TOKEN_TYPES[:STRING]
        raise "Expected #{expected}, got #{token.value}" unless token.value == expected
      end

      # Test unterminated strings
      ['\"unterminated', '\'unterminated'].each do |str|
        lexer = Lexer.new(str)
        token = lexer.get_next_token
        raise "Expected UNTERMINATED_STRING" unless token.type == :UNTERMINATED_STRING
      end
    end
  end

  def test_ambiguous_tokens
    run_coverage_strategy("Ambiguous Token Resolution (Lines 323-349)") do
      ambiguous_words = ['make', 'a', 'function', 'called', 'end']
      
      ambiguous_words.each do |word|
        lexer = Lexer.new(word)
        token = lexer.get_next_token
        raise "Expected AmbiguousToken for #{word}" unless token.is_a?(AmbiguousToken)
        raise "Expected 2 possibilities" unless token.possibilities.length == 2
      end
    end
  end

  def test_backslash_handling
    run_coverage_strategy("Backslash Handling (Lines 247-258)") do
      # Test standalone backslash
      lexer = Lexer.new("\\")
      token = lexer.get_next_token
      raise "Expected UNKNOWN token for backslash" unless token.type == :UNKNOWN
      raise "Expected backslash value" unless token.value == "\\"

      # Test backslash with escape chars
      ['\\n', '\\t', '\\r'].each do |seq|
        lexer = Lexer.new(seq)
        token1 = lexer.get_next_token
        raise "Expected UNKNOWN for backslash" unless token1.type == :UNKNOWN
      end
    end
  end

  def test_context_detection_methods
    run_coverage_strategy("Context Detection Methods (Lines 477-546)") do
      # Test comment context detection
      test_cases = [
        ["# comment", true],      # Should skip comment
        ["  # comment", true],    # Should skip comment  
        ["abc#def", false],       # Hash not in comment context
      ]
      
      test_cases.each do |input, should_skip_hash|
        lexer = Lexer.new(input)
        tokens = []
        while (token = lexer.get_next_token).type != Token::TOKEN_TYPES[:EOF]
          tokens << token
        end
        
        hash_tokens = tokens.select { |t| t.value == '#' }
        if should_skip_hash
          raise "Hash should be skipped in '#{input}'" if hash_tokens.any?
        else
          raise "Hash should appear as UNKNOWN in '#{input}'" unless hash_tokens.any? { |t| t.type == Token::TOKEN_TYPES[:UNKNOWN] }
        end
      end

      # Test arithmetic context
      lexer = Lexer.new("x = a + b")
      tokens = []
      while (token = lexer.get_next_token).type != Token::TOKEN_TYPES[:EOF]
        tokens << token
      end
      
      a_tokens = tokens.select { |t| t.value == 'a' }
      raise "Expected 'a' to be identifier in arithmetic context" unless a_tokens.any? { |t| t.type == Token::TOKEN_TYPES[:IDENTIFIER] }
    end
  end

  def test_operator_branches
    run_coverage_strategy("Operator Branch Coverage (Lines 117-246)") do
      # Test all single operators
      operators = {
        '*' => :STAR,
        '/' => :SLASH, 
        '%' => :PERCENT,
        '^' => :CARET,
        '<' => :LESS,
        '>' => :GREATER,
        '?' => :QUESTION,
        '@' => Token::TOKEN_TYPES[:AT],
      }
      
      operators.each do |op, expected_type|
        lexer = Lexer.new(op)
        token = lexer.get_next_token
        raise "Expected #{expected_type} for #{op}" unless token.type == expected_type
      end

      # Test compound operators
      compounds = {
        '==' => Token::TOKEN_TYPES[:EQUAL],
        '!=' => Token::TOKEN_TYPES[:NOT_EQUAL], 
        '<=' => Token::TOKEN_TYPES[:LESS_EQUAL],
        '>=' => Token::TOKEN_TYPES[:GREATER_EQUAL],
        '::' => Token::TOKEN_TYPES[:DOUBLE_COLON],
        '?-' => Token::TOKEN_TYPES[:QUERY_PREFIX]
      }
      
      compounds.each do |op, expected_type|
        lexer = Lexer.new(op)
        token = lexer.get_next_token
        raise "Expected #{expected_type} for #{op}" unless token.type == expected_type
      end
    end
  end

  def test_decimal_number_branches
    run_coverage_strategy("Decimal Number Logic (Lines 194-202)") do
      # Test decimal starting with dot
      lexer = Lexer.new(".5")
      token = lexer.get_next_token
      raise "Expected NUMBER for .5" unless token.type == Token::TOKEN_TYPES[:NUMBER]
      raise "Expected 0.5 value" unless token.value == 0.5

      # Test dot not followed by digit
      lexer = Lexer.new(".method")
      token = lexer.get_next_token
      raise "Expected DOT token" unless token.type == Token::TOKEN_TYPES[:DOT]

      # Test number with decimal validation
      lexer = Lexer.new("3.14.159")
      token1 = lexer.get_next_token
      raise "Expected 3.14" unless token1.value == 3.14
      
      token2 = lexer.get_next_token
      raise "Expected DOT for second decimal" unless token2.type == Token::TOKEN_TYPES[:DOT]
    end
  end

  def test_comprehensive_keywords
    run_coverage_strategy("Comprehensive Keyword Coverage (Lines 352-426)") do
      keywords = {
        'true' => Token::TOKEN_TYPES[:TRUE],
        'false' => Token::TOKEN_TYPES[:FALSE],
        'if' => Token::TOKEN_TYPES[:IF],
        'then' => Token::TOKEN_TYPES[:THEN],
        'else' => Token::TOKEN_TYPES[:ELSE],
        'while' => Token::TOKEN_TYPES[:WHILE],
        'do' => Token::TOKEN_TYPES[:DO],
        'print' => Token::TOKEN_TYPES[:PRINT],
        'reasoning' => Token::TOKEN_TYPES[:REASONING],
        'mode' => Token::TOKEN_TYPES[:MODE],
        'fact' => Token::TOKEN_TYPES[:FACT],
        'goal' => Token::TOKEN_TYPES[:GOAL],
        'query' => Token::TOKEN_TYPES[:QUERY],
        'rule' => Token::TOKEN_TYPES[:RULE],
        'and' => Token::TOKEN_TYPES[:AND],
        'or' => Token::TOKEN_TYPES[:OR],
      }
      
      keywords.each do |keyword, expected_type|
        lexer = Lexer.new(keyword)
        token = lexer.get_next_token
        raise "Expected #{expected_type} for '#{keyword}'" unless token.type == expected_type
      end
    end
  end

  def run_all_tests
    puts "Starting comprehensive lexer coverage tests..."
    puts ""

    test_error_method_coverage
    test_string_edge_cases
    test_ambiguous_tokens
    test_backslash_handling
    test_context_detection_methods
    test_operator_branches
    test_decimal_number_branches
    test_comprehensive_keywords

    puts "COVERAGE TEST SUMMARY"
    puts "-" * 30
    puts "Total Strategies Tested: #{@tests_run}"
    
    successful = @coverage_strategies.count { |s| s[:status] == 'success' }
    failed = @coverage_strategies.count { |s| s[:status] == 'error' }
    
    puts "✅ Successful: #{successful}"
    puts "⚠️  Failed: #{failed}" if failed > 0
    
    if failed > 0
      puts ""
      puts "FAILED STRATEGIES:"
      @coverage_strategies.select { |s| s[:status] == 'error' }.each do |strategy|
        puts "  - #{strategy[:name]}: #{strategy[:error]}"
      end
    end
    
    puts ""
  end
end

# Run the focused coverage test
coverage_test = LexerCoverageTest.new
coverage_test.run_all_tests

# Generate coverage report
result = SimpleCov.result
lexer_file = result.source_files.find { |f| f.filename.end_with?('src/lexer.rb') }

if lexer_file
  puts "📊 LEXER COVERAGE RESULTS"
  puts "=" * 30
  puts "Total Lines: #{lexer_file.lines.count}"
  puts "Covered Lines: #{lexer_file.covered_lines.count}"
  puts "Missed Lines: #{lexer_file.missed_lines.count}"
  puts "Coverage Percentage: #{lexer_file.covered_percent.round(2)}%"
  
  if lexer_file.missed_lines.count > 0
    puts ""
    puts "MISSED LINES (first 20):"
    lexer_file.missed_lines.first(20).each do |line_num|
      puts "  Line #{line_num}"
    end
  end
else
  puts "⚠️  Could not find lexer.rb in coverage results"
end

puts ""
puts "Coverage report saved to: coverage/index.html"