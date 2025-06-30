# frozen_string_literal: true

require_relative '../../patlang-core/reasoning/goal_system'
require_relative 'build_context'

# BuildGoal integrates with PaTLang's goal-oriented programming system
# to provide sophisticated build target management with dependency resolution,
# incremental building, and intelligent execution strategies.
class BuildGoal < Goal
  attr_reader :target_type, :inputs, :outputs, :command, :dependencies, 
              :incremental_check, :cache_policy, :parallel_safe

  def initialize(name, **options)
    # Extract build-specific options
    @target_type = options.delete(:target_type) || :generic
    @inputs = Array(options.delete(:inputs) || [])
    @outputs = Array(options.delete(:outputs) || [])
    @command = options.delete(:command)
    @dependencies = Array(options.delete(:dependencies) || [])
    @incremental_check = options.delete(:incremental_check)
    @cache_policy = options.delete(:cache_policy) || :default
    @parallel_safe = options.delete(:parallel_safe) || false
    
    # Set up build-specific preconditions and postconditions
    build_preconditions = generate_build_preconditions
    build_postconditions = generate_build_postconditions
    
    options[:preconditions] = (Array(options[:preconditions]) + build_preconditions).uniq
    options[:postconditions] = (Array(options[:postconditions]) + build_postconditions).uniq
    
    # Initialize parent Goal with enhanced options
    super(name, **options)
  end

  def needs_rebuild?(context)
    return true unless incremental_capable?
    
    # Check if outputs exist
    return true unless outputs_exist?
    
    # Check modification times
    return true if inputs_newer_than_outputs?
    
    # Check dependency changes
    return true if dependencies_changed?(context)
    
    # Custom incremental check
    if @incremental_check
      return @incremental_check.call(self, context)
    end
    
    false
  end

  def incremental_capable?
    !@inputs.empty? && !@outputs.empty?
  end

  def resolve(**context)
    build_context = BuildContext.new(context)
    
    # Check if rebuild is needed
    unless needs_rebuild?(build_context)
      return {
        status: :up_to_date,
        target: name,
        message: "Target #{name} is up to date",
        timestamp: Time.now
      }
    end
    
    # Execute build command
    execute_build_command(build_context)
  end

  def to_build_info
    {
      name: name,
      type: @target_type,
      inputs: @inputs,
      outputs: @outputs,
      dependencies: @dependencies,
      parallel_safe: @parallel_safe,
      incremental: incremental_capable?
    }
  end

  private

  def generate_build_preconditions
    conditions = []
    
    # Input files must exist
    @inputs.each do |input|
      conditions << "File.exist?('#{input}')"
    end
    
    # Dependencies must be satisfied
    @dependencies.each do |dep|
      conditions << "dependency_satisfied?('#{dep}')"
    end
    
    conditions
  end

  def generate_build_postconditions
    conditions = []
    
    # Output files must exist after build
    @outputs.each do |output|
      conditions << "File.exist?('#{output}')"
    end
    
    # Build must be successful
    conditions << "build_successful?"
    
    conditions
  end

  def outputs_exist?
    @outputs.all? { |output| File.exist?(output) }
  end

  def inputs_newer_than_outputs?
    return false if @inputs.empty? || @outputs.empty?
    
    latest_input = @inputs.map { |f| File.exist?(f) ? File.mtime(f) : Time.at(0) }.max
    earliest_output = @outputs.map { |f| File.exist?(f) ? File.mtime(f) : Time.at(0) }.min
    
    latest_input > earliest_output
  end

  def dependencies_changed?(context)
    # Check if any dependency targets have been rebuilt
    @dependencies.any? do |dep|
      dep_info = context.get_dependency_info(dep)
      dep_info && dep_info[:last_built] && dep_info[:last_built] > get_last_built_time
    end
  end

  def get_last_built_time
    return Time.at(0) unless outputs_exist?
    @outputs.map { |f| File.mtime(f) }.min
  end

  def execute_build_command(context)
    start_time = Time.now
    
    begin
      # Prepare build environment
      prepare_build_environment(context)
      
      # Execute the command
      result = if @command.is_a?(Proc)
        @command.call(self, context)
      elsif @command.is_a?(String)
        execute_shell_command(@command, context)
      else
        execute_default_build(context)
      end
      
      end_time = Time.now
      
      {
        status: :success,
        target: name,
        result: result,
        build_time: end_time - start_time,
        timestamp: end_time
      }
      
    rescue => e
      {
        status: :failure,
        target: name,
        error: e.message,
        build_time: Time.now - start_time,
        timestamp: Time.now
      }
    end
  end

  def prepare_build_environment(context)
    # Create output directories if needed
    @outputs.each do |output|
      dir = File.dirname(output)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    end
  end

  def execute_shell_command(command, context)
    # Expand variables in command
    expanded_command = expand_build_variables(command, context)
    
    # Execute with proper error handling
    output = `#{expanded_command} 2>&1`
    success = $?.success?
    
    unless success
      raise "Build command failed: #{expanded_command}\nOutput: #{output}"
    end
    
    output
  end

  def execute_default_build(context)
    case @target_type
    when :compile
      "Compiled #{@inputs.join(', ')} -> #{@outputs.join(', ')}"
    when :link
      "Linked #{@inputs.join(', ')} -> #{@outputs.join(', ')}"
    when :test
      "Ran tests for #{@inputs.join(', ')}"
    when :package
      "Packaged #{@inputs.join(', ')} -> #{@outputs.join(', ')}"
    else
      "Built target #{name} (#{@target_type})"
    end
  end

  def expand_build_variables(command, context)
    expanded = command.dup
    
    # Replace common build variables
    expanded.gsub!('$INPUTS', @inputs.join(' '))
    expanded.gsub!('$OUTPUTS', @outputs.join(' '))
    expanded.gsub!('$TARGET', name.to_s)
    
    # Replace context variables
    context.variables.each do |key, value|
      expanded.gsub!("$#{key.upcase}", value.to_s)
    end
    
    expanded
  end
end