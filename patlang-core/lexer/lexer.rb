# frozen_string_literal: true

require_relative 'token'

module Patlang
  module Lexer
    # Expectation-driven lexer - incremental API for parser
    class Lexer
      # Keyword tables for disambiguation
      KEYWORDS = {
        'make' => TokenType::MAKE_KEYWORD,
        'a' => TokenType::ARTICLE,
        'an' => TokenType::ARTICLE,
        'function' => TokenType::FUNCTION_KW,
        'class' => TokenType::CLASS_KW,
        'template' => TokenType::TEMPLATE_KW,
        'goal' => TokenType::GOAL_KW,
        'list' => TokenType::LIST_KW,
        'number' => TokenType::TYPE_KW,
        'text' => TokenType::TYPE_KW,
        'boolean' => TokenType::TYPE_KW,
        'called' => TokenType::CALLED,
        'completed' => TokenType::COMPLETED,
        'error' => TokenType::ERROR_KEYWORD,
        'changed' => TokenType::CHANGED,
        'activated' => TokenType::ACTIVATED,
        'when' => TokenType::WHEN_KEYWORD,
        'if' => TokenType::IF_KW,
        'then' => TokenType::THEN_KEYWORD,
        'elsif' => TokenType::ELSIF_KEYWORD,
        'else' => TokenType::ELSE_KEYWORD,
        'end' => TokenType::END_KEYWORD,
        'begin' => TokenType::BEGIN_KEYWORD,
        'is' => TokenType::IS_KEYWORD,
        'becomes' => TokenType::BECOMES_KEYWORD,
        'is not' => TokenType::IS_NOT_KEYWORD,
        'not' => TokenType::NOT_KEYWORD,
        'and' => TokenType::AND_KEYWORD,
        'or' => TokenType::OR_KEYWORD,
        'takes' => TokenType::TAKES_KEYWORD,
        'returns' => TokenType::RETURNS_KEYWORD,
        'requires' => TokenType::REQUIRES_KEYWORD,
        'ensures' => TokenType::ENSURES_KEYWORD,
        'maintains' => TokenType::MAINTAINS_KEYWORD,
        'achieved' => TokenType::ACHIEVED_KEYWORD,
        'runs' => TokenType::RUNS_KEYWORD,
        'activate' => TokenType::ACTIVATE_KEYWORD,
        'with' => TokenType::WITH_KEYWORD,
        'query' => TokenType::QUERY_KEYWORD,
        'assert' => TokenType::ASSERT_KEYWORD,
        'return' => TokenType::RETURN_KEYWORD,
        'true' => TokenType::TRUE_KEYWORD,
        'false' => TokenType::FALSE_KEYWORD,
        'nil' => TokenType::NIL_KEYWORD,
        'while' => TokenType::WHILE_KEYWORD,
        'for' => TokenType::FOR_KEYWORD,
        'in' => TokenType::IN_KEYWORD,
        'do' => TokenType::DO_KEYWORD,
        'range' => TokenType::RANGE_KEYWORD,
        'import' => TokenType::IMPORT_KEYWORD,
        'async' => TokenType::ASYNC_KEYWORD,
        'await' => TokenType::AWAIT_KEYWORD,
        'channel' => TokenType::CHANNEL_KEYWORD,
        'actor' => TokenType::ACTOR_KEYWORD,
        'receive' => TokenType::RECEIVE_KEYWORD,
        'select' => TokenType::SELECT_KEYWORD,
        'mutex' => TokenType::MUTEX_KEYWORD,
        'lock' => TokenType::LOCK_KEYWORD,
        'unlock' => TokenType::UNLOCK_KEYWORD,
      }.freeze
      
      TWO_WORD_KEYWORDS = {
        'is not' => TokenType::IS_NOT_KEYWORD
      }.freeze
      
      DECLARATION_TYPES = %w[function class template goal list number text boolean].freeze
      
      ARTICLES = %w[a an].freeze
      
      EVENT_ACTIONS = %w[called completed error changed activated].freeze
      
      def initialize(source)
        @source = source
        @position = 0
        @line = 1
        @column = 1
        @current_char = @source.empty? ? nil : @source[0]
        @defaults = Set.new
        @expectations = Set.new
        @in_parameter_list = false
        @parameter_context = false
        @pending_tokens = []
        @batch_mode = false
        @in_lambda_params = false
        @in_declaration_article_expected = false
        @in_event_spec = false
      end
      
      # Get next token with optional expectations for this token
      def next_token(expectations = nil)
        # If expectations provided directly, use them (for incremental API)
        @expectations = Set.new(expectations) if expectations
        # If we have pending tokens from handle_pipe, return them
        return @pending_tokens.shift if @pending_tokens.any?
        
        # Skip whitespace unless expecting NEWLINE
        skip_whitespace unless @expectations.include?(TokenType::NEWLINE)
        
        # Skip comments
        while @current_char == '#'
          skip_comment
          skip_whitespace unless @expectations.include?(TokenType::NEWLINE)
        end
        
        return new_token(TokenType::EOF, '') if @current_char.nil?
        
        case
        when newline?
          advance
          new_token(TokenType::NEWLINE, "\n")
        when @current_char == '"'
          handle_string
        when @current_char == '|'
          handle_pipe
        when @current_char == '{'
          advance; new_token(TokenType::BLOCK_START, '{')
        when @current_char == '}'
          advance; new_token(TokenType::BLOCK_END, '}')
        when letter? || @current_char == '_'
          handle_identifier_or_keyword
        when digit?
          handle_number
        else
          handle_single_char
        end
      end
      
      # Tokenize entire source with optional expectations (backward compatibility for tests)
      def tokenize(expectations: nil, expectations_overrides: [])
        # Reset state for fresh tokenization
        @position = 0
        @line = 1
        @column = 1
        @current_char = @source.empty? ? nil : @source[0]
        @defaults = Set.new(expectations || [])
        @expectations = @defaults.dup
        @in_parameter_list = false
        @parameter_context = false
        @pending_tokens = []
        @batch_mode = true
        @in_lambda_params = false
        @in_declaration_article_expected = false
        @in_event_spec = false
        @override_idx = 0
        
        tokens = []
        loop do
          # Apply per-token override expectations if provided
          @expectations = @defaults.dup
          unless expectations_overrides.empty?
            if @override_idx < expectations_overrides.size
              override = expectations_overrides[@override_idx]
              if override.is_a?(Symbol)
                # Single expected type for this token
                @expectations.clear
                @expectations.add(override)
              elsif override.respond_to?(:each)
                @expectations.merge(override)
              end
            end
          end
          @override_idx += 1
          
          tokens << next_token
          break if tokens.last.type == TokenType::EOF
        end
        @batch_mode = false
        @in_lambda_params = false
        @in_declaration_article_expected = false
        @in_event_spec = false
        tokens
      end
      
      def expect(*types)
        @expectations.merge(types)
        self
      end
      
      def clear_expectations
        @expectations.clear
        self
      end
      
      private
      
      attr_reader :source, :position, :line, :column, :current_char, :expectations
      
      def advance
        return if @current_char.nil?
        
        if @current_char == "\n"
          @line += 1
          @column = 1
        else
          @column += 1
        end
        
        @position += 1
        @current_char = @position < source.length ? source[@position] : nil
      end
      
      def peek(offset = 1)
        pos = @position + offset
        pos < source.length ? source[pos] : nil
      end
      
      def whitespace?
        @current_char =~ /\s/ && @current_char != "\n"
      end
      
      def newline?
        @current_char == "\n"
      end
      
      def letter?
        @current_char =~ /[a-zA-Z]/
      end
      
      def digit?
        @current_char =~ /\d/
      end
      
      def skip_whitespace
        while whitespace?
          advance
        end
      end
      
      def skip_comment
        advance # skip '#'
        while @current_char && @current_char != "\n"
          advance
        end
      end
      
      def handle_identifier_or_keyword
        start_col = @column
        start_line = @line
        value = String.new
        
        # Read first word (identifier/keyword without spaces)
        while @current_char && (letter? || digit? || @current_char == '_' || @current_char == '?' || @current_char == '!')
          value << @current_char
          advance
        end
        
        # Check for known two-word keywords by peeking ahead
        if !@current_char.nil? && @current_char == ' ' && !value.empty?
          # Save position to check if next word forms a multi-word keyword
          saved_pos = @position
          saved_char = @current_char
          saved_line = @line
          saved_col = @column
          
          advance # skip space
          next_word = String.new
          while @current_char && (letter? || digit? || @current_char == '_' || @current_char == '?' || @current_char == '!')
            next_word << @current_char
            advance
          end
          
          combined = (value + ' ' + next_word).downcase
          if TWO_WORD_KEYWORDS.key?(combined)
            # It's a known two-word keyword
            value << ' ' << next_word
          else
            # Not a known combination - restore position
            @position = saved_pos
            @current_char = saved_char
            @line = saved_line
            @column = saved_col
          end
        end
        
        # Check two-word keywords first
        if TWO_WORD_KEYWORDS.key?(value.downcase)
          return new_token(TWO_WORD_KEYWORDS[value.downcase], value, start_line, start_col)
        end
        
        # Check if it matches expectations for keyword vs identifier
        token_type = resolve_keyword_or_identifier(value)
        new_token(token_type, value, start_line, start_col)
      end
      
      def resolve_keyword_or_identifier(value)
        lower = value.downcase
        
        # In batch mode, rely on context tracking rather than expectations
        if @batch_mode
          # Check for known two-word keywords
          if TWO_WORD_KEYWORDS.key?(lower)
            return TWO_WORD_KEYWORDS[lower]
          end
          
          # In parameter context, articles are identifiers
          if @parameter_context && ARTICLES.include?(lower)
            return TokenType::IDENTIFIER
          end
          
          # In declaration context (after MAKE_KEYWORD), article is expected
          # Track this via a simple state
          if @in_declaration_article_expected && ARTICLES.include?(lower)
            @in_declaration_article_expected = false
            return TokenType::ARTICLE
          end
          
          # If expectations explicitly include ARTICLE for this token, honor it
          if @expectations.include?(TokenType::ARTICLE) && ARTICLES.include?(lower) && !@parameter_context
            return TokenType::ARTICLE
          end
          
          # Fallback to keyword table
          # Articles should be identifiers unless in declaration context
          result = if ARTICLES.include?(lower)
            if @in_declaration_article_expected
              TokenType::ARTICLE
            else
              TokenType::IDENTIFIER
            end
          else
            KEYWORDS.fetch(lower, TokenType::IDENTIFIER)
          end
          result
          return result
        end
        
        # Incremental mode: use expectations
        if @expectations.any?
          # Check for declaration type expectation
          if @expectations.include?(:DECL_TYPE) && DECLARATION_TYPES.include?(lower)
            return :DECL_TYPE
          end
          
          # In parameter context, identifier takes precedence over article
          if @parameter_context && @expectations.include?(TokenType::IDENTIFIER) && ARTICLES.include?(lower)
            return TokenType::IDENTIFIER
          end
          
          # Check specific keyword expectations FIRST (before article check)
          KEYWORDS.each do |kw, type|
            if @expectations.include?(type) && kw == lower
              return type
            end
          end
          
          # Check for article expectation (unless in parameter context or IDENTIFIER expected)
          if @expectations.include?(TokenType::ARTICLE) && ARTICLES.include?(lower) && !@parameter_context && !@expectations.include?(TokenType::IDENTIFIER)
            return TokenType::ARTICLE
          end
          
          # Check for identifier expectation
          if @expectations.include?(TokenType::IDENTIFIER) && @parameter_context && ARTICLES.include?(lower)
            return TokenType::IDENTIFIER
          end
          
          # Check event action keywords
          if @expectations.include?(TokenType::EVENT_ACTION_KW) && EVENT_ACTIONS.include?(lower)
            return TokenType::EVENT_ACTION_KW
          end
        end
        
        # Fallback to keyword table
        # Articles should be identifiers unless parser explicitly expects ARTICLE
        result = if ARTICLES.include?(lower)
          if @expectations.include?(TokenType::ARTICLE)
            TokenType::ARTICLE
          else
            TokenType::IDENTIFIER
          end
        else
          KEYWORDS.fetch(lower, TokenType::IDENTIFIER)
        end
        result
      end
      
      def handle_number
        start_col = @column
        value = String.new
        has_dot = false
        
        while @current_char && (digit? || (@current_char == '.' && !has_dot))
          if @current_char == '.'
            has_dot = true
          end
          value << @current_char
          advance
        end
        
        if has_dot
          new_token(TokenType::FLOAT_LITERAL, value.to_f, @line, start_col)
        else
          new_token(TokenType::INTEGER_LITERAL, value.to_i, @line, start_col)
        end
      end
      
      def handle_string
        start_col = @column
        advance # skip opening quote
        value = String.new
        
        while @current_char && @current_char != '"'
          if @current_char == '\\'
            advance
            case @current_char
            when 'n' then value << "\n"
            when 't' then value << "\t"
            when 'r' then value << "\r"
            when '\\' then value << "\\"
            when '"' then value << '"'
            else value << @current_char
            end
          else
            value << @current_char
          end
          advance
        end
        
        if @current_char != '"'
          raise LexerError, "Unterminated string at line #{@line}, column #{@column}"
        end
        
        advance # skip closing quote
        new_token(TokenType::STRING_LITERAL, value, @line, start_col)
      end
      
      def handle_pipe
        start_col = @column
        start_line = @line
        advance # skip first '|'
        
        # In batch mode, tokenize | as BLOCK_PARAM_START or BLOCK_PARAM_END
        # based on whether we're inside a lambda parameter list
        if @batch_mode
          if !@in_lambda_params
            # First | - start of lambda params
            @in_lambda_params = true
            new_token(TokenType::BLOCK_PARAM_START, '|', start_line, start_col)
          else
            # Closing | - end of lambda params
            @in_lambda_params = false
            new_token(TokenType::BLOCK_PARAM_END, '|', start_line, start_col)
          end
        else
          # Incremental mode: parse full parameter list
          first_token = new_token(TokenType::BLOCK_PARAM_START, '|', start_line, start_col)
          
          @parameter_context = true
          while @current_char && @current_char != '|'
            if whitespace?
              skip_whitespace
            elsif letter? || @current_char == '_'
              @pending_tokens << handle_identifier_or_keyword
            elsif @current_char == ','
              advance
              @pending_tokens << new_token(TokenType::COMMA, ',', @line, @column)
            else
              raise LexerError, "Unexpected character in block parameters: #{@current_char}"
            end
          end
          
          if @current_char == '|'
            @pending_tokens << new_token(TokenType::BLOCK_PARAM_END, '|', @line, @column)
            advance
          else
            raise LexerError, "Unterminated block parameter list"
          end
          
          @parameter_context = false
          first_token
        end
      end
      
      def handle_single_char
        start_col = @column
        
        # Two-char operators first
        two_char = @current_char + (peek || '')
        case two_char
        when '=>'
          advance; advance
          return new_token(TokenType::ARROW, '=>', @line, start_col)
        when '->'
          advance; advance
          return new_token(TokenType::SEND_ARROW, '->', @line, start_col)
        when '=='
          advance; advance
          return new_token(TokenType::EQ, '==', @line, start_col)
        when '!='
          advance; advance
          return new_token(TokenType::NEQ, '!=', @line, start_col)
        when '<='
          advance; advance
          return new_token(TokenType::LTE, '<=', @line, start_col)
        when '>='
          advance; advance
          return new_token(TokenType::GTE, '>=', @line, start_col)
        end
        
        # Single-char operators and delimiters
        case @current_char
        when '+'
          advance; new_token(TokenType::PLUS, '+', @line, start_col)
        when '-'
          advance; new_token(TokenType::MINUS, '-', @line, start_col)
        when '*'
          advance; new_token(TokenType::STAR, '*', @line, start_col)
        when '/'
          advance; new_token(TokenType::SLASH, '/', @line, start_col)
        when '%'
          advance; new_token(TokenType::PERCENT, '%', @line, start_col)
        when '='
          advance; new_token(TokenType::EQ, '=', @line, start_col)
        when '<'
          advance; new_token(TokenType::LT, '<', @line, start_col)
        when '>'
          advance; new_token(TokenType::GT, '>', @line, start_col)
        when '('
          advance; new_token(TokenType::LPAREN, '(', @line, start_col)
        when ')'
          advance; new_token(TokenType::RPAREN, ')', @line, start_col)
        when '{'
          advance; new_token(TokenType::LBRACE, '{', @line, start_col)
        when '}'
          advance; new_token(TokenType::BLOCK_END, '}', @line, start_col)
        when '['
          advance; new_token(TokenType::LBRACKET, '[', @line, start_col)
        when ']'
          advance; new_token(TokenType::RBRACKET, ']', @line, start_col)
        when ','
          advance; new_token(TokenType::COMMA, ',', @line, start_col)
        when '.'
          advance; new_token(TokenType::DOT, '.', @line, start_col)
        when ':'
          advance
          # Check if we're in event spec context with EVENT_ACTION_SPECIFIER expectation
          if @in_event_spec && @expectations.include?(TokenType::EVENT_ACTION_SPECIFIER)
            new_token(TokenType::EVENT_ACTION_SPECIFIER, ':', @line, start_col)
          else
            new_token(TokenType::COLON, ':', @line, start_col)
          end
        when ';'
          advance; new_token(TokenType::SEMICOLON, ';', @line, start_col)
        when '|'
          # Handled in handle_pipe
          raise LexerError, "Unexpected '|' at #{@line}:#{@column}"
        else
          raise LexerError, "Unexpected character '#{@current_char}' at line #{@line}, column #{@column}"
        end
      end
      
      def new_token(type, value, token_line = @line, token_col = @column)
        token = Token.new(type: type, value: value, line: token_line, column: token_col)
        
        # Track parameter list and declaration context
        if type == TokenType::MAKE_KEYWORD
          @in_declaration_article_expected = true
        elsif type == TokenType::WHEN_KEYWORD
          # After WHEN_KEYWORD, next identifier starts event spec
          @in_event_spec = true
        elsif type == TokenType::TAKES_KEYWORD
          @in_parameter_list = true
        elsif type == TokenType::COLON && @in_parameter_list
          @in_parameter_list = false
          @parameter_context = true
        elsif type == TokenType::ARTICLE && @in_declaration_article_expected
          @in_declaration_article_expected = false
        elsif type == TokenType::ARTICLE && @in_event_spec
          # After event name, ':' starts event action spec
          @in_event_spec = false
        # Only reset parameter context on block end or section keywords, not on newlines
        elsif type == TokenType::BLOCK_END || 
              [:RETURNS_KEYWORD, :REQUIRES_KEYWORD, :ENSURES_KEYWORD, :MAINTAINS_KEYWORD, :ACHIEVED_KEYWORD, :RUNS_KEYWORD].include?(type)
          @parameter_context = false
        end
        
        token
      end
    end
  end
end