# frozen_string_literal: true

require_relative '../reasoning/facts_database'
require_relative '../reasoning/goal_system'
require_relative '../stdlib'

module Patlang
  module Evaluator
    class EvaluatorError < StandardError; end

    class ReturnException < StandardError
      attr_reader :value
      def initialize(value)
        @value = value
        super("ReturnException: #{value}")
      end
    end

    class Environment
      attr_reader :parent

      def initialize(parent = nil)
        @store = {}
        @parent = parent
      end

      def define(name, value)
        @store[name] = value
      end

      def assign(name, value)
        if @store.key?(name)
          @store[name] = value
        elsif @parent
          @parent.assign(name, value)
        else
          raise EvaluatorError, "Variable '#{name}' is not bound"
        end
      end

      def lookup(name)
        if @store.key?(name)
          @store[name]
        elsif @parent
          @parent.lookup(name)
        else
          raise EvaluatorError, "Variable '#{name}' is not bound"
        end
      end

      def bound?(name)
        @store.key?(name) || (@parent && @parent.bound?(name))
      end
    end

    class Evaluator
      def initialize(stdlib_modules = nil)
        @env = Environment.new
        # Initialize stdlib
        @stdlib = Patlang::Stdlib::Library.new(
          stdlib_modules ? Patlang::Stdlib::Config.new(stdlib_modules) : Patlang::Stdlib::Config.new
        )
        # Merge stdlib into environment (pass self as evaluator)
        @stdlib.merge_env(@env, self)
        # Define built-ins
        @env.define("true", true)
        @env.define("false", false)
        @env.define("nil", nil)
        # Initialize logic programming database
        @facts_db = FactsDatabase.new(self)
        # Initialize goal system if goals module is enabled
        if @stdlib.config.enabled?('goals')
          @goal_system = GoalSystem.new(self)
        end
      end

      def eval(node)
        case node
        when AST::ProgramNode
          eval_program(node)
        when AST::ExpressionStatementNode
          eval(node.expression)
        when AST::BlockNode
          eval_block(node)
        when AST::IntegerLiteralNode
          node.value
        when AST::FloatLiteralNode
          node.value
        when AST::StringLiteralNode
          node.value
        when AST::BooleanLiteralNode
          node.value
        when AST::NilLiteralNode
          nil
        when AST::IdentifierNode
          @env.lookup(node.name)
        when AST::AssignmentNode
          value = eval(node.value)
          @env.define(node.name, value)
          value
        when AST::MutationNode
          value = eval(node.value)
          @env.assign(node.name, value)
          value
        when AST::BinaryOpNode
          eval_binary_op(node)
        when AST::UnaryOpNode
          eval_unary_op(node)
        when AST::ParenExpressionNode
          eval(node.expression)
        when AST::CallNode
          eval_call(node)
        when AST::MemberAccessNode
          eval_member_access(node)
        when AST::LambdaNode
          # Capture current environment for closure
          node.captured_env = @env
          node
        when AST::ListLiteralNode
          node.elements.map { |e| eval(e) }
        when AST::ObjectLiteralNode
          result = {}
          node.pairs.each do |pair|
            result[pair.key] = eval(pair.value)
          end
          result
        when AST::IfStatementNode
          eval_if(node)
        when AST::WhileStatementNode
          eval_while(node)
        when AST::ForStatementNode
          eval_for(node)
        when AST::ReturnStatementNode
          value = node.value ? eval(node.value) : nil
          raise ReturnException.new(value)
        when AST::FunctionDeclarationNode
          # Function declarations are stored in environment by name
          # The body is evaluated when called
          @env.define(node.name, node)
          nil
        when AST::GoalDeclarationNode
          # Goal declarations are stored in environment by name
          # The body is evaluated when activated
          @env.define(node.name, node)
          nil
        when AST::ActivateStatementNode
          # Activate a goal by name with optional context
          goal_name = node.goal_name
          unless @env.bound?(goal_name)
            raise EvaluatorError, "Goal '#{goal_name}' not found"
          end
          goal = @env.lookup(goal_name)
          unless goal.is_a?(AST::GoalDeclarationNode)
            raise EvaluatorError, "Goal '#{goal_name}' not found or not a goal"
          end
          
          # Evaluate context arguments if provided
          context = node.arguments ? eval(node.arguments) : {}
          
          # Execute the goal
          execute_goal(goal, context)
        when AST::ImportStatementNode
          # Import statement - in Ruby implementation, this would load the module
          # For now, just return the path
          node.path
        when AST::AssertStatementNode
          # Assert a fact into the logic database
          predicate = node.predicate
          arguments = node.arguments.map { |arg| eval(arg) }
          fact_string = build_fact_string(predicate, arguments)
          @facts_db.assert_fact(fact_string)
        when AST::QueryStatementNode
          # Execute a logic query
          execute_query(node)
        # Async/await
        when AST::AsyncExpressionNode
          eval_async(node)
        when AST::AwaitExpressionNode
          eval_await(node)
        # Channels
        when AST::ChannelCreateNode
          eval_channel_create(node)
        when AST::ChannelSendNode
          eval_channel_send(node)
        when AST::ChannelReceiveNode
          eval_channel_receive(node)
        when AST::SelectNode
          eval_select(node)
        # Actors
        when AST::ActorCreateNode
          eval_actor_create(node)
        when AST::ActorSendNode
          eval_actor_send(node)
        # Mutex
        when AST::MutexCreateNode
          eval_mutex_create(node)
        when AST::MutexLockNode
          eval_mutex_lock(node)
        when AST::MutexUnlockNode
          eval_mutex_unlock(node)
        else
          raise EvaluatorError, "Unknown node type: #{node.class}"
        end
      end

      private

      def eval_program(node)
        result = nil
        node.statements.each { |stmt| result = eval(stmt) }
        result
      end

      def eval_block(node)
        # Create new scope for block
        @env = Environment.new(@env)
        result = nil
        node.statements.each { |stmt| result = eval(stmt) }
        @env = @env.parent
        result
      end

      def eval_binary_op(node)
        left = eval(node.left)
        right = eval(node.right)

        case node.operator
        when "+"  then left + right
        when "-"  then left - right
        when "*"  then left * right
        when "/"  then left / right
        when "%"  then left % right
        when "="  then left == right
        when "!=" then left != right
        when "<"  then left < right
        when ">"  then left > right
        when "<=" then left <= right
        when ">=" then left >= right
        when "and" then left && right
        when "or"  then left || right
        when "is"  then left == right  # equality check
        when "is not" then left != right
        else raise EvaluatorError, "Unknown binary operator: #{node.operator}"
        end
      end

      def eval_unary_op(node)
        operand = eval(node.operand)
        case node.operator
        when "-"     then -operand
        when "not"   then !operand
        else raise EvaluatorError, "Unknown unary operator: #{node.operator}"
        end
      end

      def eval_call(node)
        callee = eval(node.callee)
        args = node.arguments.map { |arg| eval(arg) }
        
        case callee
        when AST::FunctionDeclarationNode
          eval_function_call(callee, args)
        when AST::LambdaNode
          eval_lambda_call(callee, args)
        when Proc
          callee.call(args)
        else
          raise EvaluatorError, "Not callable: #{callee.class}"
        end
      end
      
      def eval_member_access(node)
        object = eval(node.object)
        # For now, just return the member name as string
        # In a full implementation, this would access the property
        node.member
      end

      def eval_function_call(func_node, args)
        if func_node.parameters.size != args.size
          raise EvaluatorError, "Function #{func_node.name} expects #{func_node.parameters.size} args, got #{args.size}"
        end

        outer_env = @env
        @env = Environment.new(@env)
        func_node.parameters.each_with_index do |param, i|
          @env.define(param.name, args[i])
        end

        begin
          result = eval(func_node.body)
        rescue ReturnException => e
          result = e.value
        ensure
          @env = outer_env
        end
        result
      end

      def eval_lambda_call(lambda_node, args)
        if lambda_node.parameters.size != args.size
          raise EvaluatorError, "Lambda expects #{lambda_node.parameters.size} args, got #{args.size}"
        end

        # Use captured environment for closure
        outer_env = @env
        @env = Environment.new(lambda_node.captured_env || @env)
        lambda_node.parameters.each_with_index do |param, i|
          @env.define(param.name, args[i])
        end

        begin
          result = eval(lambda_node.body)
        rescue ReturnException => e
          result = e.value
        ensure
          @env = outer_env
        end
        result
      end

      def eval_if(node)
        if truthy?(eval(node.condition))
          eval(node.then_branch)
        elsif node.elsif_branches.any?
          node.elsif_branches.each do |cond, branch|
            if truthy?(eval(cond))
              return eval(branch)
            end
          end
          node.else_branch ? eval(node.else_branch) : nil
        else
          node.else_branch ? eval(node.else_branch) : nil
        end
      end

      def eval_while(node)
        result = nil
        while truthy?(eval(node.condition))
          result = eval(node.body)
        end
        result
      end

      def eval_for(node)
        result = nil
        iter = if node.is_range
          (eval(node.range_start)..eval(node.range_end)).to_a
        else
          eval(node.iterable)
        end

        iter.each do |item|
          outer_env = @env
          @env = Environment.new(@env)
          @env.define(node.variable, item)
          result = eval(node.body)
          @env = outer_env
        end
        result
      end

      def truthy?(value)
        !value.nil? && value != false
      end

      def execute_goal(goal, context)
        # Execute goal with context
        # Check requirements
        if goal.requirements && !goal.requirements.empty?
          goal.requirements.each do |req|
            req_name = req.name
            # Check if requirement is in context or environment
            req_value = context.key?(req_name) ? context[req_name] : (@env.bound?(req_name) ? @env.lookup(req_name) : nil)
            unless truthy?(req_value)
              raise EvaluatorError, "Goal '#{goal.name}' requirement '#{req_name}' not satisfied"
            end
          end
        end
        
        # Evaluate achievement conditions
        if goal.achievement_conditions && !goal.achievement_conditions.empty?
          all_met = goal.achievement_conditions.all? do |cond|
            val = eval(cond)
            truthy?(val)
          end
          unless all_met
            raise EvaluatorError, "Goal '#{goal.name}' achievement conditions not met"
          end
        end
        
        # Execute goal body
        if goal.body
          # Execute in new scope with context
          outer_env = @env
          @env = Environment.new(@env)
          
          # Add context variables to environment
          context.each do |key, value|
            @env.define(key, value)
          end
          
          begin
            result = eval(goal.body)
          ensure
            @env = outer_env
          end
          result
        else
          nil
        end
      end

      def eval_lambda(node)
        # Return the lambda node itself (closure capture via env)
        node.captured_env = @env
        node
      end
      
      # Logic programming helpers
      
      def build_fact_string(predicate, arguments)
        if arguments.empty?
          predicate
        else
          args_str = arguments.map { |a| format_fact_arg(a) }.join(', ')
          "#{predicate}(#{args_str})"
        end
      end
      
      def format_fact_arg(arg)
        case arg
        when String
          "\"#{arg}\""
        when Numeric, TrueClass, FalseClass, NilClass
          arg.inspect
        else
          arg.inspect
        end
      end
      
      def execute_query(node)
        # Parse query body to extract query string
        query_string = extract_query_string(node.body)
        return [] if query_string.nil? || query_string.strip.empty?
        
        # Execute query using facts database
        results = @facts_db.query(query_string)
        
        # Convert QueryResult objects to array of bindings hashes
        results.map do |result|
          if result.respond_to?(:bindings)
            result.bindings
          else
            result.to_h
          end
        end
      end
      
      def extract_query_string(body)
        # The query body contains the query pattern
        # For now, extract from the body statements
        if body && body.statements && !body.statements.empty?
          # Find first non-nil statement
          stmt = body.statements.find { |s| !s.nil? }
          if stmt.is_a?(AST::ExpressionStatementNode) && stmt.expression.is_a?(AST::CallNode)
            # Build query from call pattern
            call = stmt.expression
            predicate = call.callee.name if call.callee.is_a?(AST::IdentifierNode)
            args = call.arguments.map do |arg|
              if arg.is_a?(AST::IdentifierNode) && arg.name.start_with?('?')
                arg.name  # Variable
              else
                eval(arg)  # Evaluate concrete value
              end
            end
            build_fact_string(predicate, args)
          else
            nil
          end
        else
          nil
        end
      end
      
      # ==================== ASYNC/AWAIT ====================
      
      def eval_async(node)
        # Create a new thread to run the body
        body = node.body
        Thread.new do
          eval(body)
        end
      end
      
      def eval_await(node)
        thread = eval(node.expression)
        if thread.is_a?(Thread)
          thread.value
        else
          thread
        end
      end
      
      # ==================== CHANNELS ====================
      
      def eval_channel_create(node)
        buffer_size = node.buffer_size ? eval(node.buffer_size) : 0
        # Use Ruby's Queue for channels (unbuffered if 0)
        require 'thread'
        queue = buffer_size && buffer_size > 0 ? SizedQueue.new(buffer_size) : Queue.new
        queue
      end
      
      def eval_channel_send(node)
        channel = eval(node.channel)
        value = eval(node.value)
        channel.push(value)
        value
      end
      
      def eval_channel_receive(node)
        channel = eval(node.channel)
        channel.pop
      end
      
      def eval_select(node)
        # For now, just evaluate the first ready case
        # Full select implementation would use non-blocking checks
        node.cases.each do |case_node|
          channel = eval(case_node.channel)
          if channel.is_a?(Queue) && channel.size > 0
            pattern = case_node.pattern
            value = channel.pop
            # Bind pattern variables if pattern is an identifier
            if pattern.is_a?(AST::IdentifierNode)
              @env.define(pattern.name, value)
            end
            return eval(case_node.body)
          end
        end
        nil
      end
      
      # ==================== ACTORS ====================
      
      def eval_actor_create(node)
        behavior = eval(node.behavior)
        initial_state = node.initial_state ? eval(node.initial_state) : {}
        
        # Create an actor with message queue and behavior
        mailbox = Queue.new
        actor = {
          mailbox: mailbox,
          behavior: behavior,
          state: initial_state,
          running: true
        }
        
        # Start actor loop in a thread
        actor[:thread] = Thread.new do
          while actor[:running]
            message = mailbox.pop
            if message == :stop
              break
            end
            # Call behavior with state and message
            new_state = if behavior.respond_to?(:call)
              behavior.call(actor[:state], message)
            else
              actor[:state]
            end
            actor[:state] = new_state
          end
        end
        
        actor
      end
      
      def eval_actor_send(node)
        actor = eval(node.actor)
        message = eval(node.message)
        
        if actor.is_a?(Hash) && actor[:mailbox].is_a?(Queue)
          actor[:mailbox].push(message)
        else
          raise EvaluatorError, "Not an actor"
        end
        message
      end
      
      # ==================== MUTEX ====================
      
      def eval_mutex_create(node)
        require 'thread'
        Mutex.new
      end
      
      def eval_mutex_lock(node)
        mutex = eval(node.mutex)
        mutex.lock
        nil
      end
      
      def eval_mutex_unlock(node)
        mutex = eval(node.mutex)
        mutex.unlock
        nil
      end
    end
  end
end