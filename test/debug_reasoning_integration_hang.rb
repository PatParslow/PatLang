#!/usr/bin/env ruby

# Debug script to identify hanging test methods in test_reasoning_integration.rb
# Uses EmergencyTimeout to prevent individual test method hangs

require_relative '../src/emergency_timeout'
require 'minitest/autorun'

puts "🔍 DEBUGGING REASONING INTEGRATION HANGS"
puts "=" * 60

# Override Minitest::Test to add per-method timeout protection
class Minitest::Test
  alias_method :original_run, :run
  
  def run
    puts "🧪 Testing #{self.class.name}##{self.name}"
    start_time = Time.now
    
    begin
      # Use EmergencyTimeout to protect each test method
      result = EmergencyTimeout.protect(15, error_message: "Test method #{self.name} exceeded 15s timeout") do
        original_run
      end
      
      duration = Time.now - start_time
      puts "   ✅ COMPLETED in #{duration.round(3)}s"
      result
      
    rescue EmergencyTimeout::TimeoutError => e
      duration = Time.now - start_time
      puts "   ⚠️  TIMEOUT: #{e.message} (#{duration.round(3)}s)"
      # Mark as skip instead of error to continue with other tests
      self.failures << Minitest::Skip.new(e.message)
      "S"
      
    rescue => e
      duration = Time.now - start_time
      puts "   ❌ ERROR: #{e.class}: #{e.message} (#{duration.round(3)}s)"
      raise e
    end
  end
end

# Load the problematic test file with timeout protection
puts "📁 Loading test_reasoning_integration.rb with timeout protection..."

begin
  EmergencyTimeout.protect(30, error_message: "File loading exceeded 30s") do
    require_relative 'patlang_language/test_reasoning_integration'
  end
  
  puts "✅ File loaded successfully"
  
rescue EmergencyTimeout::TimeoutError => e
  puts "❌ File loading timeout: #{e.message}"
  exit 1
rescue => e
  puts "❌ File loading error: #{e.class}: #{e.message}"
  exit 1
end

puts "\n🎯 Running tests with individual method timeout protection..."
puts "   Each test method has a 15-second timeout limit"
puts "   Hanging methods will be identified and skipped"
puts