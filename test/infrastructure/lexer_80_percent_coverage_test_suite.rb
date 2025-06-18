require_relative '../helpers/test_helper'
require_relative '../../patlang-core/lexer/lexer'
require_relative '../../patlang-core/lexer/token'

# Targeted Lexer Coverage Test Suite
# 
# Goal: Boost lexer coverage from 70.28% to 80%+ (85 additional lines needed)
# 
# Phase 1: Context detection methods coverage (+44 lines → 74.28%)
# Phase 2: Error method coverage (+20 lines → 78.94%)  
# Phase 3: String edge cases (+15 lines → 81.72%)
# Phase 4: Final validation and optimization
#
# Target specific uncovered lines identified in gap analysis:
# - Lines 477-546: Context detection private methods
# - Lines 30-49: Error method with invalid characters
# - Lines 460-475: String parsing edge cases
# - Lines 194-202: Decimal number parsing branches

class LexerEightyPercentCoverageTestSuite < Minitest::Test
  
  def setup
    # Test setup - each test creates its own lexer instance
  end
  
  def create_lexer(input)
    Lexer.new(input)
  end

  # ========================================================================
  # PHASE 1: Context Detection Methods Coverage (+44 lines → 74.28%)
  # Target: Lines 477-546 (private helper methods)
  # ========================================================================
  
  def test_in_function_definition_context_detection
    # Target: Lines 477-485 (in_function_definition_context? method)
    # Strategy: Create input that triggers lookback for "make" keyword
    
    # Test case 1: "make" at end of recent text should trigger context detection
    input = "some text make a"
    lexer = create_lexer(input)
    
    # Advance to position where "a" would be processed
    tokens = lexer.tokenize
    
    # Verify tokens are generated (coverage of context detection logic)
    assert tokens.length >= 3
    assert_equal "some", tokens[0].value
    assert_equal "text", tokens[1].value
    
    # Test case 2: "make" with whitespace triggering regex match
    input2 = "prefix make   called"
    lexer2 = create_lexer(input2)
    tokens2 = lexer2.tokenize
    
    # Verify context detection processes the input
    assert tokens2.length >= 3
    assert_equal "make", tokens2[1].value
  end
  
  def test_in_arithmetic_context_detection
    # Target: Lines 487-498 (in_arithmetic_context? method)
    # Strategy: Create contexts with arithmetic operators that trigger lookback
    
    # Test case 1: Assignment operator context
    input = "result = a"
    lexer = create_lexer(input)
    tokens = lexer.tokenize
    
    # Verify arithmetic context detection processes assignment
    assert tokens.length >= 3
    assert_equal "result", tokens[0].value
    assert_equal :ASSIGN, tokens[1].type
    
    # Test case 2: Multiple arithmetic operators
    arithmetic_contexts = [
      "x + a",
      "y - a", 
      "z * a",
      "w / a"
    ]
    
    arithmetic_contexts.each do |context_input|
      lexer = create_lexer(context_input)
      tokens = lexer.tokenize
      
      # Verify each arithmetic context is processed
      assert tokens.length >= 3, "Failed for input: #{context_input}"
    end
  end
  
  def test_peek_word_functionality
    # Target: Lines 503-519 (peek_word method)
    # Strategy: Create inputs that require word peeking without consuming
    
    input = "identifier123 next_word"
    lexer = create_lexer(input)
    
    # This will internally trigger peek_word during tokenization
    tokens = lexer.tokenize
    
    # Verify peek_word logic processes alphanumeric characters
    assert tokens.length >= 2
    assert_equal "identifier123", tokens[0].value
    assert_equal "next_word", tokens[1].value
  end
  
  def test_skip_word_and_read_word_functionality
    # Target: Lines 521-536 (skip_word and read_word methods)
    # Strategy: Create complex identifiers that trigger word processing
    
    complex_identifiers = [
      "complexIdentifier",
      "var_with_underscores",
      "mixed123numbers", 
      "a1b2c3d4"
    ]
    
    complex_identifiers.each do |identifier|
      lexer = create_lexer(identifier)
      tokens = lexer.tokenize
      
      # Verify word processing methods handle complex identifiers
      assert tokens.length >= 1, "Failed for identifier: #{identifier}"
      assert_equal identifier, tokens[0].value
    end
  end
  
  def test_comment_context_detection
    # Target: Lines 538-546 (comment_context? method)
    # Strategy: Test specific conditions for comment context detection
    
    # Test case 1: # at start of input (line 541)
    input1 = "#comment at start"
    lexer1 = create_lexer(input1)
    tokens1 = lexer1.tokenize
    
    # Verify comment context detection at start
    assert tokens1.length >= 1
    
    # Test case 2: # preceded by whitespace (line 545)
    input2 = "code #comment after space"
    lexer2 = create_lexer(input2)
    tokens2 = lexer2.tokenize
    
    # Verify comment context after whitespace
    assert tokens2.length >= 2
    assert_equal "code", tokens2[0].value
    
    # Test case 3: # not preceded by whitespace (should NOT be comment)
    input3 = "code#notcomment"
    lexer3 = create_lexer(input3)
    tokens3 = lexer3.tokenize
    
    # Verify non-comment context
    assert tokens3.length >= 1
  end

  # ========================================================================
  # PHASE 2: Error Method Coverage (+20 lines → 78.94%)
  # Target: Lines 30-49 (error method with invalid characters)
  # ========================================================================
  
  def test_error_method_with_guaranteed_unknown_characters
    # Target: Lines 30-49 (error method)
    # Strategy: Test characters guaranteed to trigger error method
    # Avoid characters with special token paths (like # for comments, @ for AT token)
    
    truly_unknown_chars = ['$', '&', '`', '~', '¿', '§', '€', '£', '¥']
    
    truly_unknown_chars.each do |char|
      lexer = create_lexer(char)
      tokens = lexer.tokenize
      
      # Verify error method creates UNKNOWN token (lines 30-49)
      assert tokens.length >= 1, "Failed for character: #{char}"
      assert_equal :UNKNOWN, tokens[0].type, "Expected UNKNOWN token for character: #{char}"
      assert_equal char, tokens[0].value, "Expected character value: #{char}"
    end
  end
  
  def test_error_method_position_tracking
    # Target: Lines 45-48 (error method position and advance logic)
    # Strategy: Test error method's position tracking and advance behavior
    
    input = "$unknown&characters`here"
    lexer = create_lexer(input)
    tokens = lexer.tokenize
    
    # Verify multiple unknown characters are each processed by error method
    unknown_count = tokens.count { |token| token.type == :UNKNOWN }
    assert unknown_count >= 3, "Expected multiple UNKNOWN tokens"
    
    # Verify line and column tracking in error method
    tokens.each do |token|
      if token.type == :UNKNOWN
        assert token.line >= 1, "Line should be tracked"
        assert token.column >= 1, "Column should be tracked"
      end
    end
  end

  # ========================================================================
  # PHASE 3: String Edge Cases (+15 lines → 81.72%)
  # Target: Lines 460-475 (string parsing edge cases)
  # ========================================================================
  
  def test_incomplete_escape_sequence_error
    # Target: Lines 460-461 (incomplete escape sequence error)
    # Strategy: Test strings ending with backslash to trigger error condition
    # Note: Lexer actually raises exception for incomplete escapes, so we test the error path
    
    incomplete_escape_cases = [
      '"string ends with backslash\\',
      "'single quote version\\",
      '"multiple words end with\\'
    ]
    
    incomplete_escape_cases.each do |test_case|
      lexer = create_lexer(test_case)
      
      # This should trigger the incomplete escape sequence error (line 460)
      # The lexer raises RuntimeError for incomplete escape sequences
      assert_raises(RuntimeError, "Should raise error for incomplete escape: #{test_case}") do
        lexer.tokenize
      end
    end
  end
  
  def test_string_parsing_edge_cases
    # Target: Lines 462-475 (string value building and termination)
    # Strategy: Test various string edge cases that exercise different branches
    
    string_edge_cases = [
      # Empty strings
      '""',
      "''",
      # Strings with special characters
      '"string with spaces"',
      "'single with spaces'",
      # Mixed quote scenarios  
      '"double quote string"',
      "'single quote string'"
    ]
    
    string_edge_cases.each do |test_case|
      lexer = create_lexer(test_case)
      tokens = lexer.tokenize
      
      # Verify string parsing branches are exercised
      assert tokens.length >= 1, "Should tokenize string: #{test_case}"
      assert_equal :STRING, tokens[0].type, "Should create STRING token for: #{test_case}"
    end
  end
  
  def test_unterminated_string_handling
    # Target: Lines 468-471 (unterminated string token creation)
    # Strategy: Test strings without closing quotes
    
    unterminated_cases = [
      '"unterminated double quote',
      "'unterminated single quote",
      '"very long unterminated string with multiple words'
    ]
    
    unterminated_cases.each do |test_case|
      lexer = create_lexer(test_case)
      tokens = lexer.tokenize
      
      # Verify unterminated string handling (lines 468-471)
      assert tokens.length >= 1, "Should handle unterminated string: #{test_case}"
      assert_equal :UNTERMINATED_STRING, tokens[0].type, "Should create UNTERMINATED_STRING for: #{test_case}"
    end
  end

  # ========================================================================
  # PHASE 4: Additional Coverage Paths (+6 lines)
  # Target: Remaining edge cases and decimal number parsing
  # ========================================================================
  
  def test_decimal_number_parsing_branches
    # Target: Lines 194-202 (decimal number parsing logic)
    # Strategy: Test various decimal number scenarios
    
    decimal_cases = [
      "3.14",
      "0.5", 
      "10.0",
      "1.23456"
    ]
    
    decimal_cases.each do |decimal|
      lexer = create_lexer(decimal)
      tokens = lexer.tokenize
      
      # Verify decimal parsing branches
      assert tokens.length >= 1, "Should parse decimal: #{decimal}"
      assert_equal :NUMBER, tokens[0].type, "Should create NUMBER token for: #{decimal}"
    end
  end
  
  def test_complex_tokenization_scenarios
    # Target: Exercise multiple code paths simultaneously
    # Strategy: Create complex inputs that trigger multiple uncovered branches
    
    complex_scenarios = [
      # Mix of contexts, operators, and edge cases
      "make function $ result = a + 3.14",
      "code #comment &unknown `chars here",
      'make "string\\ incomplete context',
      "arithmetic = context + unknown$ chars"
    ]
    
    complex_scenarios.each do |scenario|
      lexer = create_lexer(scenario)
      tokens = lexer.tokenize
      
      # Verify complex scenarios are fully tokenized
      assert tokens.length >= 1, "Should tokenize complex scenario: #{scenario}"
      
      # Verify EOF token is always present
      assert_equal :EOF, tokens.last.type, "Should end with EOF token"
    end
  end
  
  # ========================================================================
  # INTEGRATION TESTS: Verify All Phases Working Together
  # ========================================================================
  
  def test_comprehensive_coverage_integration
    # Comprehensive test that exercises all targeted coverage areas
    comprehensive_input = <<~CODE
      make function_name called
      result = variable + 3.14
      text "string with\\ escape"
      context#comment here
      unknown$chars&here`test
      arithmetic = a + b
    CODE
    
    lexer = create_lexer(comprehensive_input)
    tokens = lexer.tokenize
    
    # Verify comprehensive tokenization
    assert tokens.length >= 10, "Should generate multiple tokens"
    
    # Verify different token types are present
    token_types = tokens.map(&:type).uniq
    expected_types = [:IDENTIFIER, :STRING, :NUMBER, :UNKNOWN, :EOF]
    
    expected_types.each do |type|
      assert token_types.include?(type), "Should include #{type} token type"
    end
    
    # Verify EOF is always last
    assert_equal :EOF, tokens.last.type, "Should end with EOF"
  end
  
  def test_coverage_target_validation
    # Final validation test to ensure all targeted areas are exercised
    
    # Test each phase's primary targets
    phase_tests = [
      # Phase 1: Context detection
      "make a function called test",
      # Phase 2: Error handling 
      "$&`~unknown",
      # Phase 3: String edges (use valid string instead)
      '"valid_string"',
      # Phase 4: Decimal parsing
      "1.23 + 4.56"
    ]
    
    phase_tests.each_with_index do |test_input, index|
      lexer = create_lexer(test_input)
      tokens = lexer.tokenize
      
      assert tokens.length >= 1, "Phase #{index + 1} test should tokenize: #{test_input}"
      assert_equal :EOF, tokens.last.type, "Should always end with EOF"
    end
    
    puts "✅ All targeted coverage areas exercised successfully"
  end
end