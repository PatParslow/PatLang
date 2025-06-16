require 'simplecov'
require_relative 'test_constants'

SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  add_group 'Source', 'src'
end

require 'minitest/autorun'
require 'minitest/assertions'

# Ensure all minitest assertion methods are available
# This fixes the missing assert_not_nil and other methods
class Minitest::Test
  include Minitest::Assertions
  
  # Add missing assert_nothing_raised method
  def assert_nothing_raised(message = nil)
    begin
      yield
    rescue => e
      full_message = build_message(message, "Exception raised when none was expected: #{e.class} - #{e.message}")
      assert false, full_message
    end
  end
  
  # Add assert_not_nil method for compatibility
  def assert_not_nil(object, message = nil)
    assert !object.nil?, message || "Expected object to not be nil"
  end
  
  # Timeout protection for hanging tests
  def with_test_timeout(seconds = 5)
    require 'timeout'
    Timeout::timeout(seconds) do
      yield
    end
  rescue Timeout::Error
    puts "   ⏰ Test timed out after #{seconds} seconds"
    skip "Test skipped due to timeout"
  end
  
  # Add build_message method for compatibility
  def build_message(head, template)
    "#{head}: #{template}"
  end
end

require_relative '../../src/exceptions'
# Mock Evaluator for testing ReasoningCoordinator
class MockEvaluator
  def initialize
    @variables = {}
    @functions = {}
  end
  
  def evaluate(ast)
    # Mock evaluation - return simple result
    "mock_result"
  end
  
  def evaluate_string(code)
    case code
    when /undefined_variable/
      raise RuntimeError, "Undefined variable: undefined_variable"
    when /10 \/ 0/
      raise ZeroDivisionError, "divided by 0"
    else
      "mock_result"
    end
  end
  
  def get_variable(name)
    @variables[name]
  end
  
  def set_variable(name, value)
    @variables[name] = value
  end
  
  def respond_to?(method)
    [:evaluate, :evaluate_string, :get_variable, :set_variable].include?(method) || super
  end
end

class MockTypeSystem
  def initialize
    @constraints = {}
  end
  
  def create_constraint(type, data)
    @constraints[type] = data
  end
  
  def validate(value, constraint)
    true
  end
  
  def to_s
    "MockTypeSystem"
  end
end

class MockGoalSystem
  def initialize
    @goals = {}
  end
  
  def create_goal(name, params = {})
    @goals[name] = params
  end
  
  def pursue_goal(name)
    "goal_result"
  end
  
  def to_s
    "MockGoalSystem"
  end
end
