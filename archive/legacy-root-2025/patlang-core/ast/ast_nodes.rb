# frozen_string_literal: true

# AST Node definitions for PatLang
# These nodes form the abstract syntax tree produced by the parser

module Patlang
  module AST
    # Base node class
    class Node
      attr_reader :line, :column
      
      def initialize(line: 1, column: 1)
        @line = line
        @column = column
      end
      
      def accept(visitor)
        visitor.visit(self)
      end
      
      def to_s
        self.class.name.split('::').last
      end
    end
    
    # Program - root node containing all statements
    class ProgramNode < Node
      attr_reader :statements
      
      def initialize(statements, line: 1, column: 1)
        super(line: line, column: column)
        @statements = statements
      end
      
      def accept(visitor)
        visitor.visit_program(self)
      end
    end
    
    # ============================================================
    # Declaration Nodes
    # ============================================================
    
    class DeclarationNode < Node; end
    
    # Function declaration
    class FunctionDeclarationNode < DeclarationNode
      attr_reader :name, :parameters, :return_type, :preconditions, :postconditions, :body
      
      def initialize(name, parameters:, return_type: nil, preconditions: [], postconditions: [], body:, line: 1, column: 1)
        super(line: line, column: column)
        @name = name
        @parameters = parameters          # Array of ParameterNode
        @return_type = return_type        # TypeAnnotationNode or nil
        @preconditions = preconditions    # Array of ExpressionNode
        @postconditions = postconditions  # Array of ExpressionNode
        @body = body                      # BlockNode
      end
      
      def accept(visitor)
        visitor.visit_function_declaration(self)
      end
    end
    
    # Class/template declaration
    class TemplateDeclarationNode < DeclarationNode
      attr_reader :name, :parent, :fields, :invariants, :methods
      
      def initialize(name, parent: nil, fields: [], invariants: [], methods: [], line: 1, column: 1)
        super(line: line, column: column)
        @name = name
        @parent = parent                  # IdentifierNode or nil
        @fields = fields                  # Array of FieldNode
        @invariants = invariants          # Array of ExpressionNode
        @methods = methods                # Array of FunctionDeclarationNode
      end
      
      def accept(visitor)
        visitor.visit_template_declaration(self)
      end
    end
    
    # Goal declaration
    class GoalDeclarationNode < DeclarationNode
      attr_reader :name, :requirements, :achievement_conditions, :body
      
      def initialize(name, requirements: [], achievement_conditions: [], body: nil, line: 1, column: 1)
        super(line: line, column: column)
        @name = name
        @requirements = requirements              # Array of RequirementNode
        @achievement_conditions = achievement_conditions  # Array of ExpressionNode
        @body = body                              # BlockNode or nil
      end
      
      def accept(visitor)
        visitor.visit_goal_declaration(self)
      end
    end
    
    # List/Variable declaration with initializer
    class VariableDeclarationNode < DeclarationNode
      attr_reader :name, :type, :initializer
      
      def initialize(name, type: nil, initializer: nil, line: 1, column: 1)
        super(line: line, column: column)
        @name = name
        @type = type
        @initializer = initializer
      end
      
      def accept(visitor)
        visitor.visit_variable_declaration(self)
      end
    end
    
    # ============================================================
    # Supporting Declaration Nodes
    # ============================================================
    
    class ParameterNode < Node
      attr_reader :name, :type, :default_value
      
      def initialize(name, type: nil, default_value: nil, line: 1, column: 1)
        super(line: line, column: column)
        @name = name
        @type = type
        @default_value = default_value
      end
      
      def accept(visitor)
        visitor.visit_parameter(self)
      end
    end
    
    class FieldNode < Node
      attr_reader :name, :type, :default_value
      
      def initialize(name, type: nil, default_value: nil, line: 1, column: 1)
        super(line: line, column: column)
        @name = name
        @type = type
        @default_value = default_value
      end
      
      def accept(visitor)
        visitor.visit_field(self)
      end
    end
    
    class RequirementNode < Node
      attr_reader :name, :type, :default_value
      
      def initialize(name, type: nil, default_value: nil, line: 1, column: 1)
        super(line: line, column: column)
        @name = name
        @type = type
        @default_value = default_value
      end
      
      def accept(visitor)
        visitor.visit_requirement(self)
      end
    end
    
    class TypeAnnotationNode < Node
      attr_reader :type_name, :type_args
      
      def initialize(type_name, type_args: [], line: 1, column: 1)
        super(line: line, column: column)
        @type_name = type_name
        @type_args = type_args
      end
      
      def accept(visitor)
        visitor.visit_type_annotation(self)
      end
    end
    
    # ============================================================
    # Statement Nodes
    # ============================================================
    
    class StatementNode < Node; end
    
    # Block of statements
    class BlockNode < StatementNode
      attr_reader :statements
      
      def initialize(statements, line: 1, column: 1)
        super(line: line, column: column)
        @statements = statements
      end
      
      def accept(visitor)
        visitor.visit_block(self)
      end
    end
    
    # If statement
    class IfStatementNode < StatementNode
      attr_reader :condition, :then_branch, :elsif_branches, :else_branch
      
      def initialize(condition, then_branch, elsif_branches: [], else_branch: nil, line: 1, column: 1)
        super(line: line, column: column)
        @condition = condition
        @then_branch = then_branch
        @elsif_branches = elsif_branches  # Array of [condition, branch]
        @else_branch = else_branch
      end
      
      def accept(visitor)
        visitor.visit_if_statement(self)
      end
    end
    
    # While loop
    class WhileStatementNode < StatementNode
      attr_reader :condition, :body
      
      def initialize(condition, body, line: 1, column: 1)
        super(line: line, column: column)
        @condition = condition
        @body = body
      end
      
      def accept(visitor)
        visitor.visit_while_statement(self)
      end
    end
    
    # For loop
    class ForStatementNode < StatementNode
      attr_reader :variable, :iterable, :body, :is_range
      attr_reader :range_start, :range_end
      
      def initialize(variable, iterable, body, is_range: false, range_start: nil, range_end: nil, line: 1, column: 1)
        super(line: line, column: column)
        @variable = variable
        @iterable = iterable
        @body = body
        @is_range = is_range
        @range_start = range_start
        @range_end = range_end
      end
      
      def accept(visitor)
        visitor.visit_for_statement(self)
      end
    end
    
    # Assignment (IS - binding)
    class AssignmentNode < StatementNode
      attr_reader :name, :value
      
      def initialize(name, value, line: 1, column: 1)
        super(line: line, column: column)
        @name = name
        @value = value
      end
      
      def accept(visitor)
        visitor.visit_assignment(self)
      end
    end
    
    # Mutation (BECOMES)
    class MutationNode < StatementNode
      attr_reader :name, :value
      
      def initialize(name, value, line: 1, column: 1)
        super(line: line, column: column)
        @name = name
        @value = value
      end
      
      def accept(visitor)
        visitor.visit_mutation(self)
      end
    end
    
    # Event handler
    class EventHandlerNode < StatementNode
      attr_reader :event_name, :event_action, :body
      
      def initialize(event_name, event_action: nil, body:, line: 1, column: 1)
        super(line: line, column: column)
        @event_name = event_name
        @event_action = event_action  # :called, :completed, :error, :changed, :activated
        @body = body
      end
      
      def accept(visitor)
        visitor.visit_event_handler(self)
      end
    end
    
    # Activate goal
    class ActivateStatementNode < StatementNode
      attr_reader :goal_name, :arguments
      
      def initialize(goal_name, arguments: nil, line: 1, column: 1)
        super(line: line, column: column)
        @goal_name = goal_name
        @arguments = arguments
      end
      
      def accept(visitor)
        visitor.visit_activate_statement(self)
      end
    end
    
    # Query statement
    class QueryStatementNode < StatementNode
      attr_reader :name, :body
      
      def initialize(name, body, line: 1, column: 1)
        super(line: line, column: column)
        @name = name
        @body = body
      end
      
      def accept(visitor)
        visitor.visit_query_statement(self)
      end
      end
  
      # Select statement
      class SelectStatementNode < StatementNode
      attr_reader :select
    
      def initialize(select, line: 1, column: 1)
        super(line: line, column: column)
        @select = select
      end
    
      def accept(visitor)
        visitor.visit_select_statement(self)
      end
      end
  
      # Assert fact
    class AssertStatementNode < StatementNode
      attr_reader :predicate, :arguments
      
      def initialize(predicate, arguments: [], line: 1, column: 1)
        super(line: line, column: column)
        @predicate = predicate
        @arguments = arguments
      end
      
      def accept(visitor)
        visitor.visit_assert_statement(self)
      end
    end
    
    # Return statement
    class ReturnStatementNode < StatementNode
      attr_reader :value
      
      def initialize(value = nil, line: 1, column: 1)
        super(line: line, column: column)
        @value = value
      end
      
      def accept(visitor)
        visitor.visit_return_statement(self)
      end
    end
    
    # Expression statement (for REPL)
    class ExpressionStatementNode < StatementNode
      attr_reader :expression
      
      def initialize(expression, line: 1, column: 1)
        super(line: line, column: column)
        @expression = expression
      end
      
      def accept(visitor)
        visitor.visit_expression_statement(self)
      end
    end
    
    # Import statement
    class ImportStatementNode < StatementNode
      attr_reader :path
      
      def initialize(path, line: 1, column: 1)
        super(line: line, column: column)
        @path = path
      end
      
      def accept(visitor)
        visitor.visit_import_statement(self)
      end
    end
    
    # ============================================================
    # Expression Nodes
    # ============================================================
    
    class ExpressionNode < Node; end
    
    # Literals
    class IntegerLiteralNode < ExpressionNode
      attr_reader :value
      
      def initialize(value, line: 1, column: 1)
        super(line: line, column: column)
        @value = value
      end
      
      def accept(visitor)
        visitor.visit_integer_literal(self)
      end
    end
    
    class FloatLiteralNode < ExpressionNode
      attr_reader :value
      
      def initialize(value, line: 1, column: 1)
        super(line: line, column: column)
        @value = value
      end
      
      def accept(visitor)
        visitor.visit_float_literal(self)
      end
    end
    
    class StringLiteralNode < ExpressionNode
      attr_reader :value
      
      def initialize(value, line: 1, column: 1)
        super(line: line, column: column)
        @value = value
      end
      
      def accept(visitor)
        visitor.visit_string_literal(self)
      end
    end
    
    class BooleanLiteralNode < ExpressionNode
      attr_reader :value
      
      def initialize(value, line: 1, column: 1)
        super(line: line, column: column)
        @value = value
      end
      
      def accept(visitor)
        visitor.visit_boolean_literal(self)
      end
    end
    
    class NilLiteralNode < ExpressionNode
      def initialize(line: 1, column: 1)
        super(line: line, column: column)
      end
      
      def accept(visitor)
        visitor.visit_nil_literal(self)
      end
    end
    
    # Identifier/Variable reference
    class IdentifierNode < ExpressionNode
      attr_reader :name
      
      def initialize(name, line: 1, column: 1)
        super(line: line, column: column)
        @name = name
      end
      
      def accept(visitor)
        visitor.visit_identifier(self)
      end
    end
    
    # Function call
    class CallNode < ExpressionNode
      attr_reader :callee, :arguments
      
      def initialize(callee, arguments: [], line: 1, column: 1)
        super(line: line, column: column)
        @callee = callee
        @arguments = arguments
      end
      
      def accept(visitor)
        visitor.visit_call(self)
      end
    end
    
    # Lambda/Block literal
    class LambdaNode < ExpressionNode
      attr_reader :parameters, :body
      attr_accessor :captured_env
      
      def initialize(parameters, body, line: 1, column: 1)
        super(line: line, column: column)
        @parameters = parameters  # Array of ParameterNode (no default values for lambdas)
        @body = body
        @captured_env = nil
      end
      
      def accept(visitor)
        visitor.visit_lambda(self)
      end
    end
    
    # List literal
    class ListLiteralNode < ExpressionNode
      attr_reader :elements
      
      def initialize(elements, line: 1, column: 1)
        super(line: line, column: column)
        @elements = elements
      end
      
      def accept(visitor)
        visitor.visit_list_literal(self)
      end
    end
    
    # Object literal (key-value pairs)
    class ObjectLiteralNode < ExpressionNode
      attr_reader :pairs
      
      def initialize(pairs, line: 1, column: 1)
        super(line: line, column: column)
        @pairs = pairs
      end
      
      def accept(visitor)
        visitor.visit_object_literal(self)
      end
    end
    
    # Key-value pair for object literals
    class KeyValuePairNode < ExpressionNode
      attr_reader :key, :value
      
      def initialize(key, value, line: 1, column: 1)
        super(line: line, column: column)
        @key = key
        @value = value
      end
      
      def accept(visitor)
        visitor.visit_key_value_pair(self)
      end
    end
    
    # Member access (obj.property or obj.method())
    class MemberAccessNode < ExpressionNode
      attr_reader :object, :member
      
      def initialize(object, member, line: 1, column: 1)
        super(line: line, column: column)
        @object = object
        @member = member
      end
      
      def accept(visitor)
        visitor.visit_member_access(self)
      end
    end
    
    # Binary operations
    class BinaryOpNode < ExpressionNode
      attr_reader :left, :operator, :right
      
      def initialize(left, operator, right, line: 1, column: 1)
        super(line: line, column: column)
        @left = left
        @operator = operator
        @right = right
      end
      
      def accept(visitor)
        visitor.visit_binary_op(self)
      end
    end
    
    # Unary operations
    class UnaryOpNode < ExpressionNode
      attr_reader :operator, :operand
      
      def initialize(operator, operand, line: 1, column: 1)
        super(line: line, column: column)
        @operator = operator
        @operand = operand
      end
      
      def accept(visitor)
        visitor.visit_unary_op(self)
      end
    end
    
    # Parenthesized expression
    class ParenExpressionNode < ExpressionNode
      attr_reader :expression
      
      def initialize(expression, line: 1, column: 1)
        super(line: line, column: column)
        @expression = expression
      end
      
      def accept(visitor)
        visitor.visit_paren_expression(self)
      end
    end
    
    # Logic fact (for queries/asserts)
    class FactNode < ExpressionNode
      attr_reader :predicate, :arguments
      
      def initialize(predicate, arguments: [], line: 1, column: 1)
        super(line: line, column: column)
        @predicate = predicate
        @arguments = arguments
      end
      
      def accept(visitor)
        visitor.visit_fact(self)
      end
    end
    
    # Async/await expressions
    class AsyncExpressionNode < ExpressionNode
      attr_reader :body
      
      def initialize(body, line: 1, column: 1)
        super(line: line, column: column)
        @body = body
      end
      
      def accept(visitor)
        visitor.visit_async_expression(self)
      end
    end
    
    class AwaitExpressionNode < ExpressionNode
      attr_reader :expression
      
      def initialize(expression, line: 1, column: 1)
        super(line: line, column: column)
        @expression = expression
      end
      
      def accept(visitor)
        visitor.visit_await_expression(self)
      end
    end
    
    # Channel operations
    class ChannelCreateNode < ExpressionNode
      attr_reader :buffer_size
      
      def initialize(buffer_size = nil, line: 1, column: 1)
        super(line: line, column: column)
        @buffer_size = buffer_size
      end
      
      def accept(visitor)
        visitor.visit_channel_create(self)
      end
    end
    
    class ChannelSendNode < ExpressionNode
      attr_reader :channel, :value
      
      def initialize(channel, value, line: 1, column: 1)
        super(line: line, column: column)
        @channel = channel
        @value = value
      end
      
      def accept(visitor)
        visitor.visit_channel_send(self)
      end
    end
    
    class ChannelReceiveNode < ExpressionNode
      attr_reader :channel
      
      def initialize(channel, line: 1, column: 1)
        super(line: line, column: column)
        @channel = channel
      end
      
      def accept(visitor)
        visitor.visit_channel_receive(self)
      end
    end
    
    class SelectNode < ExpressionNode
      attr_reader :cases
      
      def initialize(cases, line: 1, column: 1)
        super(line: line, column: column)
        @cases = cases
      end
      
      def accept(visitor)
        visitor.visit_select(self)
      end
    end
    
    class SelectCaseNode < ExpressionNode
      attr_reader :channel, :pattern, :body
      
      def initialize(channel, pattern, body, line: 1, column: 1)
        super(line: line, column: column)
        @channel = channel
        @pattern = pattern
        @body = body
      end
      
      def accept(visitor)
        visitor.visit_select_case(self)
      end
    end
    
    # Actor model
    class ActorCreateNode < ExpressionNode
      attr_reader :behavior, :initial_state
      
      def initialize(behavior, initial_state = nil, line: 1, column: 1)
        super(line: line, column: column)
        @behavior = behavior
        @initial_state = initial_state
      end
      
      def accept(visitor)
        visitor.visit_actor_create(self)
      end
    end
    
    class ActorSendNode < ExpressionNode
      attr_reader :actor, :message
      
      def initialize(actor, message, line: 1, column: 1)
        super(line: line, column: column)
        @actor = actor
        @message = message
      end
      
      def accept(visitor)
        visitor.visit_actor_send(self)
      end
    end
    
    # Mutex operations
    class MutexCreateNode < ExpressionNode
      def initialize(line: 1, column: 1)
        super(line: line, column: column)
      end
      
      def accept(visitor)
        visitor.visit_mutex_create(self)
      end
    end
    
    class MutexLockNode < ExpressionNode
      attr_reader :mutex
      
      def initialize(mutex, line: 1, column: 1)
        super(line: line, column: column)
        @mutex = mutex
      end
      
      def accept(visitor)
        visitor.visit_mutex_lock(self)
      end
    end
    
    class MutexUnlockNode < ExpressionNode
      attr_reader :mutex
      
      def initialize(mutex, line: 1, column: 1)
        super(line: line, column: column)
        @mutex = mutex
      end
      
      def accept(visitor)
        visitor.visit_mutex_unlock(self)
      end
    end
  end
end