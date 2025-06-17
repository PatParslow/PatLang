# frozen_string_literal: true

require_relative '../helpers/test_helper'

class TestTokenResolver < Minitest::Test
  def setup
    # Create token resolver with sample tokens
    @sample_tokens = [
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'test', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:ASSIGN], '=', 1, 1, 6),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 42, 2, 1, 8),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 3, 1, 10)
    ]
    @token_resolver = ParserModules::TokenResolver.new(@sample_tokens)
  end

  # Test basic token resolver functionality
  def test_token_resolver_initialization
    assert_not_nil @token_resolver
    assert_respond_to @token_resolver, :peek_ahead
    assert_respond_to @token_resolver, :resolve_ambiguous_token
    assert_respond_to @token_resolver, :is_function_definition_start?
    assert_respond_to @token_resolver, :is_function_call_start?
  end

  # Test peek ahead functionality
  def test_peek_ahead_basic
    # Should be able to peek ahead from different positions
    result = @token_resolver.peek_ahead(0, 1)
    assert_not_nil result
    assert_equal @sample_tokens[1], result
    
    result = @token_resolver.peek_ahead(0, 2)
    assert_not_nil result
    assert_equal @sample_tokens[2], result
  end

  def test_peek_ahead_boundary_conditions
    # Test peeking beyond token array
    result = @token_resolver.peek_ahead(0, 10)
    assert_nil result
    
    # Test peeking from invalid position
    result = @token_resolver.peek_ahead(10, 1)
    assert_nil result
    
    # Test negative positions
    result = @token_resolver.peek_ahead(-1, 1)
    assert_nil result
  end

  def test_peek_ahead_edge_cases
    # Test peeking with zero distance
    result = @token_resolver.peek_ahead(0, 0)
    assert_equal @sample_tokens[0], result
    
    # Test peeking from last token
    result = @token_resolver.peek_ahead(@sample_tokens.length - 1, 1)
    assert_nil result
  end

  # Test ambiguous token resolution
  def test_resolve_ambiguous_token_article_vs_identifier
    # Create ambiguous token 'a' that could be article or identifier
    ambiguous_tokens = [
      AmbiguousToken.new('a', :A, :IDENTIFIER, 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'function', 1, 1, 3),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 2, 1, 11)
    ]
    
    resolver = ParserModules::TokenResolver.new(ambiguous_tokens)
    
    # Should resolve 'a' as article when followed by 'function'
    result = resolver.resolve_ambiguous_token(0)
    assert_equal :A, result
  end

  def test_resolve_ambiguous_token_without_following_context
    # Create ambiguous token without helpful context
    ambiguous_tokens = [
      AmbiguousToken.new('a', :A, :IDENTIFIER, 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 42, 1, 1, 3),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 2, 1, 5)
    ]
    
    resolver = ParserModules::TokenResolver.new(ambiguous_tokens)
    
    # Should default to identifier when context is unclear
    result = resolver.resolve_ambiguous_token(0)
    assert_equal :IDENTIFIER, result
  end

  def test_resolve_ambiguous_token_with_non_ambiguous_token
    # Should return original type for non-ambiguous tokens
    result = @token_resolver.resolve_ambiguous_token(0)  # 'test' identifier
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], result
    
    result = @token_resolver.resolve_ambiguous_token(1)  # '=' assign
    assert_equal Token::TOKEN_TYPES[:ASSIGN], result
  end

  def test_resolve_ambiguous_token_at_invalid_position
    # Should handle invalid positions gracefully
    result = @token_resolver.resolve_ambiguous_token(-1)
    assert_nil result
    
    result = @token_resolver.resolve_ambiguous_token(100)
    assert_nil result
  end

  # Test function definition detection
  def test_is_function_definition_start_classic_syntax
    # Test classic "make a function called" syntax
    func_def_tokens = [
      Token.new(Token::TOKEN_TYPES[:MAKE], 'make', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:A], 'a', 1, 1, 6),
      Token.new(Token::TOKEN_TYPES[:FUNCTION], 'function', 2, 1, 8),
      Token.new(Token::TOKEN_TYPES[:CALLED], 'called', 3, 1, 17),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'test', 4, 1, 24),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 5, 1, 28)
    ]
    
    resolver = ParserModules::TokenResolver.new(func_def_tokens)
    
    assert resolver.is_function_definition_start?(0)
  end

  def test_is_function_definition_start_flexible_syntax
    # Test flexible "make function" syntax
    func_def_tokens = [
      Token.new(Token::TOKEN_TYPES[:MAKE], 'make', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:FUNCTION], 'function', 1, 1, 6),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'test', 2, 1, 15),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 3, 1, 19)
    ]
    
    resolver = ParserModules::TokenResolver.new(func_def_tokens)
    
    assert resolver.is_function_definition_start?(0)
  end

  def test_is_function_definition_start_with_ambiguous_article
    # Test with ambiguous 'a' token
    func_def_tokens = [
      Token.new(Token::TOKEN_TYPES[:MAKE], 'make', 0, 1, 1),
      AmbiguousToken.new('a', :A, :IDENTIFIER, 1, 1, 6),
      Token.new(Token::TOKEN_TYPES[:FUNCTION], 'function', 2, 1, 8),
      Token.new(Token::TOKEN_TYPES[:CALLED], 'called', 3, 1, 17),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'test', 4, 1, 24),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 5, 1, 28)
    ]
    
    resolver = ParserModules::TokenResolver.new(func_def_tokens)
    
    assert resolver.is_function_definition_start?(0)
  end

  def test_is_function_definition_start_false_cases
    # Test cases that should not be function definitions
    
    # Just "make" without function
    make_only_tokens = [
      Token.new(Token::TOKEN_TYPES[:MAKE], 'make', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'variable', 1, 1, 6),
      Token.new(Token::TOKEN_TYPES[:ASSIGN], '=', 2, 1, 15),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 3, 1, 17)
    ]
    
    resolver = ParserModules::TokenResolver.new(make_only_tokens)
    assert_not resolver.is_function_definition_start?(0)
    
    # Starting with different token
    non_make_tokens = [
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'variable', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:ASSIGN], '=', 1, 1, 9),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 2, 1, 11)
    ]
    
    resolver = ParserModules::TokenResolver.new(non_make_tokens)
    assert_not resolver.is_function_definition_start?(0)
  end

  def test_is_function_definition_start_at_invalid_position
    # Should handle invalid positions gracefully
    assert_not @token_resolver.is_function_definition_start?(-1)
    assert_not @token_resolver.is_function_definition_start?(100)
  end

  # Test function call detection
  def test_is_function_call_start_basic
    # Test basic "call function_name" syntax
    func_call_tokens = [
      Token.new(Token::TOKEN_TYPES[:CALL], 'call', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'test_function', 1, 1, 6),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 2, 1, 19)
    ]
    
    resolver = ParserModules::TokenResolver.new(func_call_tokens)
    
    assert resolver.is_function_call_start?(0)
  end

  def test_is_function_call_start_with_arguments
    # Test function call with "with" keyword for arguments
    func_call_tokens = [
      Token.new(Token::TOKEN_TYPES[:CALL], 'call', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'test_function', 1, 1, 6),
      Token.new(Token::TOKEN_TYPES[:WITH], 'with', 2, 1, 19),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 42, 3, 1, 24),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 4, 1, 26)
    ]
    
    resolver = ParserModules::TokenResolver.new(func_call_tokens)
    
    assert resolver.is_function_call_start?(0)
  end

  def test_is_function_call_start_false_cases
    # Test cases that should not be function calls
    
    # Just "call" without identifier
    call_only_tokens = [
      Token.new(Token::TOKEN_TYPES[:CALL], 'call', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 42, 1, 1, 6),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 2, 1, 8)
    ]
    
    resolver = ParserModules::TokenResolver.new(call_only_tokens)
    assert_not resolver.is_function_call_start?(0)
    
    # Starting with different token
    non_call_tokens = [
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'variable', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:ASSIGN], '=', 1, 1, 9),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 2, 1, 11)
    ]
    
    resolver = ParserModules::TokenResolver.new(non_call_tokens)
    assert_not resolver.is_function_call_start?(0)
  end

  def test_is_function_call_start_at_invalid_position
    # Should handle invalid positions gracefully
    assert_not @token_resolver.is_function_call_start?(-1)
    assert_not @token_resolver.is_function_call_start?(100)
  end

  # Test complex token resolution scenarios
  def test_complex_ambiguous_token_resolution_scenario
    # Create complex scenario with multiple ambiguous tokens
    complex_tokens = [
      Token.new(Token::TOKEN_TYPES[:MAKE], 'make', 0, 1, 1),
      AmbiguousToken.new('a', :A, :IDENTIFIER, 1, 1, 6),
      Token.new(Token::TOKEN_TYPES[:FUNCTION], 'function', 2, 1, 8),
      Token.new(Token::TOKEN_TYPES[:CALLED], 'called', 3, 1, 17),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'test', 4, 1, 24),
      Token.new(Token::TOKEN_TYPES[:LBRACE], '{', 5, 1, 29),
      Token.new(Token::TOKEN_TYPES[:RETURN], 'return', 6, 1, 31),
      AmbiguousToken.new('a', :A, :IDENTIFIER, 7, 1, 38),
      Token.new(Token::TOKEN_TYPES[:RBRACE], '}', 8, 1, 40),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 9, 1, 41)
    ]
    
    resolver = ParserModules::TokenResolver.new(complex_tokens)
    
    # First 'a' should resolve as article (in function definition)
    result1 = resolver.resolve_ambiguous_token(1)
    assert_equal :A, result1
    
    # Second 'a' should resolve as identifier (in expression context)
    result2 = resolver.resolve_ambiguous_token(7)
    assert_equal :IDENTIFIER, result2
  end

  def test_token_resolver_performance_with_large_token_stream
    # Test performance with large token stream
    large_tokens = []
    
    # Create large token stream
    1000.times do |i|
      large_tokens << Token.new(Token::TOKEN_TYPES[:IDENTIFIER], "var#{i}", i * 3, 1, i * 3 + 1)
      large_tokens << Token.new(Token::TOKEN_TYPES[:ASSIGN], '=', i * 3 + 1, 1, i * 3 + 5)
      large_tokens << Token.new(Token::TOKEN_TYPES[:NUMBER], i, i * 3 + 2, 1, i * 3 + 7)
    end
    large_tokens << Token.new(Token::TOKEN_TYPES[:EOF], nil, 3000, 1, 3001)
    
    resolver = ParserModules::TokenResolver.new(large_tokens)
    
    start_time = Time.now
    
    # Perform many peek operations
    100.times do |i|
      resolver.peek_ahead(i * 10, 5)
    end
    
    # Test function detection on various positions
    (0...100).step(10) do |i|
      resolver.is_function_definition_start?(i)
      resolver.is_function_call_start?(i)
    end
    
    elapsed = Time.now - start_time
    assert_operator elapsed, :<, 1.0, "Token resolver should be fast with large token streams"
  end

  def test_token_resolver_memory_efficiency
    # Test memory efficiency
    original_resolver_count = ObjectSpace.each_object(ParserModules::TokenResolver).count
    
    # Create many resolvers
    resolvers = []
    50.times do |i|
      tokens = [
        Token.new(Token::TOKEN_TYPES[:IDENTIFIER], "test#{i}", 0, 1, 1),
        Token.new(Token::TOKEN_TYPES[:EOF], nil, 1, 1, 10)
      ]
      resolvers << ParserModules::TokenResolver.new(tokens)
    end
    
    # Use resolvers
    resolvers.each_with_index do |resolver, i|
      resolver.peek_ahead(0, 1)
      resolver.resolve_ambiguous_token(0)
    end
    
    # Clear references
    resolvers = nil
    GC.start
    
    new_resolver_count = ObjectSpace.each_object(ParserModules::TokenResolver).count
    
    # Should not have excessive resolver objects
    assert_operator new_resolver_count - original_resolver_count, :<=, 60
  end

  # Test edge cases and error handling
  def test_token_resolver_with_empty_token_stream
    empty_resolver = ParserModules::TokenResolver.new([])
    
    # Should handle empty token stream gracefully
    assert_nil empty_resolver.peek_ahead(0, 1)
    assert_nil empty_resolver.resolve_ambiguous_token(0)
    assert_not empty_resolver.is_function_definition_start?(0)
    assert_not empty_resolver.is_function_call_start?(0)
  end

  def test_token_resolver_with_single_token
    single_token = [Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'test', 0, 1, 1)]
    resolver = ParserModules::TokenResolver.new(single_token)
    
    # Should handle single token gracefully
    assert_nil resolver.peek_ahead(0, 1)
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], resolver.resolve_ambiguous_token(0)
    assert_not resolver.is_function_definition_start?(0)
    assert_not resolver.is_function_call_start?(0)
  end

  def test_token_resolver_boundary_conditions
    # Test various boundary conditions
    boundary_tokens = [
      Token.new(Token::TOKEN_TYPES[:MAKE], 'make', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 1, 1, 5)
    ]
    
    resolver = ParserModules::TokenResolver.new(boundary_tokens)
    
    # Should handle incomplete function definitions
    assert_not resolver.is_function_definition_start?(0)
    
    # Should handle EOF gracefully
    assert_equal Token::TOKEN_TYPES[:EOF], resolver.resolve_ambiguous_token(1)
    assert_nil resolver.peek_ahead(1, 1)
  end

  def test_token_resolver_with_malformed_tokens
    # Test with tokens that might have unusual properties
    malformed_tokens = [
      Token.new(Token::TOKEN_TYPES[:UNKNOWN], '$', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], '', 1, 1, 2),  # Empty identifier
      Token.new(nil, 'test', 2, 1, 3),  # Nil type
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 3, 1, 7)
    ]
    
    resolver = ParserModules::TokenResolver.new(malformed_tokens)
    
    # Should handle malformed tokens without crashing
    assert_nothing_raised do
      resolver.peek_ahead(0, 1)
      resolver.resolve_ambiguous_token(0)
      resolver.is_function_definition_start?(0)
      resolver.is_function_call_start?(0)
    end
  end

  def test_token_resolver_concurrent_access
    # Test thread safety simulation
    threads = []
    results = []
    
    10.times do |i|
      threads << Thread.new do
        local_tokens = [
          Token.new(Token::TOKEN_TYPES[:IDENTIFIER], "test#{i}", 0, 1, 1),
          Token.new(Token::TOKEN_TYPES[:ASSIGN], '=', 1, 1, 6),
          Token.new(Token::TOKEN_TYPES[:NUMBER], i, 2, 1, 8),
          Token.new(Token::TOKEN_TYPES[:EOF], nil, 3, 1, 10)
        ]
        
        resolver = ParserModules::TokenResolver.new(local_tokens)
        
        # Perform operations
        result = resolver.peek_ahead(0, 1)
        type = resolver.resolve_ambiguous_token(0)
        is_func_def = resolver.is_function_definition_start?(0)
        is_func_call = resolver.is_function_call_start?(0)
        
        results << {
          thread_id: i,
          peek_result: result,
          type: type,
          is_func_def: is_func_def,
          is_func_call: is_func_call
        }
      end
    end
    
    threads.each(&:join)
    
    # All threads should complete successfully
    assert_equal 10, results.length
    results.each do |result|
      assert_not_nil result[:peek_result]
      assert_not_nil result[:type]
      assert_not_nil result[:is_func_def]  # Can be false
      assert_not_nil result[:is_func_call] # Can be false
    end
  end

  def test_token_resolver_state_consistency
    # Test that token resolver maintains consistent state
    original_tokens = @token_resolver.instance_variable_get(:@tokens)
    
    # Perform various operations
    @token_resolver.peek_ahead(0, 1)
    @token_resolver.resolve_ambiguous_token(0)
    @token_resolver.is_function_definition_start?(0)
    @token_resolver.is_function_call_start?(0)
    
    # Token array should remain unchanged
    final_tokens = @token_resolver.instance_variable_get(:@tokens)
    assert_equal original_tokens, final_tokens
  end

  def test_token_resolver_integration_with_parser
    # Test integration scenarios that would occur during parsing
    integration_tokens = [
      Token.new(Token::TOKEN_TYPES[:MAKE], 'make', 0, 1, 1),
      AmbiguousToken.new('a', :A, :IDENTIFIER, 1, 1, 6),
      Token.new(Token::TOKEN_TYPES[:FUNCTION], 'function', 2, 1, 8),
      Token.new(Token::TOKEN_TYPES[:CALLED], 'called', 3, 1, 17),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'test', 4, 1, 24),
      Token.new(Token::TOKEN_TYPES[:LBRACE], '{', 5, 1, 29),
      Token.new(Token::TOKEN_TYPES[:CALL], 'call', 6, 1, 31),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'helper', 7, 1, 36),
      Token.new(Token::TOKEN_TYPES[:RBRACE], '}', 8, 1, 42),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 9, 1, 43)
    ]
    
    resolver = ParserModules::TokenResolver.new(integration_tokens)
    
    # Should correctly identify function definition
    assert resolver.is_function_definition_start?(0)
    
    # Should correctly resolve ambiguous 'a'
    assert_equal :A, resolver.resolve_ambiguous_token(1)
    
    # Should correctly identify function call within body
    assert resolver.is_function_call_start?(6)
    
    # Should be able to peek ahead for parser lookahead
    next_token = resolver.peek_ahead(6, 1)
    assert_equal integration_tokens[7], next_token
  end
end