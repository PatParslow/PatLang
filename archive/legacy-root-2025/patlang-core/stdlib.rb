# frozen_string_literal: true

# PatLang Standard Library - Main Entry Point
# Provides modular, feature-flagged standard library loading

require_relative 'stdlib/core'
require_relative 'stdlib/collections'
require_relative 'stdlib/logic'
require_relative 'stdlib/io'
require_relative 'stdlib/goals'
require_relative 'stdlib/html_gui'
require_relative 'stdlib/http'

module Patlang
  module Stdlib
    # Default enabled modules (can be overridden by feature flags)
    DEFAULT_ENABLED = %w[core].freeze
    
    # All available modules
    MODULES = {
      'core' => Patlang::Stdlib::Core::FUNCTIONS,
      'collections' => Patlang::Stdlib::Collections::FUNCTIONS,
      'logic' => Patlang::Stdlib::Logic::FUNCTIONS,
      'io' => Patlang::Stdlib::IO::FUNCTIONS,
      'goals' => Patlang::Stdlib::Goals::FUNCTIONS,
      'html_gui' => Patlang::Stdlib::HtmlGui::FUNCTIONS,
      'http' => Patlang::Stdlib::Http::FUNCTIONS
    }.freeze
    
    # Feature flag configuration
    class Config
      attr_reader :enabled_modules
      
      def initialize(enabled_modules = nil)
        @enabled_modules = enabled_modules || DEFAULT_ENABLED
        validate_modules!
      end
      
      def enabled?(module_name)
        @enabled_modules.include?(module_name)
      end
      
      def enable(module_name)
        unless MODULES.key?(module_name)
          raise ArgumentError, "Unknown module: #{module_name}"
        end
        @enabled_modules << module_name unless @enabled_modules.include?(module_name)
      end
      
      def disable(module_name)
        @enabled_modules.delete(module_name)
      end
      
      def enable_all!
        @enabled_modules = MODULES.keys
      end
      
      def disable_all!
        @enabled_modules = []
      end
      
      private
      
      def validate_modules!
        unknown = @enabled_modules - MODULES.keys
        unless unknown.empty?
          raise ArgumentError, "Unknown modules: #{unknown.join(', ')}"
        end
      end
    end
    
    # Main stdlib interface
    class Library
      attr_reader :config, :functions
      
      def initialize(config = Config.new)
        @config = config.is_a?(Config) ? config : Config.new(config)
        @functions = {}
        load_modules!
      end
      
      def get(name)
        @functions[name]
      end
      
      def function_names
        @functions.keys
      end
      
      def module_names
        @config.enabled_modules
      end
      
      def merge_env(env, evaluator = nil)
        # Inject stdlib functions into evaluation environment
        @functions.each do |name, func|
          # Capture evaluator in the function's closure
          env.define(name, create_callable_with_evaluator(func, evaluator))
        end
        
        # Also inject module references
        if @config.enabled?('logic')
          facts_db = evaluator&.instance_variable_get(:@facts_db)
          env.define(:facts_db, facts_db)
        end
        if @config.enabled?('goals')
          goal_system = evaluator&.instance_variable_get(:@goal_system)
          env.define(:goal_system, goal_system)
        end
        # Inject evaluator for stdlib functions that need it
        env.define(:evaluator, evaluator)
        
        env
      end
      
      def create_callable_with_evaluator(func_info, evaluator)
        proc do |args|
          env = func_info[:env] || {}
          env[:evaluator] = evaluator
          func_info[:impl].call(args, env)
        end
      end
      
      def call(name, args, env = {})
        func = @functions[name]
        raise NameError, "Function '#{name}' not found in stdlib" unless func
        
        check_arity(name, func[:arity], args.size)
        
        func[:impl].call(args, env)
      end
      
      private
      
      def load_modules!
        @config.enabled_modules.each do |mod_name|
          load_module(mod_name)
        end
      end
      
      def load_module(mod_name)
        mod_functions = MODULES[mod_name]
        raise ArgumentError, "Unknown module: #{mod_name}" unless mod_functions
        
        mod_functions.each do |name, func|
          if @functions.key?(name)
            warn "Warning: Overriding stdlib function '#{name}' from module '#{mod_name}'"
          end
          @functions[name] = func
        end
      end
      
      def check_arity(name, expected, actual)
        return if expected < 0  # variadic
        return if expected == actual
        
        raise ArgumentError, "Function '#{name}' expects #{expected} arguments, got #{actual}"
      end
      
      def create_callable(func_info)
        # Pass evaluator to functions that need it (already set in merge_env)
        proc do |*args|
          env = func_info[:env] || {}
          func_info[:impl].call(args, env)
        end
      end
    end
    
    # Convenience methods
    def self.load(enabled_modules = DEFAULT_ENABLED)
      config = Config.new(enabled_modules)
      Library.new(config)
    end
    
    def self.load_all
      config = Config.new
      config.enable_all!
      Library.new(config)
    end
    
    def self.core_only
      Library.new(Config.new(['core']))
    end
    
    # Global default instance (core only)
    def self.default
      @default ||= core_only
    end
    
    def self.default=(library)
      @default = library
    end
  end
end