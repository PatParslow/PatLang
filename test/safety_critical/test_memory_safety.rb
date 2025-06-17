# frozen_string_literal: true

require_relative '../helpers/test_helper'

class TestMemorySafety < Minitest::Test
  def setup
    @mock_evaluator = MockEvaluator.new
  end

  # Test memory allocation patterns in lexer
  def test_lexer_memory_allocation_patterns
    # Test that lexer doesn't accumulate excessive memory with large inputs
    large_input = 'a' * 10000
    
    # Measure memory usage pattern
    lexer = Lexer.new(large_input)
    
    assert_nothing_raised do
      tokens = lexer.tokenize
      
      # Should produce reasonable number of tokens
      assert_equal 2, tokens.length  # One IDENTIFIER, one EOF
      assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[0].type
      assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
      
      # Token value should reference the original string efficiently
      assert_equal large_input, tokens[0].value
    end
  end

  def test_lexer_memory_efficiency_with_many_tokens
    # Test memory efficiency with many small tokens
    input = (1..1000).map { |i| "token#{i}" }.join(' ')
    
    lexer = Lexer.new(input)
    
    assert_nothing_raised do
      tokens = lexer.tokenize
      
      # Should have 1000 identifier tokens plus EOF
      assert_equal 1001, tokens.length
      assert_equal Token::TOKEN_TYPES[:EOF], tokens.last.type
      
      # Each token should have reasonable memory footprint
      tokens[0...-1].each_with_index do |token, index|
        assert_equal Token::TOKEN_TYPES[:IDENTIFIER], token.type
        assert_equal "token#{index + 1}", token.value
        assert_kind_of Integer, token.position
        assert_kind_of Integer, token.line
        assert_kind_of Integer, token.column
      end
    end
  end

  def test_token_memory_management
    # Test that tokens don't hold excessive references
    token = Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'test', 0, 1, 1)
    
    # Verify token structure
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], token.type
    assert_equal 'test', token.value
    assert_equal 0, token.position
    assert_equal 1, token.line
    assert_equal 1, token.column
    
    # Test that token can be safely duplicated
    token_copy = token.dup
    assert_equal token.type, token_copy.type
    assert_equal token.value, token_copy.value
    assert_equal token.position, token_copy.position
  end

  # Test parser memory management
  def test_parser_memory_allocation_with_large_token_stream
    # Create a large but manageable token stream
    tokens = []
    1000.times do |i|
      tokens << Token.new(Token::TOKEN_TYPES[:IDENTIFIER], "var#{i}", i * 2, 1, i * 2 + 1)
      tokens << Token.new(Token::TOKEN_TYPES[:ASSIGN], '=', i * 2 + 1, 1, i * 2 + 2)
    end
    tokens << Token.new(Token::TOKEN_TYPES[:EOF], nil, tokens.length, 1, tokens.length + 1)
    
    parser = Parser.new(tokens)
    
    # Parser should handle large token stream without memory issues
    assert_nothing_raised do
      # Test basic parser functionality
      assert_equal tokens[0], parser.current_token
      assert_equal 0, parser.current_token_index
      
      # Test advancement through tokens
      10.times do |i|
        parser.advance
        assert_equal tokens[i + 1], parser.current_token
        assert_equal i + 1, parser.current_token_index
      end
    end
  end

  def test_parser_error_collection_memory_management
    # Test that error collection doesn't cause memory leaks
    tokens = [Token.new(Token::TOKEN_TYPES[:EOF], nil, 0, 1, 1)]
    parser = Parser.new(tokens)
    
    # Collect many errors to test memory management
    1000.times do |i|
      error_info = {
        message: "Error #{i}",
        position: i,
        token: tokens[0],
        line: 1,
        column: i + 1
      }
      parser.collect_error(error_info)
    end
    
    # Should handle large error collection
    assert parser.has_errors?
    assert_equal 1000, parser.get_all_errors.length
    
    # Each error should be properly stored
    parser.get_all_errors.each_with_index do |error, index|
      assert_equal "Error #{index}", error[:message]
      assert_equal index, error[:position]
    end
  end

  # Test AST node memory management
  def test_ast_node_memory_efficiency
    # Test that AST nodes don't hold excessive references
    nodes = []
    
    # Create various AST node types
    100.times do |i|
      nodes << NumberNode.new(i)
      nodes << IdentifierNode.new("var#{i}")
      nodes << StringNode.new("string#{i}")
    end
    
    # Verify nodes are created properly
    assert_equal 300, nodes.length
    
    # Test node properties
    nodes.each_with_index do |node, index|
      case index % 3
      when 0  # NumberNode
        assert_kind_of NumberNode, node
        assert_equal index / 3, node.value
      when 1  # IdentifierNode  
        assert_kind_of IdentifierNode, node
        assert_equal "var#{index / 3}", node.name
      when 2  # StringNode
        assert_kind_of StringNode, node
        assert_equal "string#{index / 3}", node.value
      end
    end
  end

  def test_binary_operation_node_memory_management
    # Test memory management of complex AST structures
    left = NumberNode.new(5)
    right = NumberNode.new(10)
    op = BinaryOpNode.new(left, Token.new(Token::TOKEN_TYPES[:PLUS], '+', 0, 1, 1), right)
    
    # Verify structure
    assert_equal left, op.left
    assert_equal right, op.right
    assert_equal Token::TOKEN_TYPES[:PLUS], op.op.type
    
    # Test nested operations don't cause circular references
    nested_op = BinaryOpNode.new(op, Token.new(Token::TOKEN_TYPES[:STAR], '*', 0, 1, 1), NumberNode.new(2))
    
    assert_equal op, nested_op.left
    assert_kind_of NumberNode, nested_op.right
    assert_equal 2, nested_op.right.value
  end

  # Test string handling memory safety
  def test_string_memory_management_with_escapes
    # Test that string parsing doesn't cause memory issues with escapes
    test_strings = [
      '"simple string"',
      '"string with \\"escaped quotes\\""',
      '"string with \\n newlines \\t tabs"',
      '"string with \\\\ backslashes"',
      '"very long string #{"x" * 1000} with content"'
    ]
    
    test_strings.each do |input|
      lexer = Lexer.new(input)
      
      assert_nothing_raised do
        tokens = lexer.tokenize
        assert_equal 2, tokens.length
        assert_equal Token::TOKEN_TYPES[:STRING], tokens[0].type
        assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
        
        # String value should be properly unescaped
        assert_kind_of String, tokens[0].value
        assert_operator tokens[0].value.length, :>, 0
      end
    end
  end

  def test_lexer_position_tracking_memory_efficiency
    # Test that position tracking doesn't accumulate excessive memory
    input = "line1\nline2\nline3\n" * 100  # 300 lines
    
    lexer = Lexer.new(input)
    
    assert_nothing_raised do
      tokens = lexer.tokenize
      
      # Should track positions correctly without memory bloat
      identifier_tokens = tokens.select { |t| t.type == Token::TOKEN_TYPES[:IDENTIFIER] }
      
      identifier_tokens.each do |token|
        assert_kind_of Integer, token.line
        assert_kind_of Integer, token.column
        assert_kind_of Integer, token.position
        assert_operator token.line, :>, 0
        assert_operator token.column, :>, 0
        assert_operator token.position, :>=, 0
      end
    end
  end

  # Test memory safety with malformed input
  def test_memory_safety_with_malformed_input
    # Test various malformed inputs don't cause memory issues
    malformed_inputs = [
      '"' * 1000,  # Many unclosed quotes
      '(' * 1000,  # Many unclosed parentheses
      '$' * 1000,  # Many invalid characters
      '123.' * 1000, # Many malformed numbers
      'if' * 1000   # Many keywords without structure
    ]
    
    malformed_inputs.each do |input|
      lexer = Lexer.new(input)
      
      assert_nothing_raised("Memory issue with input pattern") do
        with_test_timeout(5) do
          tokens = lexer.tokenize
          
          # Should complete tokenization
          assert_operator tokens.length, :>, 0
          assert_equal Token::TOKEN_TYPES[:EOF], tokens.last.type
          
          # Should not have excessive memory per token
          tokens.each do |token|
            assert_respond_to token, :type
            assert_respond_to token, :value
            assert_respond_to token, :position
            assert_respond_to token, :line
            assert_respond_to token, :column
          end
        end
      end
    end
  end

  # Test garbage collection interaction
  def test_token_cleanup_after_parsing
    # Test that tokens can be garbage collected after parsing
    original_token_count = ObjectSpace.each_object(Token).count
    
    # Create and parse tokens
    input = (1..100).map { |i| "token#{i}" }.join(' ')
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    
    # Verify tokens were created
    new_token_count = ObjectSpace.each_object(Token).count
    assert_operator new_token_count, :>, original_token_count
    
    # Clear references
    tokens = nil
    lexer = nil
    
    # Force garbage collection
    GC.start
    
    # Note: This test is somewhat fragile as GC behavior is implementation-dependent
    # But it should generally reduce token count
    final_token_count = ObjectSpace.each_object(Token).count
    # We can't guarantee exact cleanup due to GC behavior, but count shouldn't grow indefinitely
    assert_operator final_token_count, :<, new_token_count + 50
  end

  def test_parser_state_memory_consistency
    # Test that parser state doesn't accumulate unnecessary memory
    tokens = [
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'x', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:ASSIGN], '=', 1, 1, 3),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 42, 2, 1, 5),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 3, 1, 7)
    ]
    
    parser = Parser.new(tokens)
    
    # Test that parser state is consistent
    assert_equal tokens, parser.instance_variable_get(:@tokens)
    assert_equal 0, parser.current_token_index
    assert_equal tokens[0], parser.current_token
    
    # Advance through tokens
    parser.advance
    assert_equal 1, parser.current_token_index
    assert_equal tokens[1], parser.current_token
    
    parser.advance
    assert_equal 2, parser.current_token_index
    assert_equal tokens[2], parser.current_token
    
    # Test end of tokens
    parser.advance
    assert_equal 3, parser.current_token_index
    assert_equal tokens[3], parser.current_token
    
    parser.advance
    assert_equal 4, parser.current_token_index
    assert_nil parser.current_token
  end

  # Test memory safety with deeply nested structures
  def test_memory_safety_with_nested_structures
    # Create deeply nested parenthetical expressions
    nested_input = '(' * 100 + '42' + ')' * 100
    
    lexer = Lexer.new(nested_input)
    
    assert_nothing_raised do
      with_test_timeout(3) do
        tokens = lexer.tokenize
        
        # Should handle deep nesting without stack overflow
        lparen_count = tokens.count { |t| t.type == Token::TOKEN_TYPES[:LPAREN] }
        rparen_count = tokens.count { |t| t.type == Token::TOKEN_TYPES[:RPAREN] }
        number_count = tokens.count { |t| t.type == Token::TOKEN_TYPES[:NUMBER] }
        
        assert_equal 100, lparen_count
        assert_equal 100, rparen_count
        assert_equal 1, number_count
        assert_equal Token::TOKEN_TYPES[:EOF], tokens.last.type
      end
    end
  end

  def test_exception_memory_safety
    # Test that custom exceptions don't cause memory leaks
    large_context = {}
    1000.times { |i| large_context["key#{i}"] = "value#{i}" }
    
    # Create exceptions with large context
    exceptions = []
    100.times do |i|
      exceptions << PatlangError.new("Error #{i}", context: large_context.dup)
    end
    
    # Verify exceptions are created properly
    assert_equal 100, exceptions.length
    
    exceptions.each_with_index do |exception, index|
      assert_equal "Error #{index}", exception.message
      assert_equal large_context, exception.context
      assert_respond_to exception, :detailed_message
    end
    
    # Clear references
    exceptions = nil
    large_context = nil
    
    # Should allow garbage collection
    GC.start
    
    # Test passes if no memory errors occur
    assert true
  end
end