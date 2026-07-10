# frozen_string_literal: true

# PatLang Standard Library - Core Module
# Provides fundamental built-in functions available in all configurations

module Patlang
  module Stdlib
    module Core
      # Registry of core functions
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
      
      # Initialize core functions
      def self.init!
        # Type conversion
        register("to_string", 1) do |args|
          args[0].to_s
        end
        
        register("to_number", 1) do |args|
          case args[0]
          when String
            args[0].to_f
          when Numeric
            args[0]
          else
            raise TypeError, "Cannot convert #{args[0].class} to number"
          end
        end
        
        register("to_boolean", 1) do |args|
          !!args[0]
        end
        
        # Type checking
        register("is_string?", 1) { |args| args[0].is_a?(String) }
        register("is_number?", 1) { |args| args[0].is_a?(Numeric) }
        register("is_boolean?", 1) { |args| args[0].is_a?(TrueClass) || args[0].is_a?(FalseClass) }
        register("is_nil?", 1) { |args| args[0].nil? }
        register("is_list?", 1) { |args| args[0].is_a?(Array) }
        register("is_object?", 1) { |args| args[0].is_a?(Hash) }
        register("is_function?", 1) { |args| args[0].is_a?(Proc) || args[0].respond_to?(:call) }
        
        # Equality and comparison
        register("equal?", 2) { |args| args[0] == args[1] }
        register("not_equal?", 2) { |args| args[0] != args[1] }
        register("less_than?", 2) { |args| args[0] < args[1] }
        register("greater_than?", 2) { |args| args[0] > args[1] }
        register("less_equal?", 2) { |args| args[0] <= args[1] }
        register("greater_equal?", 2) { |args| args[0] >= args[1] }
        
        # Math operations
        register("add", 2) { |args| args[0] + args[1] }
        register("subtract", 2) { |args| args[0] - args[1] }
        register("multiply", 2) { |args| args[0] * args[1] }
        register("divide", 2) { |args| args[0] / args[1] }
        register("modulo", 2) { |args| args[0] % args[1] }
        register("power", 2) { |args| args[0] ** args[1] }
        register("abs", 1) { |args| args[0].abs }
        register("min", 2) { |args| [args[0], args[1]].min }
        register("max", 2) { |args| [args[0], args[1]].max }
        
        # String operations
        register("string_length", 1) { |args| args[0].to_s.length }
        register("string_concat", 2) { |args| args[0].to_s + args[1].to_s }
        register("string_substring", 3) { |args| args[0].to_s[args[1], args[2]] }
        register("string_split", 2) { |args| args[0].to_s.split(args[1].to_s) }
        register("string_join", 2) { |args| args[0].join(args[1].to_s) }
        register("string_uppercase", 1) { |args| args[0].to_s.upcase }
        register("string_lowercase", 1) { |args| args[0].to_s.downcase }
        register("string_trim", 1) { |args| args[0].to_s.strip }
        
        # List operations (basic)
        register("list_length", 1) { |args| args[0].length }
        register("list_get", 2) { |args| args[0][args[1]] }
        register("list_set", 3) { |args| args[0][args[1]] = args[2]; args[0] }
        register("list_append", 2) { |args| args[0] + [args[1]] }
        register("list_prepend", 2) { |args| [args[1]] + args[0] }
        register("list_concat", 2) { |args| args[0] + args[1] }
        register("list_reverse", 1) { |args| args[0].reverse }
        register("list_empty?", 1) { |args| args[0].empty? }
        
        # Object/hash operations
        register("object_get", 2) { |args| args[0][args[1]] }
        register("object_set", 3) { |args| args[0][args[1]] = args[2]; args[0] }
        register("object_keys", 1) { |args| args[0].keys }
        register("object_values", 1) { |args| args[0].values }
        register("object_has_key?", 2) { |args| args[0].key?(args[1]) }
        register("object_merge", 2) { |args| args[0].merge(args[1]) }
        
        # Logical operations
        register("not", 1) { |args| !args[0] }
        register("and", 2) { |args| args[0] && args[1] }
        register("or", 2) { |args| args[0] || args[1] }
        
        # Identity
        register("identity", 1) { |args| args[0] }
        
        # Error handling
        register("error", 1) do |args|
          raise StandardError, args[0].to_s
        end
        
        # Debug
        register("print", 1) do |args|
          puts args[0].to_s
          args[0]
        end
        
        register("inspect", 1) do |args|
          args[0].inspect
        end
        
        # Channel operations
        register("send", 2) do |args|
          channel = args[0]
          value = args[1]
          channel.push(value)
          value
        end
        
        register("receive", 1) do |args|
          channel = args[0]
          channel.pop
        end
        
        register("channel", 0) do |args|
          require 'thread'
          Queue.new
        end
        
        register("channel_buffered", 1) do |args|
          require 'thread'
          SizedQueue.new(args[0])
        end
      end
      
      init!
    end
  end
end