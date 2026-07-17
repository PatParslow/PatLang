# frozen_string_literal: true

module Patlang
  module Lexer
    # Token type constants - single source of truth
    module TokenType
      # Literals
      INTEGER_LITERAL = :INTEGER_LITERAL
      FLOAT_LITERAL   = :FLOAT_LITERAL
      STRING_LITERAL  = :STRING_LITERAL
      
      # Keywords - context-sensitive
      MAKE_KEYWORD       = :MAKE_KEYWORD
      ARTICLE            = :ARTICLE             # 'a', 'an'
      FUNCTION_KW        = :FUNCTION_KW
      CLASS_KW           = :CLASS_KW
      TEMPLATE_KW        = :TEMPLATE_KW
      GOAL_KW            = :GOAL_KW
      LIST_KW            = :LIST_KW
      TYPE_KW            = :TYPE_KW             # number, text, boolean, etc.
      DECL_TYPE          = :DECL_TYPE           # unified declaration type
      
      CALLED     = :CALLED
      COMPLETED  = :COMPLETED
      ERROR_KEYWORD = :ERROR_KEYWORD
      CHANGED    = :CHANGED
      ACTIVATED  = :ACTIVATED
      WHEN_KEYWORD       = :WHEN_KEYWORD
      IF_KW              = :IF_KW
      THEN_KEYWORD       = :THEN_KEYWORD
      ELSIF_KEYWORD      = :ELSIF_KEYWORD
      ELSE_KEYWORD       = :ELSE_KEYWORD
      END_KEYWORD        = :END_KEYWORD
      BEGIN_KEYWORD      = :BEGIN_KEYWORD
      
      IS_KEYWORD         = :IS_KEYWORD
      BECOMES_KEYWORD    = :BECOMES_KEYWORD
      IS_NOT_KEYWORD     = :IS_NOT_KEYWORD
      AND_KEYWORD        = :AND_KEYWORD
      OR_KEYWORD         = :OR_KEYWORD
      NOT_KEYWORD        = :NOT_KEYWORD
      
      TAKES_KEYWORD      = :TAKES_KEYWORD
      RETURNS_KEYWORD    = :RETURNS_KEYWORD
      REQUIRES_KEYWORD   = :REQUIRES_KEYWORD
      ENSURES_KEYWORD    = :ENSURES_KEYWORD
      MAINTAINS_KEYWORD  = :MAINTAINS_KEYWORD
      ACHIEVED_KEYWORD   = :ACHIEVED_KEYWORD
      RUNS_KEYWORD       = :RUNS_KEYWORD
      
      ACTIVATE_KEYWORD   = :ACTIVATE_KEYWORD
      WITH_KEYWORD       = :WITH_KEYWORD
      QUERY_KEYWORD      = :QUERY_KEYWORD
      ASSERT_KEYWORD     = :ASSERT_KEYWORD
      RETURN_KEYWORD     = :RETURN_KEYWORD
      
      TRUE_KEYWORD       = :TRUE_KEYWORD
      FALSE_KEYWORD      = :FALSE_KEYWORD
      NIL_KEYWORD        = :NIL_KEYWORD
      
      # Operators
      PLUS     = :PLUS
      MINUS    = :MINUS
      STAR     = :STAR
      SLASH    = :SLASH
      PERCENT  = :PERCENT
      EQ       = :EQ
      NEQ      = :NEQ
      LT       = :LT
      GT       = :GT
      LTE      = :LTE
      GTE      = :GTE
      ARROW    = :ARROW      # =>
      SEND_ARROW = :SEND_ARROW  # ->
      PIPE     = :PIPE       # |
      
      # Delimiters
      LPAREN      = :LPAREN
      RPAREN      = :RPAREN
      LBRACE      = :LBRACE
      RBRACE      = :RBRACE
      LBRACKET    = :LBRACKET
      RBRACKET    = :RBRACKET
      COMMA       = :COMMA
      DOT         = :DOT
      COLON       = :COLON
      SEMICOLON   = :SEMICOLON
      
      # Event-related
      EVENT_ACTION_SPECIFIER = :EVENT_ACTION_SPECIFIER  # ':'
      EVENT_ACTION_KW        = :EVENT_ACTION_KW         # called, completed, error, changed, activated
      
      # Control flow
      WHILE_KEYWORD     = :WHILE_KEYWORD
      FOR_KEYWORD       = :FOR_KEYWORD
      IN_KEYWORD        = :IN_KEYWORD
      DO_KEYWORD        = :DO_KEYWORD
      RANGE_KEYWORD     = :RANGE_KEYWORD
      IMPORT_KEYWORD    = :IMPORT_KEYWORD
      
      # Async/concurrency
      ASYNC_KEYWORD      = :ASYNC_KEYWORD
      AWAIT_KEYWORD      = :AWAIT_KEYWORD
      CHANNEL_KEYWORD    = :CHANNEL_KEYWORD
      ACTOR_KEYWORD      = :ACTOR_KEYWORD
      RECEIVE_KEYWORD    = :RECEIVE_KEYWORD
      SELECT_KEYWORD     = :SELECT_KEYWORD
      MUTEX_KEYWORD      = :MUTEX_KEYWORD
      LOCK_KEYWORD       = :LOCK_KEYWORD
      UNLOCK_KEYWORD     = :UNLOCK_KEYWORD
      
      # Block-related
      BLOCK_START       = :BLOCK_START       # '{'
      BLOCK_END         = :BLOCK_END         # '}'
      BLOCK_PARAM_START = :BLOCK_PARAM_START # '|'
      BLOCK_PARAM_END   = :BLOCK_PARAM_END   # '|'
      
      # Other
      IDENTIFIER       = :IDENTIFIER
      NEWLINE          = :NEWLINE
      EOF              = :EOF
      BASIS_KEYWORD    = :BASIS_KEYWORD
      
      def self.all
        constants.map { |c| const_get(c) }
      end
    end
    
    class LexerError < StandardError; end
    
    # Token data structure
    Token = Struct.new(:type, :value, :line, :column, keyword_init: true) do
      def to_s
        "#<Token #{type} #{value.inspect} @#{line}:#{column}>"
      end
      
      def inspect
        to_s
      end
    end
  end
end