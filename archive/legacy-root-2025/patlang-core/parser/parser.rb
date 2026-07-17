# frozen_string_literal: true

# Recursive Descent Parser for PatLang
# Implements expectation-driven token resolution per SPECIFICATION.md

require_relative '../ast/ast_nodes'

module Patlang
  module Parser
    class ParseError < StandardError
      attr_reader :token, :expected
      
      def initialize(message, token: nil, expected: [])
        super(message)
        @token = token
        @expected = expected
      end
    end
    
    class Parser
      def initialize(tokens)
        @tokens = tokens
        @current = 0
      end
      
      def parse
        statements = []
        until at_end? || current_token.type == :EOF
          stmt = statement
          statements << stmt if stmt
        end
        AST::ProgramNode.new(statements)
      end
      
      private
      
      attr_reader :tokens, :current
      
      def current_token
        @tokens[@current] || TokenType::EOF
      end
      
      def peek_token(offset = 1)
        @tokens[@current + offset] || TokenType::EOF
      end
      
      def advance
        @current += 1 unless at_end?
        previous_token
      end
      
      def previous_token
        @tokens[@current - 1]
      end
      
      def at_end?
        @current >= @tokens.length || current_token.type == :EOF
      end
      
      def check(type)
        current_token.type == type
      end
      
      def match(*types)
        types.each do |type|
          if check(type)
            advance
            return true
          end
        end
        false
      end
      
      def consume(type, message = "Expected #{type}")
        if check(type)
          advance
        else
          raise ParseError.new(message, token: current_token, expected: [type])
        end
      end
      
      def consume_expecting(types)
        types.each do |type|
          if check(type)
            return advance
          end
        end
        raise ParseError.new(
          "Expected one of #{types}, got #{current_token.type}",
          token: current_token,
          expected: types
        )
      end
      
      def expect_next(expectations)
        expectations
      end
      
      # ============================================================
      # Statement Parsing
      # ============================================================
      
      def statement
        return nil if match(:NEWLINE)
        
        case current_token.type
        when :MAKE_KEYWORD
          make_declaration
        when :WHEN_KEYWORD
          event_handler
        when :IMPORT_KEYWORD
          import_statement
        when :IF_KW
          if_statement
        when :WHILE_KEYWORD
          while_statement
        when :FOR_KEYWORD
          for_statement
        when :ACTIVATE_KEYWORD
          activate_statement
        when :QUERY_KEYWORD
          query_statement
        when :ASSERT_KEYWORD
          assert_statement
        when :SELECT_KEYWORD
          select_statement
        when :RETURN_KEYWORD
          return_statement
        when :IDENTIFIER
          if peek_token.type == :IS_KEYWORD || peek_token.type == :BECOMES_KEYWORD
            assignment_or_mutation
          else
            expression_statement
          end
        else
          expression_statement
        end
      end
      
      # ============================================================
      # Declaration Parsing
      # ============================================================
      
      def make_declaration
        start_token = consume(:MAKE_KEYWORD)
        
        # Expect ARTICLE ('a' or 'an')
        consume_expecting([:ARTICLE])
        
        # Expect declaration type
        decl_type = consume_expecting([
          :FUNCTION_KW, :CLASS_KW, :TEMPLATE_KW, :GOAL_KW, :LIST_KW, :TYPE_KW, :DECL_TYPE
        ])
        
        # Expect CALLED
        consume(:CALLED)
        
        # Expect name (IDENTIFIER)
        name_token = consume(:IDENTIFIER)
        name = name_token.value
        
        case decl_type.value
        when 'function'
          parse_function_declaration(name, start_token)
        when 'class', 'template'
          body = block
          parse_template(name, body, start_token, decl_type.value == 'class')
        when 'goal'
          parse_goal(name, start_token)
        when 'list'
          body = block
          initialize_list(name, body, start_token)
        when 'number', 'text', 'boolean'
          body = block
          initialize_typed_var(name, decl_type.value, body, start_token)
        else
          raise ParseError.new("Unknown declaration type: #{decl_type.value}")
        end
      end
      
      def parse_function_declaration(name, start_token)
        params = []
        return_type = nil
        preconditions = []
        postconditions = []
        body_statements = []
        
        if match(:BLOCK_START)
          until match(:BLOCK_END) || at_end?
            if match(:TAKES_KEYWORD)
              consume(:COLON)
              until match(:NEWLINE) || check(:BLOCK_END) || at_end?
                param_name = consume(:IDENTIFIER).value
                param_type = nil
                if match(:MINUS)
                  param_type = consume_expecting([:TYPE_KW, :IDENTIFIER]).value
                end
                params << AST::ParameterNode.new(param_name, type: param_type)
                match(:COMMA)
              end
            elsif match(:RETURNS_KEYWORD)
              consume(:COLON)
              # Check if next token is a type keyword or identifier (type annotation)
              # or an expression (including block expressions)
              next_token = peek_token
              expression_starters = [:PLUS, :MINUS, :STAR, :SLASH, :LPAREN, :LBRACKET, :BLOCK_START, :INTEGER_LITERAL, :FLOAT_LITERAL, :STRING_LITERAL]
              # Block start (BLOCK_START) should be treated as expression, not type
              if check(:TYPE_KW) || (check(:IDENTIFIER) && !expression_starters.include?(next_token.type))
                return_type = parse_type_annotation
              else
                # Parse as return expression
                body_statements << AST::ReturnStatementNode.new(expression)
              end
              match(:NEWLINE)
            elsif match(:REQUIRES_KEYWORD)
              consume(:COLON)
              until match(:NEWLINE) || check(:BLOCK_END) || at_end?
                preconditions << expression
                match(:COMMA)
              end
            elsif match(:ENSURES_KEYWORD)
              consume(:COLON)
              until match(:NEWLINE) || check(:BLOCK_END) || at_end?
                postconditions << expression
                match(:COMMA)
              end
            else
              stmt = statement
              body_statements << stmt if stmt
              match(:NEWLINE)
            end
          end
        elsif match(:BEGIN_KEYWORD)
          until match(:END_KEYWORD) || at_end?
            stmt = statement
            body_statements << stmt if stmt
            match(:NEWLINE)
          end
        else
          body_statements << expression_statement
        end
        
        AST::FunctionDeclarationNode.new(
          name,
          parameters: params,
          return_type: return_type,
          preconditions: preconditions,
          postconditions: postconditions,
          body: AST::BlockNode.new(body_statements),
          line: start_token.line,
          column: start_token.column
        )
      end
      
      def parse_template(name, body, start_token, is_class)
        parent = nil
        fields = []
        invariants = []
        methods = []
        
        body.statements.each do |stmt|
          if stmt.is_a?(AST::ExpressionStatementNode)
            expr = stmt.expression
            if expr.is_a?(AST::CallNode) && expr.callee.is_a?(AST::IdentifierNode)
              case expr.callee.name
              when 'inherits'
                parent = expr.arguments.first
              when 'has'
                expr.arguments.each do |arg|
                  fields << parse_field(arg) if arg.is_a?(AST::CallNode)
                end
              when 'maintains'
                invariants += expr.arguments
              end
            else
              methods << stmt if stmt.is_a?(AST::FunctionDeclarationNode)
            end
          end
        end
        
        AST::TemplateDeclarationNode.new(
          name,
          parent: parent,
          fields: fields,
          invariants: invariants,
          methods: methods,
          line: start_token.line,
          column: start_token.column
        )
      end
      
      def parse_goal(name, start_token)
        requirements = []
        achievement_conditions = []
        goal_body = nil
        
        consume(:BLOCK_START)
        until match(:BLOCK_END) || at_end?
          match(:NEWLINE)
          
          if match(:REQUIRES_KEYWORD)
            consume(:COLON)
            until match(:NEWLINE) || check(:BLOCK_END) || at_end?
              req_name = consume(:IDENTIFIER).value
              requirements << AST::RequirementNode.new(req_name)
              match(:COMMA)
            end
          elsif match(:ACHIEVED_KEYWORD)
            if match(:WHEN_KEYWORD)
              consume(:COLON)
            else
              consume(:COLON)
            end
            until match(:NEWLINE) || check(:BLOCK_END) || at_end?
              achievement_conditions << expression
              match(:COMMA)
            end
          elsif match(:RUNS_KEYWORD)
            consume(:COLON)
            if match(:BLOCK_START)
              body_statements = []
              until match(:BLOCK_END) || at_end?
                body_statements << statement
                match(:NEWLINE)
              end
              goal_body = AST::BlockNode.new(body_statements)
            else
              goal_body = expression
            end
            match(:NEWLINE)
          else
            match(:NEWLINE)
          end
        end
        
        AST::GoalDeclarationNode.new(
          name,
          requirements: requirements,
          achievement_conditions: achievement_conditions,
          body: goal_body,
          line: start_token.line,
          column: start_token.column
        )
      end
      
      def parse_field(call_node)
        name = call_node.callee.name if call_node.callee.is_a?(AST::IdentifierNode)
        AST::FieldNode.new(name, line: call_node.line, column: call_node.column)
      end
      
      def parse_requirement(call_node)
        name = call_node.callee.name if call_node.callee.is_a?(AST::IdentifierNode)
        AST::RequirementNode.new(name, line: call_node.line, column: call_node.column)
      end
      
      def initialize_list(name, body, start_token)
        elements = []
        body.statements.each do |stmt|
          if stmt.is_a?(AST::ExpressionStatementNode)
            elements << stmt.expression
          end
        end
        
        AST::VariableDeclarationNode.new(
          name,
          initializer: AST::ListLiteralNode.new(elements, line: start_token.line, column: start_token.column),
          line: start_token.line,
          column: start_token.column
        )
      end
      
      def initialize_typed_var(name, type_name, body, start_token)
        initializer = nil
        body.statements.each do |stmt|
          if stmt.is_a?(AST::ExpressionStatementNode)
            initializer = stmt.expression
            break
          end
        end
        
        AST::VariableDeclarationNode.new(
          name,
          type: AST::TypeAnnotationNode.new(type_name, line: start_token.line, column: start_token.column),
          initializer: initializer,
          line: start_token.line,
          column: start_token.column
        )
      end
      
      def event_handler
        start_token = consume(:WHEN_KEYWORD)
        
        event_name_token = consume(:IDENTIFIER)
        event_name = event_name_token.value
        
        event_action = nil
        if match(:COLON)
          action_token = consume_expecting([:EVENT_ACTION_KW, :IDENTIFIER])
          event_action = action_token.value.to_sym
        end
        
        body = block
        
        AST::EventHandlerNode.new(
          event_name,
          event_action: event_action,
          body: body,
          line: start_token.line,
          column: start_token.column
        )
      end
      
      def if_statement
        start_token = consume(:IF_KW)
        condition = expression
        match(:THEN_KEYWORD)
        then_branch = block
        
        elsif_branches = []
        while match(:ELSIF_KEYWORD)
          elsif_condition = expression
          match(:THEN_KEYWORD)
          elsif_branch = block
          elsif_branches << [elsif_condition, elsif_branch]
        end
        
        else_branch = nil
        if match(:ELSE_KEYWORD)
          else_branch = block
        end
        
        consume(:END_KEYWORD)
        
        AST::IfStatementNode.new(
          condition,
          then_branch,
          elsif_branches: elsif_branches,
          else_branch: else_branch,
          line: start_token.line,
          column: start_token.column
        )
      end
      
      def while_statement
        start_token = consume(:WHILE_KEYWORD)
        condition = expression
        consume(:DO_KEYWORD)
        body = block
        consume(:END_KEYWORD)
        
        AST::WhileStatementNode.new(
          condition,
          body,
          line: start_token.line,
          column: start_token.column
        )
      end
      
      def for_statement
        start_token = consume(:FOR_KEYWORD)
        
        variable_token = consume(:IDENTIFIER)
        variable = variable_token.value
        
        consume(:IN_KEYWORD)
        
        is_range = false
        range_start = nil
        range_end = nil
        iterable = nil
        
        if match(:RANGE_KEYWORD)
          is_range = true
          consume(:LPAREN)
          range_start = expression
          consume(:COMMA)
          range_end = expression
          consume(:RPAREN)
        else
          iterable = expression
        end
        
        consume(:DO_KEYWORD)
        body = block
        consume(:END_KEYWORD)
        
        AST::ForStatementNode.new(
          variable,
          iterable,
          body,
          is_range: is_range,
          range_start: range_start,
          range_end: range_end,
          line: start_token.line,
          column: start_token.column
        )
      end
      
      def assignment_or_mutation
        name_token = consume(:IDENTIFIER)
        name = name_token.value
        
        if match(:IS_KEYWORD)
          value = expression
          AST::AssignmentNode.new(
            name,
            value,
            line: name_token.line,
            column: name_token.column
          )
        elsif match(:BECOMES_KEYWORD)
          value = expression
          AST::MutationNode.new(
            name,
            value,
            line: name_token.line,
            column: name_token.column
          )
        else
          raise ParseError.new("Expected 'is' or 'becomes' after identifier")
        end
      end
      
      def activate_statement
        start_token = consume(:ACTIVATE_KEYWORD)
        goal_name_token = consume(:IDENTIFIER)
        goal_name = goal_name_token.value
        
        arguments = nil
        if match(:WITH_KEYWORD)
          arguments = expression
        end
        
        AST::ActivateStatementNode.new(
          goal_name,
          arguments: arguments,
          line: start_token.line,
          column: start_token.column
        )
      end
      
      def query_statement
        start_token = consume(:QUERY_KEYWORD)
        name_token = consume(:IDENTIFIER)
        name = name_token.value
        body = block
        consume(:END_KEYWORD)
        
        AST::QueryStatementNode.new(
          name,
          body,
          line: start_token.line,
          column: start_token.column
        )
      end
      
      def assert_statement
        start_token = consume(:ASSERT_KEYWORD)
        
        predicate_token = consume(:IDENTIFIER)
        predicate = predicate_token.value
        
        arguments = []
        if match(:LPAREN)
          until match(:RPAREN) || at_end?
            arguments << expression
            match(:COMMA)
          end
        end
        
        AST::AssertStatementNode.new(
          predicate,
          arguments: arguments,
          line: start_token.line,
          column: start_token.column
        )
      end
      
      def select_statement
        select_node = parse_select
        AST::SelectStatementNode.new(select_node)
      end
      
      def import_statement
        start_token = consume(:IMPORT_KEYWORD)
        # Expect string literal for module path
        path_token = consume(:STRING_LITERAL)
        path = path_token.value
        
        # For now, just create a simple node - import is handled at load time
        AST::ImportStatementNode.new(path, line: start_token.line, column: start_token.column)
      end
      
      def return_statement
        start_token = consume(:RETURN_KEYWORD)
        value = nil
        
        unless check(:NEWLINE) || check(:END_KEYWORD) || check(:EOF)
          value = expression
        end
        
        AST::ReturnStatementNode.new(
          value,
          line: start_token.line,
          column: start_token.column
        )
      end
      
      def expression_statement
        expr = expression
        AST::ExpressionStatementNode.new(expr)
      end
      
      def block
        statements = []
        
        if match(:BLOCK_START)
          until match(:BLOCK_END) || at_end?
            stmt = statement
            statements << stmt if stmt
            match(:NEWLINE)
          end
          # Consume optional trailing newline after block end
          match(:NEWLINE)
        elsif match(:BEGIN_KEYWORD)
          until match(:END_KEYWORD) || at_end?
            stmt = statement
            statements << stmt if stmt
            match(:NEWLINE)
          end
        else
          stmt = statement
          statements << stmt if stmt
        end
        
        AST::BlockNode.new(statements)
      end
      
      def expression
        logical_or
      end
      
      def logical_or
        left = logical_and
        while match(:OR_KEYWORD)
          operator = previous_token
          right = logical_and
          left = AST::BinaryOpNode.new(left, operator.value, right, line: operator.line, column: operator.column)
        end
        left
      end
      
      def logical_and
        left = equality
        while match(:AND_KEYWORD)
          operator = previous_token
          right = equality
          left = AST::BinaryOpNode.new(left, operator.value, right, line: operator.line, column: operator.column)
        end
        left
      end
      
      def equality
        left = comparison
        while match(:IS_KEYWORD, :IS_NOT_KEYWORD, :EQ, :NEQ)
          operator = previous_token
          right = comparison
          left = AST::BinaryOpNode.new(left, operator.value, right, line: operator.line, column: operator.column)
        end
        left
      end
      
      def comparison
        left = additive
        while match(:LT, :GT, :LTE, :GTE)
          operator = previous_token
          right = additive
          left = AST::BinaryOpNode.new(left, operator.value, right, line: operator.line, column: operator.column)
        end
        left
      end
      
      def additive
        left = multiplicative
        while match(:PLUS, :MINUS)
          operator = previous_token
          right = multiplicative
          left = AST::BinaryOpNode.new(left, operator.value, right, line: operator.line, column: operator.column)
        end
        left
      end
      
      def multiplicative
        left = unary
        while match(:STAR, :SLASH, :PERCENT)
          operator = previous_token
          right = unary
          left = AST::BinaryOpNode.new(left, operator.value, right, line: operator.line, column: operator.column)
        end
        left
      end
      
      def unary
        if match(:NOT_KEYWORD, :MINUS)
          operator = previous_token
          operand = unary
          return AST::UnaryOpNode.new(operator.value, operand, line: operator.line, column: operator.column)
        end
        parse_postfix
      end
      
      def primary
        case current_token.type
        when :INTEGER_LITERAL
          token = advance
          AST::IntegerLiteralNode.new(token.value, line: token.line, column: token.column)
        when :FLOAT_LITERAL
          token = advance
          AST::FloatLiteralNode.new(token.value, line: token.line, column: token.column)
        when :STRING_LITERAL
          token = advance
          AST::StringLiteralNode.new(token.value, line: token.line, column: token.column)
        when :TRUE_KEYWORD
          token = advance
          AST::BooleanLiteralNode.new(true, line: token.line, column: token.column)
        when :FALSE_KEYWORD
          token = advance
          AST::BooleanLiteralNode.new(false, line: token.line, column: token.column)
        when :NIL_KEYWORD
          token = advance
          AST::NilLiteralNode.new(line: token.line, column: token.column)
        when :IDENTIFIER
          parse_identifier_or_call
        when :AND_KEYWORD, :OR_KEYWORD, :NOT_KEYWORD, :RANGE_KEYWORD
          # Allow logical keywords as function names when followed by (
          if peek_token.type == :LPAREN
            parse_identifier_or_call
          else
            raise ParseError.new("Unexpected token in expression: #{current_token.type}", token: current_token)
          end
        when :ASYNC_KEYWORD
          parse_async_expression
        when :AWAIT_KEYWORD
          parse_await_expression
        when :CHANNEL_KEYWORD
          parse_channel_create
        when :ACTOR_KEYWORD
          parse_actor_create
        when :RECEIVE_KEYWORD
          parse_channel_receive
        when :SELECT_KEYWORD
          parse_select
        when :MUTEX_KEYWORD
          parse_mutex_create
        when :LOCK_KEYWORD
          parse_lock
        when :UNLOCK_KEYWORD
          parse_unlock
        when :LPAREN
          parse_paren_or_lambda
        when :BLOCK_PARAM_START
          parse_lambda
        when :BLOCK_START
          if peek_is_takes_or_returns
            parse_lambda_expression
          else
            parse_block_expression
          end
        when :LBRACKET
          parse_list_literal
        else
          raise ParseError.new("Unexpected token in expression: #{current_token.type}", token: current_token)
        end
      end
      
      def parse_postfix
        # Parse primary then handle member access (dot notation) and call chaining
        node = primary
        
        while true
          if match(:DOT)
            # Member access: obj.method or obj.property
            member_token = consume(:IDENTIFIER)
            member_name = member_token.value
            
            # Create member access node
            member_access = AST::MemberAccessNode.new(
              node,
              member_name,
              line: member_token.line,
              column: member_token.column
            )
            
            if match(:LPAREN)
              # Method call: obj.method(args)
              arguments = []
              until match(:RPAREN) || at_end?
                arguments << expression
                match(:COMMA)
              end
              node = AST::CallNode.new(
                member_access,
                arguments: arguments,
                line: member_token.line,
                column: member_token.column
              )
            else
              # Property access: obj.property
              node = member_access
            end
          else
            break
          end
        end
        
        node
      end
      
      def parse_block_expression
        # Check if this looks like an object literal (key: value pairs) BEFORE consuming BLOCK_START
        if is_object_literal?
          return parse_object_literal
        end
        
        # Otherwise parse as regular block expression - block() will consume BLOCK_START
        body = block
        body
      end
      
      def is_object_literal?
        # Current position is at BLOCK_START (not yet consumed)
        saved_idx = @current
        
        # Skip BLOCK_START
        advance
        
        # Skip whitespace/newlines
        while current_token.type == :NEWLINE
          advance
        end
        
        result = false
        if current_token.type == :IDENTIFIER || current_token.type == :STRING_LITERAL
          peek_idx = @current + 1
          while peek_idx < @tokens.length && @tokens[peek_idx].type == :NEWLINE
            peek_idx += 1
          end
          if peek_idx < @tokens.length && @tokens[peek_idx].type == :COLON
            result = true
          end
        end
        
        @current = saved_idx
        result
      end
      
      def parse_object_literal
        consume(:BLOCK_START)
        obj_pairs = []
        
        until at_end?
          match(:NEWLINE)
          
          if check(:BLOCK_END)
            break
          end
          
          if (check(:IDENTIFIER) || check(:STRING_LITERAL)) && peek_token.type == :COLON
            key_token = consume_expecting([:IDENTIFIER, :STRING_LITERAL])
            key = key_token.value
            consume(:COLON)
            value = expression
            obj_pairs << AST::KeyValuePairNode.new(key, value)
            match(:COMMA)
          else
            return parse_block_expression_fallback
          end
        end
        
        consume(:BLOCK_END)
        AST::ObjectLiteralNode.new(obj_pairs)
      end
      
      def parse_block_expression_fallback
        consume(:BLOCK_END)
        AST::ObjectLiteralNode.new([])
      end
      
      def peek_is_takes_or_returns
        saved_idx = @current
        saved_token = @tokens[@current]
        
        advance
        while current_token.type == :NEWLINE
          advance
        end
        
        result = current_token.type == :TAKES_KEYWORD || current_token.type == :RETURNS_KEYWORD
        
        @current = saved_idx
        @tokens[saved_idx] = saved_token
        result
      end
      
      def parse_lambda_expression
        consume(:BLOCK_START)
        
        params = []
        return_type = nil
        preconditions = []
        postconditions = []
        body_statements = []
        
        until match(:BLOCK_END) || at_end?
          if match(:TAKES_KEYWORD)
            consume(:COLON)
            until match(:NEWLINE) || check(:BLOCK_END) || at_end?
              param_name = consume(:IDENTIFIER).value
              param_type = nil
              if match(:MINUS)
                param_type = consume_expecting([:TYPE_KW, :IDENTIFIER]).value
              end
              params << AST::ParameterNode.new(param_name, type: param_type)
              match(:COMMA)
            end
          elsif match(:RETURNS_KEYWORD)
            consume(:COLON)
            if check(:TYPE_KW)
              return_type = parse_type_annotation
            else
              body_statements << AST::ReturnStatementNode.new(expression)
            end
            match(:NEWLINE)
          elsif match(:REQUIRES_KEYWORD)
            consume(:COLON)
            until match(:NEWLINE) || check(:BLOCK_END) || at_end?
              preconditions << expression
              match(:COMMA)
            end
          elsif match(:ENSURES_KEYWORD)
            consume(:COLON)
            until match(:NEWLINE) || check(:BLOCK_END) || at_end?
              postconditions << expression
              match(:COMMA)
            end
          else
            body_statements << statement
            match(:NEWLINE)
          end
        end
        
        AST::LambdaNode.new(params, AST::BlockNode.new(body_statements))
      end
      
      def parse_identifier_or_call
        # Handle both identifiers and keywords that can be function names
        if current_token.type == :IDENTIFIER
          name_token = consume(:IDENTIFIER)
        else
          # Allow keywords like and, or, not, range as function names
          name_token = consume_expecting([:AND_KEYWORD, :OR_KEYWORD, :NOT_KEYWORD, :RANGE_KEYWORD])
        end
        name = name_token.value
        
        if match(:LPAREN)
          arguments = []
          until match(:RPAREN) || at_end?
            arguments << expression
            match(:COMMA)
          end
          AST::CallNode.new(
            AST::IdentifierNode.new(name, line: name_token.line, column: name_token.column),
            arguments: arguments,
            line: name_token.line,
            column: name_token.column
          )
        else
          AST::IdentifierNode.new(name, line: name_token.line, column: name_token.column)
        end
      end
      
      def parse_paren_or_lambda
        consume(:LPAREN)
        
        if current_token.type == :BLOCK_PARAM_START
          lambda_node = parse_lambda
          consume(:RPAREN)
          lambda_node
        else
          expr = expression
          consume(:RPAREN)
          AST::ParenExpressionNode.new(expr)
        end
      end
      
      def parse_lambda
        consume(:BLOCK_PARAM_START)
        
        parameters = []
        until match(:BLOCK_PARAM_END) || at_end?
          param_token = consume(:IDENTIFIER)
          parameters << AST::ParameterNode.new(param_token.value, line: param_token.line, column: param_token.column)
          match(:COMMA)
        end
        
        body = block
        
        AST::LambdaNode.new(parameters, body)
      end
      
      def parse_lambda
        consume(:BLOCK_PARAM_START)
        
        parameters = []
        until match(:BLOCK_PARAM_END) || at_end?
          param_token = consume(:IDENTIFIER)
          parameters << AST::ParameterNode.new(param_token.value, line: param_token.line, column: param_token.column)
          match(:COMMA)
        end
        
        body = block
        
        AST::LambdaNode.new(parameters, body)
      end
      
      def parse_async_expression
        consume(:ASYNC_KEYWORD)
        body = expression
        AST::AsyncExpressionNode.new(body)
      end
      
      def parse_await_expression
        consume(:AWAIT_KEYWORD)
        expr = expression
        AST::AwaitExpressionNode.new(expr)
      end
      
      def parse_channel_create
        consume(:CHANNEL_KEYWORD)
        buffer_size = nil
        if match(:LPAREN)
          buffer_size = expression
          consume(:RPAREN)
        end
        AST::ChannelCreateNode.new(buffer_size)
      end
      
      def parse_actor_create
        consume(:ACTOR_KEYWORD)
        initial_state = nil
        if match(:WITH_KEYWORD)
          initial_state = expression
        end
        behavior = expression
        AST::ActorCreateNode.new(behavior, initial_state)
      end
      
      def parse_send
        consume(:SEND_KEYWORD)
        target = expression
        message = expression
        AST::ActorSendNode.new(target, message)
      end
      
      def parse_channel_receive
        consume(:RECEIVE_KEYWORD)
        channel = expression
        AST::ChannelReceiveNode.new(channel)
      end
      
      def parse_select
        consume(:SELECT_KEYWORD)
        cases = []
        if match(:BLOCK_START)
          until match(:BLOCK_END) || at_end?
            match(:NEWLINE)
            if match(:RECEIVE_KEYWORD)
              consume(:LPAREN)
              channel = expression
              consume(:RPAREN)
              consume(:SEND_ARROW)
              pattern = expression
              body = block
              cases << AST::SelectCaseNode.new(channel, pattern, body)
              match(:NEWLINE)
            end
          end
        end
        AST::SelectNode.new(cases)
      end
      
      def parse_mutex_create
        consume(:MUTEX_KEYWORD)
        AST::MutexCreateNode.new
      end
      
      def parse_lock
        consume(:LOCK_KEYWORD)
        mutex = expression
        AST::MutexLockNode.new(mutex)
      end
      
      def parse_unlock
        consume(:UNLOCK_KEYWORD)
        mutex = expression
        AST::MutexUnlockNode.new(mutex)
      end
      
      def parse_list_literal
        consume(:LBRACKET)
        elements = []
        until match(:RBRACKET) || at_end?
          elements << expression
          match(:COMMA)
        end
        
        AST::ListLiteralNode.new(elements)
      end
      
      def parse_type_annotation
        token = consume_expecting([:TYPE_KW, :IDENTIFIER])
        AST::TypeAnnotationNode.new(token.value, line: token.line, column: token.column)
      end
      
      def expression_to_condition(expr)
        expr
      end
    end
  end
end