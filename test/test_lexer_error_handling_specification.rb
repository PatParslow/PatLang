#!/usr/bin/env ruby

# Test file to verify lexer error handling specification compliance
# This file demonstrates and tests the "Never Fail, Always Token" principle

require_relative '../src/lexer'
require_relative '../src/token'

class TestLexerErrorHandlingSpecification
  def initialize
    @test_count = 0
    @passed_count = 0
    @failed_tests = []
  end

  def run_all_tests
    puts "Testing Lexer Error Handling Specification Compliance"
    puts "=" * 60
    
    test_unknown_characters
    test_unterminated_strings
    test_invalid_escape_sequences
    test_multiple_invalid_characters
    test_mixed_valid_invalid
    test_large_invalid_input
    test_malformed_numbers
    test_invalid_operators
    test_no_exceptions_raised
    
    print_summary
  end

  private

  def test(name, &block)
    @test_count += 1
    print "Test #{@test_count}: #{name}... "
    
    begin
      result = block.call
      if result
        puts "PASS"
        @passed_count += 1
      else
        puts "FAIL"
        @failed_tests << name
      end
    rescue => e
      puts "FAIL (Exception: #{e.message})"
      @failed_tests << "#{name} (Exception: #{e.message})"
    end
  end

  def test_unknown_characters
    test "Unknown characters return UNKNOWN tokens" do
      lexer = Lexer.new("hello $ world")
      tokens = lexer.tokenize
      
      # Should get: IDENTIFIER, UNKNOWN, IDENTIFIER, EOF
      return false unless tokens.length == 4
      return false unless tokens[0].type == Token::TOKEN_TYPES[:IDENTIFIER]
      return false unless tokens[1].type == Token::TOKEN_TYPES[:UNKNOWN]
      return false unless tokens[1].value == "$"
      return false unless tokens[2].type == Token::TOKEN_TYPES[:IDENTIFIER]
      return false unless tokens[3].type == Token::TOKEN_TYPES[:EOF]
      
      true
    end
  end

  def test_unterminated_strings
    test "Unterminated strings return UNTERMINATED_STRING tokens" do
      lexer = Lexer.new('"hello world')
      tokens = lexer.tokenize
      
      # Should get: UNTERMINATED_STRING, EOF
      return false unless tokens.length == 2
      return false unless tokens[0].type == :UNTERMINATED_STRING
      return false unless tokens[0].value == "hello world"
      return false unless tokens[1].type == Token::TOKEN_TYPES[:EOF]
      
      true
    end
  end

  def test_invalid_escape_sequences
    test "Invalid escape sequences don't crash lexer" do
      lexer = Lexer.new('"hello\\x world"')
      tokens = lexer.tokenize
      
      # Should not crash and should return some token
      return false unless tokens.length >= 1
      return false unless tokens[-1].type == Token::TOKEN_TYPES[:EOF]
      
      true
    end
  end

  def test_multiple_invalid_characters
    test "Multiple invalid characters return multiple UNKNOWN tokens" do
      lexer = Lexer.new("@ # $ % ^")
      tokens = lexer.tokenize
      
      # Should get multiple UNKNOWN tokens + EOF
      unknown_count = tokens.count { |t| t.type == Token::TOKEN_TYPES[:UNKNOWN] }
      return false unless unknown_count > 0
      return false unless tokens[-1].type == Token::TOKEN_TYPES[:EOF]
      
      true
    end
  end

  def test_mixed_valid_invalid
    test "Mixed valid and invalid input processes correctly" do
      lexer = Lexer.new("x = $ + y")
      tokens = lexer.tokenize
      
      expected_types = [
        Token::TOKEN_TYPES[:IDENTIFIER],  # x
        :ASSIGN,                          # =
        Token::TOKEN_TYPES[:UNKNOWN],     # $
        Token::TOKEN_TYPES[:PLUS],        # +
        Token::TOKEN_TYPES[:IDENTIFIER],  # y
        Token::TOKEN_TYPES[:EOF]          # EOF
      ]
      
      actual_types = tokens.map(&:type)
      return false unless actual_types == expected_types
      
      true
    end
  end

  def test_large_invalid_input
    test "Large invalid input doesn't crash or hang" do
      large_input = "$" * 1000
      lexer = Lexer.new(large_input)
      
      start_time = Time.now
      tokens = lexer.tokenize
      end_time = Time.now
      
      # Should complete in reasonable time (< 1 second)
      return false unless (end_time - start_time) < 1.0
      
      # Should get 1000 UNKNOWN tokens + 1 EOF token
      return false unless tokens.length == 1001
      return false unless tokens[0...-1].all? { |t| t.type == Token::TOKEN_TYPES[:UNKNOWN] }
      return false unless tokens[-1].type == Token::TOKEN_TYPES[:EOF]
      
      true
    end
  end

  def test_malformed_numbers
    test "Malformed numbers are handled gracefully" do
      lexer = Lexer.new("123.45.67")
      tokens = lexer.tokenize
      
      # Should tokenize without crashing
      return false unless tokens.length >= 2  # At least some tokens + EOF
      return false unless tokens[-1].type == Token::TOKEN_TYPES[:EOF]
      
      true
    end
  end

  def test_invalid_operators
    test "Invalid operators return UNKNOWN tokens" do
      lexer = Lexer.new("a ~~ b")
      tokens = lexer.tokenize
      
      # Should process without crashing
      return false unless tokens.length >= 4  # identifier, unknown(s), identifier, EOF
      return false unless tokens[-1].type == Token::TOKEN_TYPES[:EOF]
      
      # Should have some UNKNOWN tokens for the ~~ operator
      unknown_count = tokens.count { |t| t.type == Token::TOKEN_TYPES[:UNKNOWN] }
      return false unless unknown_count > 0
      
      true
    end
  end

  def test_no_exceptions_raised
    test "No exceptions raised for any invalid input" do
      test_inputs = [
        "$@#%^&*",           # All invalid characters
        '"unterminated',     # Unterminated string
        '123.45.67.89',      # Multiple decimals
        '\\invalid\\escape', # Invalid escape outside string
        '@#$%^&*()',         # Mixed invalid characters
        '',                  # Empty input
        ' ' * 100,           # Only whitespace
        "\n\t\r",           # Only control characters
      ]
      
      test_inputs.each do |input|
        begin
          lexer = Lexer.new(input)
          tokens = lexer.tokenize
          # Should always get at least EOF token
          return false unless tokens.length >= 1
          return false unless tokens[-1].type == Token::TOKEN_TYPES[:EOF]
        rescue => e
          puts "  FAILED on input: #{input.inspect} - Exception: #{e.message}"
          return false
        end
      end
      
      true
    end
  end

  def print_summary
    puts
    puts "=" * 60
    puts "Test Summary:"
    puts "Total tests: #{@test_count}"
    puts "Passed: #{@passed_count}"
    puts "Failed: #{@test_count - @passed_count}"
    
    if @failed_tests.any?
      puts
      puts "Failed tests:"
      @failed_tests.each { |test| puts "  - #{test}" }
    end
    
    puts
    if @passed_count == @test_count
      puts "✅ ALL TESTS PASSED - Lexer Error Handling Specification Compliant!"
    else
      puts "❌ SOME TESTS FAILED - Lexer needs fixes to meet specification!"
    end
  end
end

# Run tests if this file is executed directly
if __FILE__ == $0
  tester = TestLexerErrorHandlingSpecification.new
  tester.run_all_tests
end