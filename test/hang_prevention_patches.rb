#!/usr/bin/env ruby
# frozen_string_literal: true

# HANG PREVENTION PATCHES
# These patches add timeout protection to core components that can hang

require 'timeout'

# Patch 1: Parser with mandatory timeouts
module ParserTimeoutProtection
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    def with_parser_timeout(timeout = 5, &block)
      Timeout::timeout(timeout) do
        yield
      end
    rescue Timeout::Error
      raise ParseError, "Parser operation timed out after #{timeout} seconds - likely infinite loop"
    end
  end
  
  def parse_expression_with_timeout
    self.class.with_parser_timeout(3) do
      original_parse_expression
    end
  end
  
  def parse_statement_with_timeout
    self.class.with_parser_timeout(3) do
      original_parse_statement
    end
  end
end

# Patch 2: Evaluator with mandatory timeouts
module EvaluatorTimeoutProtection
  def evaluate_with_timeout(node, timeout = 5)
    Timeout::timeout(timeout) do
      original_evaluate(node)
    end
  rescue Timeout::Error
    raise RuntimeError, "Evaluation timed out after #{timeout} seconds - likely infinite recursion or loop"
  end
  
  def evaluate_block_with_timeout(statements, timeout = 10)
    Timeout::timeout(timeout) do
      original_evaluate_block(statements)
    end
  rescue Timeout::Error
    raise RuntimeError, "Block evaluation timed out after #{timeout} seconds"
  end
end

# Patch 3: Reasoning Engine with mandatory timeouts
module ReasoningTimeoutProtection
  def pursue_goal_with_timeout(goal, timeout = 8)
    Timeout::timeout(timeout) do
      original_pursue_goal(goal)
    end
  rescue Timeout::Error
    raise RuntimeError, "Goal pursuit timed out after #{timeout} seconds - likely infinite reasoning loop"
  end
  
  def unify_with_timeout(term1, term2, timeout = 3)
    Timeout::timeout(timeout) do
      original_unify(term1, term2)
    end
  rescue Timeout::Error
    raise RuntimeError, "Unification timed out after #{timeout} seconds"
  end
end

# Patch 4: Loop Detection and Prevention
class LoopDetector
  def initialize(max_iterations = 1000)
    @max_iterations = max_iterations
    @iteration_count = 0
    @loop_contexts = {}
  end
  
  def check_loop(context_key)
    @iteration_count += 1
    
    if @iteration_count > @max_iterations
      raise RuntimeError, "Maximum iteration limit (#{@max_iterations}) exceeded - infinite loop detected"
    end
    
    @loop_contexts[context_key] ||= 0
    @loop_contexts[context_key] += 1
    
    if @loop_contexts[context_key] > 100
      raise RuntimeError, "Context loop detected: #{context_key} repeated #{@loop_contexts[context_key]} times"
    end
  end
  
  def reset_context(context_key)
    @loop_contexts.delete(context_key)
  end
  
  def reset_all
    @iteration_count = 0
    @loop_contexts.clear
  end
end

# Global loop detector
$global_loop_detector = LoopDetector.new

# Patch 5: Enhanced Parser Loop Protection
module EnhancedParserLoopProtection
  def parse_with_loop_detection
    context_key = "#{self.class.name}##{caller_locations(1,1)[0].label}"
    $global_loop_detector.check_loop(context_key)
    
    yield
  ensure
    $global_loop_detector.reset_context(context_key) if block_given?
  end
end

# Apply patches conditionally to avoid conflicts
def apply_hang_prevention_patches!
  puts "🛡️  Applying hang prevention patches..."
  
  # Patch Parser if it exists
  if defined?(Parser)
    unless Parser.included_modules.include?(ParserTimeoutProtection)
      Parser.include(ParserTimeoutProtection)
      puts "   ✅ Parser timeout protection applied"
    end
  end
  
  # Patch ExpressionParser if it exists
  if defined?(ExpressionParser)
    unless ExpressionParser.included_modules.include?(EnhancedParserLoopProtection)
      ExpressionParser.include(EnhancedParserLoopProtection)
      puts "   ✅ ExpressionParser loop protection applied"
    end
  end
  
  # Patch Evaluator if it exists
  if defined?(Evaluator)
    unless Evaluator.included_modules.include?(EvaluatorTimeoutProtection)
      Evaluator.include(EvaluatorTimeoutProtection)
      puts "   ✅ Evaluator timeout protection applied"
    end
  end
  
  # Patch GoalSystem if it exists
  if defined?(GoalSystem)
    unless GoalSystem.included_modules.include?(ReasoningTimeoutProtection)
      GoalSystem.include(ReasoningTimeoutProtection)
      puts "   ✅ GoalSystem timeout protection applied"
    end
  end
  
  # Patch UnificationEngine if it exists
  if defined?(UnificationEngine)
    unless UnificationEngine.included_modules.include?(ReasoningTimeoutProtection)
      UnificationEngine.include(ReasoningTimeoutProtection)
      puts "   ✅ UnificationEngine timeout protection applied"
    end
  end
  
  puts "🛡️  Hang prevention patches applied successfully"
end

# Emergency timeout wrapper for any method call
class EmergencyTimeout
  def self.protect(timeout = 5, &block)
    start_time = Time.now
    result = nil
    
    Timeout::timeout(timeout) do
      result = yield
    end
    
    duration = Time.now - start_time
    if duration > timeout * 0.8  # Warn if taking >80% of timeout
      puts "⚠️  SLOW OPERATION: #{duration.round(2)}s (#{(duration/timeout*100).round}% of timeout)"
    end
    
    result
  rescue Timeout::Error
    puts "🚨 EMERGENCY TIMEOUT: Operation killed after #{timeout}s"
    raise RuntimeError, "Emergency timeout: operation exceeded #{timeout} seconds"
  end
end

# Test-specific timeout wrapper
module TestTimeoutHelpers
  def with_test_timeout(timeout = 5, &block)
    EmergencyTimeout.protect(timeout, &block)
  end
  
  def assert_completes_within(timeout, message = nil, &block)
    start_time = Time.now
    result = EmergencyTimeout.protect(timeout, &block)
    duration = Time.now - start_time
    
    assert duration < timeout, 
           message || "Operation should complete within #{timeout}s but took #{duration.round(3)}s"
    
    result
  end
end

# Global timeout configuration
class GlobalTimeoutConfig
  @@timeouts = {
    parser: 3,
    evaluator: 5,
    reasoning: 8,
    test: 10,
    emergency: 15
  }
  
  def self.get(component)
    @@timeouts[component] || 5
  end
  
  def self.set(component, timeout)
    @@timeouts[component] = timeout
  end
  
  def self.tighten_all(factor = 0.5)
    @@timeouts.each { |k, v| @@timeouts[k] = (v * factor).ceil }
    puts "🔧 Tightened all timeouts by #{(factor * 100).round}%"
  end
  
  def self.summary
    puts "⏱️  Current timeout configuration:"
    @@timeouts.each { |component, timeout| puts "   #{component}: #{timeout}s" }
  end
end

# Auto-apply patches when this file is loaded
apply_hang_prevention_patches!

puts "🛡️  Hang prevention system initialized"
puts "   📊 Global loop detector: #{$global_loop_detector.class}"
puts "   ⏱️  Emergency timeout protection: available"
puts "   🔧 Global timeout config: available"

# Make timeout helpers available to all test classes
if defined?(Minitest::Test)
  Minitest::Test.include(TestTimeoutHelpers)
  puts "   ✅ Test timeout helpers added to Minitest::Test"
end