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
  
  # Add build_message method for compatibility
  def build_message(head, template)
    "#{head}: #{template}"
  end
end

require_relative '../../src/exceptions'