# frozen_string_literal: true

require_relative '../core/build_runner'
require_relative '../core/build_goal'

# BuildDSL provides a clean, intuitive domain-specific language
# for defining build targets and their relationships, leveraging
# PaTLang's goal-oriented programming capabilities.
module BuildDSL
  class BuildFile
    attr_reader :runner, :variables, :file_path

    def initialize(runner, file_path = nil)
      @runner = runner
      @variables = {}
      @file_path = file_path
      @target_stack = []
    end

    # Variable definition and access
    def var(name, value = nil, &block)
      if block_given?
        @variables[name.to_sym] = block
      else
        @variables[name.to_sym] = value
      end
    end

    def get_var(name)
      value = @variables[name.to_sym]
      value.is_a?(Proc) ? value.call : value
    end

    # Target definition methods
    def target(name, **options, &block)
      context = TargetContext.new(self, name, options)
      context.instance_eval(&block) if block_given?
      
      # Create the actual build target
      @runner.define_target(name, **context.to_options)
    end

    def compile(name, **options, &block)
      options[:target_type] = :compile
      target(name, **options, &block)
    end

    def link(name, **options, &block)
      options[:target_type] = :link
      target(name, **options, &block)
    end

    def test(name, **options, &block)
      options[:target_type] = :test
      target(name, **options, &block)
    end

    def package(name, **options, &block)
      options[:target_type] = :package
      target(name, **options, &block)
    end

    def clean(name, **options, &block)
      options[:target_type] = :clean
      target(name, **options, &block)
    end

    # File pattern matching helpers
    def glob(pattern)
      Dir.glob(pattern)
    end

    def src(pattern = "src/**/*.rb")
      glob(pattern)
    end

    def tests(pattern = "test/**/*.rb")
      glob(pattern)
    end

    # Build execution methods
    def build(*targets)
      @runner.build(targets.empty? ? nil : targets)
    end

    def clean_all
      @runner.clean
    end

    def list
      @runner.list_targets
    end

    # Default target definition
    def default(*targets)
      var(:default_targets, targets)
    end

    def get_default_targets
      get_var(:default_targets) || []
    end

    # Conditional execution
    def when_condition(condition, &block)
      instance_eval(&block) if condition
    end

    def unless_condition(condition, &block)
      instance_eval(&block) unless condition
    end

    # Include other build files
    def include_build_file(file_path)
      resolved_path = File.expand_path(file_path, File.dirname(@file_path || "."))
      if File.exist?(resolved_path)
        content = File.read(resolved_path)
        sub_build_file = BuildFile.new(@runner, resolved_path)
        sub_build_file.instance_eval(content, resolved_path)
        
        # Merge variables
        @variables.merge!(sub_build_file.variables)
      else
        raise "Build file not found: #{resolved_path}"
      end
    end
  end

  class TargetContext
    def initialize(build_file, name, initial_options)
      @build_file = build_file
      @name = name
      @options = initial_options.dup
      @inputs = []
      @outputs = []
      @dependencies = []
      @preconditions = []
      @postconditions = []
    end

    # Input/Output specification
    def inputs(*files)
      files.flatten.each { |file| @inputs << file }
    end
    alias_method :input, :inputs

    def outputs(*files)
      files.flatten.each { |file| @outputs << file }
    end
    alias_method :output, :outputs

    # Dependency specification
    def depends_on(*targets)
      targets.flatten.each { |target| @dependencies << target }
    end
    alias_method :depends, :depends_on

    # Command specification
    def command(cmd)
      @options[:command] = cmd
    end

    def shell(cmd)
      command(cmd)
    end

    def action(&block)
      @options[:command] = block
    end

    # Build conditions
    def precondition(condition)
      @preconditions << condition
    end

    def postcondition(condition)
      @postconditions << condition
    end

    # Helper methods for file patterns and variables
    def glob(pattern)
      Dir.glob(pattern)
    end
    
    def var(name)
      @build_file.get_var(name)
    end

    # Build properties
    def parallel_safe(enabled = true)
      @options[:parallel_safe] = enabled
    end

    def incremental(&block)
      @options[:incremental_check] = block
    end

    def description(desc)
      @options[:description] = desc
    end

    # File operations within target context
    def mkdir(dir)
      @options[:command] = proc do |target, context|
        FileUtils.mkdir_p(dir)
        "Created directory: #{dir}"
      end
    end

    def copy(from, to)
      @options[:command] = proc do |target, context|
        FileUtils.cp_r(from, to)
        "Copied #{from} to #{to}"
      end
    end

    def remove(*files)
      @options[:command] = proc do |target, context|
        files.flatten.each do |file|
          if File.exist?(file)
            FileUtils.rm_rf(file)
          end
        end
        "Removed #{files.join(', ')}"
      end
    end

    # Access to build file variables
    def var(name)
      @build_file.get_var(name)
    end

    def to_options
      @options.merge(
        inputs: @inputs,
        outputs: @outputs,
        dependencies: @dependencies,
        preconditions: @preconditions,
        postconditions: @postconditions
      )
    end
  end

  # DSL loader and executor
  class DSLLoader
    def self.load_build_file(file_path, runner = nil)
      runner ||= BuildRunner.new
      
      unless File.exist?(file_path)
        raise "Build file not found: #{file_path}"
      end
      
      content = File.read(file_path)
      build_file = BuildFile.new(runner, file_path)
      
      begin
        build_file.instance_eval(content, file_path)
      rescue => e
        raise "Error loading build file #{file_path}: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
      end
      
      { build_file: build_file, runner: runner }
    end

    def self.execute_build_file(file_path, targets = nil)
      result = load_build_file(file_path)
      build_file = result[:build_file]
      runner = result[:runner]
      
      # Use specified targets or default targets
      targets_to_build = if targets && !targets.empty?
        targets
      else
        default_targets = build_file.get_default_targets
        default_targets.empty? ? nil : default_targets
      end
      
      runner.build(targets_to_build)
    end
  end

  # Convenience methods for direct DSL usage
  def self.define_build_file(&block)
    runner = BuildRunner.new
    build_file = BuildFile.new(runner)
    build_file.instance_eval(&block)
    { build_file: build_file, runner: runner }
  end

  def self.quick_build(&block)
    result = define_build_file(&block)
    runner = result[:runner]
    build_file = result[:build_file]
    
    # Execute default targets
    default_targets = build_file.get_default_targets
    runner.build(default_targets.empty? ? nil : default_targets)
  end
end

# Global convenience methods for build files
def build_with_dsl(file_path, targets = nil)
  BuildDSL::DSLLoader.execute_build_file(file_path, targets)
end

def quick_build(&block)
  BuildDSL.quick_build(&block)
end