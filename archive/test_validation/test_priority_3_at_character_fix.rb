#!/usr/bin/env ruby
# frozen_string_literal: true

require 'timeout'
require_relative 'src/lexer'
require_relative 'src/token'

class Priority3AtCharacterTester
  def initialize
    @test_count = 0
    @passed_count = 0
    @failed_tests = []
  end

  def run_test(name)
    @test_count += 1
    print "Testing #{name}... "
    
    begin
      Timeout.timeout(5) do
        yield
      end
      @passed_count += 1
      puts "✅ PASSED"
      true
    rescue Exception => e
      @failed_tests << { name: name, error: e }
      puts "❌ FAILED: #{e.message}"
      false
    end
  end

  def test_basic_at_character_tokenization
    run_test("Basic @ character tokenization") do
      lexer = Lexer.new('@')
      tokens = lexer.tokenize
      
      raise "Expected 2 tokens, got #{tokens.length}" unless tokens.length == 2
      raise "Expected AT token, got #{tokens[0].type}" unless tokens[0].type == Token::TOKEN_TYPES[:AT]
      raise "Expected '@' value, got #{tokens[0].value}" unless tokens[0].value == '@'
      raise "Expected EOF token, got #{tokens[1].type}" unless tokens[1].type == Token::TOKEN_TYPES[:EOF]
    end
  end

  def test_at_character_in_expressions
    run_test("@ character in expressions") do
      lexer = Lexer.new('user @ domain.com')
      tokens = lexer.tokenize
      
      expected_types = [:IDENTIFIER, :AT, :IDENTIFIER, :DOT, :IDENTIFIER, :EOF]
      expected_values = ['user', '@', 'domain', '.', 'com', nil]
      
      raise "Expected #{expected_types.length} tokens, got #{tokens.length}" unless tokens.length == expected_types.length
      
      tokens.each_with_index do |token, i|
        raise "Token #{i}: expected type #{expected_types[i]}, got #{token.type}" unless token.type == expected_types[i]
        next if expected_values[i].nil?
        raise "Token #{i}: expected value #{expected_values[i]}, got #{token.value}" unless token.value == expected_values[i]
      end
    end
  end

  def test_multiple_at_characters
    run_test("Multiple @ characters") do
      lexer = Lexer.new('@@mention')
      tokens = lexer.tokenize
      
      expected_types = [:AT, :AT, :IDENTIFIER, :EOF]
      
      raise "Expected #{expected_types.length} tokens, got #{tokens.length}" unless tokens.length == expected_types.length
      
      tokens.each_with_index do |token, i|
        raise "Token #{i}: expected type #{expected_types[i]}, got #{token.type}" unless token.type == expected_types[i]
      end
    end
  end

  def test_at_character_with_whitespace
    run_test("@ character with whitespace") do
      lexer = Lexer.new('  @  user  ')
      tokens = lexer.tokenize
      
      expected_types = [:AT, :IDENTIFIER, :EOF]
      expected_values = ['@', 'user', nil]
      
      raise "Expected #{expected_types.length} tokens, got #{tokens.length}" unless tokens.length == expected_types.length
      
      tokens.each_with_index do |token, i|
        raise "Token #{i}: expected type #{expected_types[i]}, got #{token.type}" unless token.type == expected_types[i]
        next if expected_values[i].nil?
        raise "Token #{i}: expected value #{expected_values[i]}, got #{token.value}" unless token.value == expected_values[i]
      end
    end
  end

  def test_email_like_patterns
    run_test("Email-like patterns") do
      lexer = Lexer.new('test@example.com')
      tokens = lexer.tokenize
      
      expected_types = [:IDENTIFIER, :AT, :IDENTIFIER, :DOT, :IDENTIFIER, :EOF]
      
      raise "Expected #{expected_types.length} tokens, got #{tokens.length}" unless tokens.length == expected_types.length
      
      tokens.each_with_index do |token, i|
        raise "Token #{i}: expected type #{expected_types[i]}, got #{token.type}" unless token.type == expected_types[i]
      end
      
      # Verify specific values for email components
      raise "Expected 'test' for first identifier, got #{tokens[0].value}" unless tokens[0].value == 'test'
      raise "Expected '@' for AT token, got #{tokens[1].value}" unless tokens[1].value == '@'
      raise "Expected 'example' for third identifier, got #{tokens[2].value}" unless tokens[2].value == 'example'
      raise "Expected '.' for DOT token, got #{tokens[3].value}" unless tokens[3].value == '.'
      raise "Expected 'com' for fifth identifier, got #{tokens[4].value}" unless tokens[4].value == 'com'
    end
  end

  def test_mention_like_patterns
    run_test("Mention-like patterns") do
      lexer = Lexer.new('@username')
      tokens = lexer.tokenize
      
      expected_types = [:AT, :IDENTIFIER, :EOF]
      expected_values = ['@', 'username', nil]
      
      raise "Expected #{expected_types.length} tokens, got #{tokens.length}" unless tokens.length == expected_types.length
      
      tokens.each_with_index do |token, i|
        raise "Token #{i}: expected type #{expected_types[i]}, got #{token.type}" unless token.type == expected_types[i]
        next if expected_values[i].nil?
        raise "Token #{i}: expected value #{expected_values[i]}, got #{token.value}" unless token.value == expected_values[i]
      end
    end
  end

  def test_at_character_in_complex_expressions
    run_test("@ character in complex expressions") do
      lexer = Lexer.new('x + @user * 2')
      tokens = lexer.tokenize
      
      expected_types = [:IDENTIFIER, :PLUS, :AT, :IDENTIFIER, :STAR, :NUMBER, :EOF]
      
      raise "Expected #{expected_types.length} tokens, got #{tokens.length}" unless tokens.length == expected_types.length
      
      tokens.each_with_index do |token, i|
        raise "Token #{i}: expected type #{expected_types[i]}, got #{token.type}" unless token.type == expected_types[i]
      end
    end
  end

  def test_at_character_with_strings
    run_test("@ character with strings") do
      lexer = Lexer.new('"email: " + user@domain.com')
      tokens = lexer.tokenize
      
      expected_types = [:STRING, :PLUS, :IDENTIFIER, :AT, :IDENTIFIER, :DOT, :IDENTIFIER, :EOF]
      
      raise "Expected #{expected_types.length} tokens, got #{tokens.length}" unless tokens.length == expected_types.length
      
      tokens.each_with_index do |token, i|
        raise "Token #{i}: expected type #{expected_types[i]}, got #{token.type}" unless token.type == expected_types[i]
      end
    end
  end

  def test_position_tracking_with_at_character
    run_test("Position tracking with @ character") do
      lexer = Lexer.new("test@user")
      tokens = lexer.tokenize
      
      # Verify position tracking is working correctly
      raise "Expected line 1 for all tokens" unless tokens.all? { |t| t.line == 1 }
      
      # Check column positions
      raise "First token should start at column 1, got #{tokens[0].column}" unless tokens[0].column == 1
      raise "AT token should be at column 5, got #{tokens[1].column}" unless tokens[1].column == 5
      raise "Third token should be at column 6, got #{tokens[2].column}" unless tokens[2].column == 6
    end
  end

  def test_backward_compatibility
    run_test("Backward compatibility - existing tokens still work") do
      # Test that existing functionality is not broken
      test_cases = [
        ['x + y', [:IDENTIFIER, :PLUS, :IDENTIFIER, :EOF]],
        ['"string"', [:STRING, :EOF]],
        ['42', [:NUMBER, :EOF]],
        ['if true then end', [:IF, :TRUE, :THEN, :END, :EOF]]
      ]
      
      test_cases.each do |input, expected_types|
        lexer = Lexer.new(input)
        tokens = lexer.tokenize
        
        actual_types = tokens.map(&:type)
        raise "For input '#{input}': expected #{expected_types}, got #{actual_types}" unless actual_types == expected_types
      end
    end
  end

  def test_at_character_error_conditions
    run_test("@ character error conditions (should not error)") do
      # Test various edge cases that previously might have caused issues
      test_cases = [
        '@',         # Single @
        '@@',        # Double @
        '@123',      # @ followed by numbers  
        '@_var',     # @ followed by underscore
        '@ @'        # @ with spaces
      ]
      
      test_cases.each do |input|
        lexer = Lexer.new(input)
        # This should not raise an error anymore
        tokens = lexer.tokenize
        raise "Tokenization failed for input: #{input}" if tokens.empty?
        raise "No EOF token found for input: #{input}" unless tokens.last.type == Token::TOKEN_TYPES[:EOF]
      end
    end
  end

  def run_all_tests
    puts "🧪 Priority 3 Fix: Lexer '@' Character Support Test Suite"
    puts "=" * 60
    
    test_basic_at_character_tokenization
    test_at_character_in_expressions
    test_multiple_at_characters
    test_at_character_with_whitespace
    test_email_like_patterns
    test_mention_like_patterns
    test_at_character_in_complex_expressions
    test_at_character_with_strings
    test_position_tracking_with_at_character
    test_backward_compatibility
    test_at_character_error_conditions
    
    puts "\n📊 Test Results:"
    puts "=" * 30
    puts "Total tests: #{@test_count}"
    puts "Passed: #{@passed_count}"
    puts "Failed: #{@test_count - @passed_count}"
    puts "Success rate: #{((@passed_count.to_f / @test_count) * 100).round(1)}%"
    
    if @failed_tests.any?
      puts "\n❌ Failed tests:"
      @failed_tests.each do |test|
        puts "  - #{test[:name]}: #{test[:error].message}"
      end
    else
      puts "\n🎉 All tests passed! Priority 3 fix is working correctly."
    end
    
    @passed_count == @test_count
  end
end

# Run the tests
if __FILE__ == $0
  tester = Priority3AtCharacterTester.new
  success = tester.run_all_tests
  exit(success ? 0 : 1)
end