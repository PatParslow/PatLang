require_relative '../ast/ast_nodes'

# Control flow parsing module for handling if/else, while loops, and return statements
module ParserModules
  class ControlFlowParser
    def initialize(parser)
      @parser = parser
    end

    # Grammar: if_statement → 'if' expression 'then' statement ('else' statement)? 'end'
    def parse_if_statement
      begin
        @parser.eat(:IF)
        
        if @parser.current_token.nil?
          return @parser.safe_error("Expected condition after 'if'")
        end

        # Collect tokens for the condition up to 'then' or '{'
        condition_tokens = []
        paren_depth = 0
        last_token = nil
        starters = [:IDENTIFIER, :IF, :WHILE, :RETURN, :PRINT, :INCLUDE, :MAKE, :CALL, :MATCH, :FACT, :RULE, :QUERY, :QUERY_PREFIX, :ASSERT, :GOAL, :CONSTRAIN, :PURSUE, :LBRACE]
        while @parser.current_token && !((paren_depth == 0) && (@parser.current_token.type == :THEN || @parser.current_token.type == :LBRACE))
          tok = @parser.current_token
          # Break on implicit newline termination: line break + starter token at paren depth 0
            if paren_depth == 0 && last_token && tok.line > last_token.line && starters.include?(tok.type)
            break
          end
          if tok.type == :LPAREN
            paren_depth += 1
          elsif tok.type == :RPAREN
            paren_depth -= 1 if paren_depth > 0
          end
          condition_tokens << tok
          last_token = tok
          @parser.advance
        end

        if condition_tokens.empty?
          return @parser.safe_error("Expected condition after 'if'")
        end

        # Parse the collected tokens as an expression using a minimal helper parser
        require_relative 'expression_parser'
        helper_parser = Object.new
        helper_parser.instance_variable_set(:@tokens, condition_tokens)
        helper_parser.instance_variable_set(:@current_token_index, 0)
        def helper_parser.current_token
          @tokens[@current_token_index]
        end
        def helper_parser.advance
          @current_token_index += 1
        end
        def helper_parser.peek(offset = 1)
          @tokens[@current_token_index + offset]
        end
        def helper_parser.current_token_index
          @current_token_index
        end
        expr_parser = ParserModules::ExpressionParser.new(helper_parser)
        condition = expr_parser.expression

        then_used_braces = false
        then_statements = []
        if @parser.current_token && @parser.current_token.type == :THEN
          @parser.eat(:THEN)
          loop_count = 0
          while @parser.current_token &&
                @parser.current_token.type != :ELSE &&
                @parser.current_token.type != :END &&
                loop_count < 1000  # Safety limit
            stmt = @parser.statement
            then_statements << stmt if stmt
            loop_count += 1
          end
        elsif @parser.current_token && @parser.current_token.type == :LBRACE
          @parser.eat(:LBRACE)
          then_used_braces = true
          loop_count = 0
          while @parser.current_token &&
                @parser.current_token.type != :RBRACE &&
                loop_count < 1000  # Safety limit
            stmt = @parser.statement
            then_statements << stmt if stmt
            loop_count += 1
          end
          @parser.eat(:RBRACE)
        else
          # Enhancement: allow implicit THEN if next token appears to start a statement (newline style)
          # Heuristic: if current_token begins a statement (IDENTIFIER, IF, WHILE, RETURN, PRINT, INCLUDE, MAKE, CALL, MATCH, FACT, RULE, QUERY, QUERY_PREFIX, ASSERT, GOAL, CONSTRAIN, PURSUE, LBRACE)
          starters = [:IDENTIFIER, :IF, :WHILE, :RETURN, :PRINT, :INCLUDE, :MAKE, :CALL, :MATCH, :FACT, :RULE, :QUERY, :QUERY_PREFIX, :ASSERT, :GOAL, :CONSTRAIN, :PURSUE, :LBRACE]
          if @parser.current_token && starters.include?(@parser.current_token.type)
            # Implicit single-line or multi-line block until ELSE/END
            loop_count = 0
            while @parser.current_token &&
                  @parser.current_token.type != :ELSE &&
                  @parser.current_token.type != :END &&
                  loop_count < 1000
              stmt = @parser.statement
              then_statements << stmt if stmt
              loop_count += 1
            end
          else
            @parser.syntax_error("Expected 'then' or '{' after if condition")
          end
        end

        then_branch = BlockNode.new(then_statements)
        
        else_used_braces = false
        else_branch = nil
        if @parser.current_token&.type == :ELSE
          @parser.eat(:ELSE)
          
          else_statements = []
          if @parser.current_token && @parser.current_token.type == :LBRACE
            @parser.eat(:LBRACE)
            else_used_braces = true
            loop_count = 0
            while @parser.current_token &&
                  @parser.current_token.type != :RBRACE &&
                  loop_count < 1000  # Safety limit
              stmt = @parser.statement
              else_statements << stmt if stmt
              loop_count += 1
            end
            @parser.eat(:RBRACE)
          else
            loop_count = 0
            while @parser.current_token &&
                  @parser.current_token.type != :END &&
                  loop_count < 1000  # Safety limit
              stmt = @parser.statement
              else_statements << stmt if stmt
              loop_count += 1
            end
          end
          else_branch = BlockNode.new(else_statements)
        end
        
        if !(then_used_braces || else_used_braces)
          if @parser.current_token&.type == :END
            @parser.eat(:END)
          else
            @parser.syntax_error("Missing 'end' for if statement")
          end
        end

        return IfNode.new(condition, then_branch, else_branch)
      rescue ParseError => e
        @parser.safe_error("If statement parse error: #{e.message}")
      end
    end

    # Grammar: while_statement → 'while' expression 'do' statement* 'end'
    def parse_while_statement
      begin
        @parser.eat(:WHILE)
        
        if @parser.current_token.nil?
          return @parser.safe_error("Expected condition after 'while'")
        end
        
        condition = @parser.expression
        
        used_braces = false
        body_statements = []
        if @parser.current_token && @parser.current_token.type == :DO
          @parser.eat(:DO)
          loop_count = 0
          while @parser.current_token &&
                @parser.current_token.type != :END &&
                loop_count < 1000  # Safety limit
            stmt = @parser.statement
            body_statements << stmt if stmt
            loop_count += 1
          end
        elsif @parser.current_token && @parser.current_token.type == :LBRACE
          @parser.eat(:LBRACE)
          used_braces = true
          loop_count = 0
          while @parser.current_token &&
                @parser.current_token.type != :RBRACE &&
                loop_count < 1000  # Safety limit
            stmt = @parser.statement
            body_statements << stmt if stmt
            loop_count += 1
          end
          @parser.eat(:RBRACE)
        else
          @parser.syntax_error("Expected 'do' or '{' after while condition")
        end

        body = BlockNode.new(body_statements)
        
        if !used_braces
          if @parser.current_token&.type == :END
            @parser.eat(:END)
          else
            @parser.syntax_error("Missing 'end' for while statement")
          end
        end

        return WhileNode.new(condition, body)
      rescue ParseError => e
        @parser.safe_error("While statement parse error: #{e.message}")
      end
    end

    # Grammar: return_statement → 'return' expression?
    def parse_return_statement
      @parser.eat(:RETURN)
      
      if @parser.current_token && 
         @parser.current_token.type != :RBRACE &&
         @parser.current_token.type != :END &&
         @parser.current_token.type != :ELSE &&
         @parser.current_token.type != :ELSIF &&
         @parser.current_token.type != :EOF
        
        expr = @parser.expression
        return ReturnNode.new(expr)
      else
        return ReturnNode.new(nil)
      end
    end

    # Grammar: print_statement → 'print' expression
    def parse_print_statement
      @parser.eat(:PRINT)
      expr = @parser.expression
      return PrintNode.new(expr)
    end

    # Grammar: include_statement → 'include' expression
    def parse_include_statement
  include_token = @parser.current_token
  @parser.eat(:INCLUDE)
  expr = @parser.expression
  # Attach source location metadata so evaluator can resolve relative paths
  node = IncludeNode.new(expr, @parser.filename, include_token&.line, include_token&.column)
  # Debug file attachment
  # puts "[PARSER DEBUG] Created IncludeNode with file=#{node.file} line=#{node.line} col=#{node.column}"
  return node
    end
    # Grammar: for_statement → 'for' IDENTIFIER 'in' expression 'do' statement* 'end'
    def parse_for_statement
      @parser.eat(:FOR)
      iterator = @parser.current_token.value
      @parser.eat(:IDENTIFIER)
      @parser.eat(:IN)
      iterable = @parser.expression
      @parser.eat(:DO)
      body_statements = []
      loop_count = 0
      while @parser.current_token &&
            @parser.current_token.type != :END &&
            loop_count < 1000
        stmt = @parser.statement
        body_statements << stmt if stmt
        loop_count += 1
      end
      @parser.eat(:END)
      body = BlockNode.new(body_statements)
      ForLoopNode.new(iterator, iterable, body)
    end

    # Grammar: match_statement → 'match' expression 'with' (pattern '=>' statement)+ 'end'
    def parse_pattern_match_statement
      @parser.eat(:MATCH)
      expr = @parser.expression
      @parser.eat(:WITH)
      patterns = []
      loop_count = 0
      while @parser.current_token &&
            @parser.current_token.type != :END &&
            loop_count < 1000
        pattern = @parser.pattern
        @parser.eat(:ARROW)
        body = @parser.statement
        patterns << [pattern, body]
        loop_count += 1
      end
      @parser.eat(:END)
      PatternMatchNode.new(expr, patterns)
    end

    # Grammar: try_catch_statement → 'try' statement* ('catch' IDENTIFIER statement*)? ('finally' statement*)? 'end'
    def parse_try_catch_statement
      @parser.eat(:TRY)
      try_statements = []
      loop_count = 0
      while @parser.current_token &&
            @parser.current_token.type != :CATCH &&
            @parser.current_token.type != :FINALLY &&
            @parser.current_token.type != :END &&
            loop_count < 1000
        stmt = @parser.statement
        try_statements << stmt if stmt
        loop_count += 1
      end
      try_block = BlockNode.new(try_statements)
      catch_var = nil
      catch_block = nil
      finally_block = nil
      if @parser.current_token&.type == :CATCH
        @parser.eat(:CATCH)
        catch_var = @parser.current_token.value
        @parser.eat(:IDENTIFIER)
        catch_statements = []
        loop_count = 0
        while @parser.current_token &&
              @parser.current_token.type != :FINALLY &&
              @parser.current_token.type != :END &&
              loop_count < 1000
          stmt = @parser.statement
          catch_statements << stmt if stmt
          loop_count += 1
        end
        catch_block = BlockNode.new(catch_statements)
      end
      if @parser.current_token&.type == :FINALLY
        @parser.eat(:FINALLY)
        finally_statements = []
        loop_count = 0
        while @parser.current_token &&
              @parser.current_token.type != :END &&
              loop_count < 1000
          stmt = @parser.statement
          finally_statements << stmt if stmt
          loop_count += 1
        end
        finally_block = BlockNode.new(finally_statements)
      end
      @parser.eat(:END)
      TryCatchNode.new(try_block, catch_var, catch_block, finally_block)
    end

    # Grammar: non_local_return_statement → ('break' | 'continue' | 'return') expression?
    def parse_non_local_return_statement
      type = @parser.current_token.type
      @parser.eat(type)
      expr = nil
      if @parser.current_token &&
         ![:RBRACE, :END, :ELSE, :ELSIF, :EOF].include?(@parser.current_token.type)
        expr = @parser.expression
      end
      NonLocalReturnNode.new(type.downcase, expr)
    end
  end
end