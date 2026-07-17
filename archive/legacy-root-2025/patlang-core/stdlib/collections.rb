# frozen_string_literal: true

# PatLang Standard Library - Collections Module
# Provides collection manipulation functions (map, filter, reduce, etc.)

module Patlang
  module Stdlib
    module Collections
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
        # Helper to call function (handles both Proc and LambdaNode)
        call_fn = lambda do |fn, arg, env|
          if fn.respond_to?(:call)
            fn.call(arg)
          elsif fn.is_a?(::Patlang::AST::LambdaNode)
            # Evaluate lambda using the evaluator
            evaluator = env[:evaluator]
            raise "Evaluator not available in env" unless evaluator
            
            # Create a call node and evaluate it
            call_node = ::Patlang::AST::CallNode.new(
              fn,
              arguments: [::Patlang::AST::IntegerLiteralNode.new(arg, line: 1, column: 1)],
              line: 1,
              column: 1
            )
            evaluator.eval(call_node)
          else
            raise TypeError, "Function is not callable: #{fn.class}"
          end
        end
        
        # Helper to call binary function (for reduce)
        call_binary_fn = lambda do |fn, arg1, arg2, env|
          if fn.respond_to?(:call)
            fn.call(arg1, arg2)
          elsif fn.is_a?(::Patlang::AST::LambdaNode)
            evaluator = env[:evaluator]
            raise "Evaluator not available in env" unless evaluator
            
            call_node = ::Patlang::AST::CallNode.new(
              fn,
              arguments: [
                ::Patlang::AST::IntegerLiteralNode.new(arg1, line: 1, column: 1),
                ::Patlang::AST::IntegerLiteralNode.new(arg2, line: 1, column: 1)
              ],
              line: 1,
              column: 1
            )
            evaluator.eval(call_node)
          else
            raise TypeError, "Function is not callable: #{fn.class}"
          end
        end
        
        # Map - apply function to each element
        register("map", 2) do |args, env|
          list = args[0]
          fn = args[1]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          
          list.map { |item| call_fn.call(fn, item, env) }
        end
        
        # Filter - keep elements that satisfy predicate
        register("filter", 2) do |args, env|
          list = args[0]
          predicate = args[1]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          
          list.select { |item| 
            result = call_fn.call(predicate, item, env)
            !!result  # truthy check
          }
        end
        
        # Reduce/fold - combine elements using binary function
        register("reduce", 3) do |args, env|
          list = args[0]
          initial = args[1]
          fn = args[2]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          
          list.reduce(initial) do |acc, item|
            call_binary_fn.call(fn, acc, item, env)
          end
        end
        
        # Reduce with no initial value (uses first element)
        register("reduce1", 2) do |args, env|
          list = args[0]
          fn = args[1]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          raise ArgumentError, "Cannot reduce empty list without initial value" if list.empty?
          
          list[1..].reduce(list[0]) do |acc, item|
            call_binary_fn.call(fn, acc, item, env)
          end
        end
        
        # Find first element matching predicate
        register("find", 2) do |args, env|
          list = args[0]
          predicate = args[1]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          
          list.find { |item| 
            result = call_fn.call(predicate, item, env)
            !!result
          }
        end
        
        # Find index of first matching element
        register("find_index", 2) do |args, env|
          list = args[0]
          predicate = args[1]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          
          list.find_index { |item| 
            result = call_fn.call(predicate, item, env)
            !!result
          }
        end
        
        # Check if any element matches predicate
        register("any?", 2) do |args, env|
          list = args[0]
          predicate = args[1]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          
          list.any? { |item| 
            result = call_fn.call(predicate, item, env)
            !!result
          }
        end
        
        # Check if all elements match predicate
        register("all?", 2) do |args, env|
          list = args[0]
          predicate = args[1]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          
          list.all? { |item| 
            result = call_fn.call(predicate, item, env)
            !!result
          }
        end
        
        # Check if no elements match predicate
        register("none?", 2) do |args, env|
          list = args[0]
          predicate = args[1]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          
          list.none? { |item| 
            result = call_fn.call(predicate, item, env)
            !!result
          }
        end
        
        # Count elements matching predicate
        register("count", 2) do |args, env|
          list = args[0]
          predicate = args[1]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          
          if predicate.respond_to?(:call) || predicate.is_a?(::Patlang::AST::LambdaNode)
            list.count { |item| 
              result = call_fn.call(predicate, item, env)
              !!result
            }
          else
            list.count(predicate)
          end
        end
        
        # Sort list
        register("sort", 1) do |args, env|
          list = args[0]
          raise TypeError, "Argument must be a list" unless list.is_a?(Array)
          
          list.sort
        end
        
        register("sort_by", 2) do |args, env|
          list = args[0]
          key_fn = args[1]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          
          list.sort_by { |item| call_fn.call(key_fn, item, env) }
        end
        
        # Unique elements
        register("uniq", 1) do |args, env|
          list = args[0]
          raise TypeError, "Argument must be a list" unless list.is_a?(Array)
          
          list.uniq
        end
        
        # Flatten nested lists
        register("flatten", 1) do |args, env|
          list = args[0]
          raise TypeError, "Argument must be a list" unless list.is_a?(Array)
          
          list.flatten
        end
        
        # Zip multiple lists
        register("zip", -1) do |args, env|
          lists = args
          lists.each { |l| raise TypeError, "All arguments must be lists" unless l.is_a?(Array) }
          
          lists[0].zip(*lists[1..])
        end
        
        # Range generation
        register("range", 2) do |args, env|
          start = args[0]
          finish = args[1]
          raise TypeError, "Arguments must be numbers" unless start.is_a?(Numeric) && finish.is_a?(Numeric)
          
          (start..finish).to_a
        end
        
        register("range_step", 3) do |args, env|
          start = args[0]
          finish = args[1]
          step = args[2]
          raise TypeError, "Arguments must be numbers" unless start.is_a?(Numeric) && finish.is_a?(Numeric) && step.is_a?(Numeric)
          
          (start..finish).step(step).to_a
        end
        
        # Take first n elements
        register("take", 2) do |args, env|
          list = args[0]
          n = args[1]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          raise TypeError, "Second argument must be a number" unless n.is_a?(Integer)
          
          list.take(n)
        end
        
        # Drop first n elements
        register("drop", 2) do |args, env|
          list = args[0]
          n = args[1]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          raise TypeError, "Second argument must be a number" unless n.is_a?(Integer)
          
          list.drop(n)
        end
        
        # Partition list by predicate
        register("partition", 2) do |args, env|
          list = args[0]
          predicate = args[1]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          
          list.partition { |item| 
            result = call_fn.call(predicate, item, env)
            !!result
          }
        end
        
        # Group by key function
        register("group_by", 2) do |args, env|
          list = args[0]
          key_fn = args[1]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          
          list.group_by { |item| 
            call_fn.call(key_fn, item, env)
          }
        end
        
        # Chunk list into sublists of size n
        register("chunk", 2) do |args, env|
          list = args[0]
          n = args[1]
          raise TypeError, "First argument must be a list" unless list.is_a?(Array)
          raise TypeError, "Second argument must be a number" unless n.is_a?(Integer)
          
          list.each_slice(n).to_a
        end
      end
      
      init!
    end
  end
end