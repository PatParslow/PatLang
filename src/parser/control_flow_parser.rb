require_relative '../ast_nodes'

# Control flow parsing module for handling if/else, while loops, and return statements
module ParserModules
  class ControlFlowParser
    def initialize(parser)
      @parser = parser
    end

    # Grammar: if_statement → 'if' expression 'then' statement ('else' statement)? 'end'
    def parse_if_statement
      @parser.eat(:IF)
      condition = @parser.expression
      @parser.eat(:THEN)
      
      then_statements = []
      while @parser.current_token && 
            @parser.current_token.type != :ELSE && 
            @parser.current_token.type != :END
        stmt = @parser.statement
        then_statements << stmt if stmt
      end
      
      then_branch = BlockNode.new(then_statements)
      
      else_branch = nil
      if @parser.current_token&.type == :ELSE
        @parser.eat(:ELSE)
        
        else_statements = []
        while @parser.current_token && @parser.current_token.type != :END
          stmt = @parser.statement
          else_statements << stmt if stmt
        end
        
        else_branch = BlockNode.new(else_statements)
      end
      
      @parser.eat(:END)
      
      return IfNode.new(condition, then_branch, else_branch)
    end

    # Grammar: while_statement → 'while' expression 'do' statement* 'end'
    def parse_while_statement
      @parser.eat(:WHILE)
      condition = @parser.expression
      @parser.eat(:DO)
      
      body_statements = []
      while @parser.current_token && @parser.current_token.type != :END
        stmt = @parser.statement
        body_statements << stmt if stmt
      end
      
      body = BlockNode.new(body_statements)
      
      @parser.eat(:END)
      
      return WhileNode.new(condition, body)
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