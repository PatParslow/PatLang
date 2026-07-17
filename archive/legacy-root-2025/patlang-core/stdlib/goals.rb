# frozen_string_literal: true

# PatLang Standard Library - Goals Module
# Provides goal-oriented programming functions

module Patlang
  module Stdlib
    module Goals
      FUNCTIONS = {}
      
      def self.register(name, arity, &block)
        FUNCTIONS[name] = { arity: arity, impl: block }
      end
      
      def self.get(name)
        FUNCTIONS[name]
      end
      
      def self.all
        FUNCTIONS.keys
      end
      
      def self.init!
        # Helper to get goal system from environment
        get_goal_system = lambda do |env|
          env.lookup(:goal_system) rescue (env[:evaluator]&.instance_variable_get(:@goal_system))
        end
        
        # Goal system access
        register("goal_system", 0) do |args, env|
          get_goal_system.call(env)
        end
        
        # Declare goal
        register("declare_goal", -1) do |args, env|
          goal_system = get_goal_system.call(env)
          raise "Goal system not available" unless goal_system
          
          name = args[0]
          definition = args[1..].join(' ')
          goal_system.declare_goal(name, definition)
        end
        
        # Pursue/activate goal
        register("pursue", 1) do |args, env|
          goal_system = get_goal_system.call(env)
          raise "Goal system not available" unless goal_system
          
          goal_name = args[0]
          context = args[1] || {}
          goal_system.pursue_goal(goal_name, context)
        end
        
        # Pursue goal with context
        register("pursue_with", 2) do |args, env|
          goal_system = get_goal_system.call(env)
          raise "Goal system not available" unless goal_system
          
          goal_name = args[0]
          context = args[1]
          goal_system.pursue_goal(goal_name, context)
        end
        
        # Pursue multiple goals concurrently
        register("pursue_all", 1) do |args, env|
          goal_system = get_goal_system.call(env)
          raise "Goal system not available" unless goal_system
          
          goal_names = args[0]
          context = args[1] || {}
          goal_system.pursue_goals_concurrently(goal_names, context)
        end
        
        # Create execution plan
        register("execution_plan", 1) do |args, env|
          goal_system = get_goal_system.call(env)
          raise "Goal system not available" unless goal_system
          
          goal_name = args[0]
          goal_system.create_execution_plan(goal_name)
        end
        
        # Start monitoring
        register("monitor_goal", 1) do |args, env|
          goal_system = get_goal_system.call(env)
          raise "Goal system not available" unless goal_system
          
          goal_name = args[0]
          goal_system.start_monitoring(goal_name)
        end
        
        # Get goal by name
        register("get_goal", 1) do |args, env|
          goal_system = get_goal_system.call(env)
          raise "Goal system not available" unless goal_system
          
          goal_system.get_goal(args[0])
        end
        
        # List all goals
        register("all_goals", 0) do |args, env|
          goal_system = get_goal_system.call(env)
          raise "Goal system not available" unless goal_system
          
          goal_system.all_goals
        end
        
        # Resource scheduling
        register("resource_scheduler", 0) do |args, env|
          goal_system = get_goal_system.call(env)
          raise "Goal system not available" unless goal_system
          
          goal_system.resource_scheduler
        end
      end
      
      init!
    end
  end
end