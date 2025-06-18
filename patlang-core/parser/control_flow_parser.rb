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
        
        condition = @parser.expression
        
        if @parser.current_token.nil? || @parser.current_token.type != :THEN
          @parser.syntax_error("Expected 'then' after if condition")
        end
        
        @parser.eat(:THEN)
        
        then_statements = []
        loop_count = 0
        while @parser.current_token &&
              @parser.current_token.type != :ELSE &&
              @parser.current_token.type != :END &&
              loop_count < 1000  # Safety limit
          stmt = @parser.statement
          then_statements << stmt if stmt
          loop_count += 1
        end
        
        then_branch = BlockNode.new(then_statements)
        
        else_branch = nil
        if @parser.current_token&.type == :ELSE
          @parser.eat(:ELSE)
          
          else_statements = []
          loop_count = 0
          while @parser.current_token &&
                @parser.current_token.type != :END &&
                loop_count < 1000  # Safety limit
            stmt = @parser.statement
            else_statements << stmt if stmt
            loop_count += 1
          end
          
          else_branch = BlockNode.new(else_statements)
        end
        
        if @parser.current_token&.type == :END
          @parser.eat(:END)
        else
          @parser.syntax_error("Missing 'end' for if statement")
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
        
        if @parser.current_token.nil? || @parser.current_token.type != :DO
          @parser.syntax_error("Expected 'do' after while condition")
        end
        
        @parser.eat(:DO)
        
        body_statements = []
        loop_count = 0
        while @parser.current_token &&
              @parser.current_token.type != :END &&
              loop_count < 1000  # Safety limit
          stmt = @parser.statement
          body_statements << stmt if stmt
          loop_count += 1
        end
        
        body = BlockNode.new(body_statements)
        
        if @parser.current_token&.type == :END
          @parser.eat(:END)
        else
          @parser.syntax_error("Missing 'end' for while statement")
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
  end
end