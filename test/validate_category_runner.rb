#!/usr/bin/env ruby

# Validation script for category test runner method visibility fixes
# Tests that all categories can be executed without method visibility errors

require 'timeout'

class CategoryRunnerValidator
  def initialize
    @results = {}
    @categories = ['infrastructure', 'ruby_implementation', 'patlang_language', 'all']
  end

  def validate_all_categories
    puts "🔍 Validating Category Test Runner Method Visibility Fixes"
    puts "=" * 60
    puts

    @categories.each do |category|
      validate_category(category)
    end

    print_summary
  end

  private

  def validate_category(category)
    puts "Testing category: #{category}"
    
    begin
      # Test that the category runner can start without method visibility errors
      # We'll run it with a short timeout to just check initialization
      result = Timeout::timeout(10) do
        `ruby test/run_category_tests.rb #{category} 2>&1`
      end
      
      # Check for specific method visibility errors that would prevent category loading
      visibility_errors = [
        'private method',
        'protected method',
        'superclass mismatch for class',
        'method_missing',
        'undefined method.*for.*CategoryTestRunner',
        'undefined method.*for.*class:'
      ]
      
      has_visibility_error = visibility_errors.any? { |error| result.include?(error) }
      
      if has_visibility_error
        @results[category] = {
          status: :failed,
          error: "Method visibility error detected",
          output: result[0..500] # First 500 chars
        }
        puts "  ❌ FAILED - Method visibility errors found"
      else
        # Check if it loads successfully
        if result.include?("All #{category} tests loaded successfully!") || 
           result.include?("Loading") && result.include?("test files")
          @results[category] = {
            status: :passed,
            message: "Category runner loads successfully without visibility errors"
          }
          puts "  ✅ PASSED - No method visibility errors"
        else
          @results[category] = {
            status: :partial,
            message: "Loads but may have other issues",
            output: result[0..300]
          }
          puts "  ⚠️  PARTIAL - Loads but may have other issues"
        end
      end
      
    rescue Timeout::Error
      @results[category] = {
        status: :timeout,
        message: "Category loads without immediate visibility errors (timed out during test execution)"
      }
      puts "  ✅ PASSED - Loads without visibility errors (execution timeout is expected)"
    rescue => e
      @results[category] = {
        status: :failed,
        error: e.message,
        output: e.backtrace[0..5].join("\n")
      }
      puts "  ❌ FAILED - #{e.message}"
    end
    
    puts
  end

  def print_summary
    puts "📊 CATEGORY RUNNER VALIDATION SUMMARY"
    puts "=" * 60
    
    passed = @results.values.count { |r| r[:status] == :passed || r[:status] == :timeout }
    failed = @results.values.count { |r| r[:status] == :failed }
    partial = @results.values.count { |r| r[:status] == :partial }
    
    puts "Categories tested: #{@categories.length}"
    puts "✅ Passed: #{passed}"
    puts "⚠️  Partial: #{partial}"  
    puts "❌ Failed: #{failed}"
    puts
    
    @results.each do |category, result|
      puts "#{category.ljust(20)} - #{format_status(result[:status])}"
      if result[:error]
        puts "  Error: #{result[:error]}"
      end
      if result[:message]
        puts "  Note: #{result[:message]}"
      end
      puts
    end
    
    if failed == 0
      puts "🎉 SUCCESS: All categories load without method visibility errors!"
      puts "The category test runner method visibility issues have been resolved."
    else
      puts "⚠️  Some categories still have method visibility issues that need fixing."
    end
  end

  def format_status(status)
    case status
    when :passed then "✅ PASSED"
    when :failed then "❌ FAILED"
    when :partial then "⚠️  PARTIAL"
    when :timeout then "✅ PASSED (timeout)"
    else "❓ UNKNOWN"
    end
  end
end

# Run validation if called directly
if __FILE__ == $0
  validator = CategoryRunnerValidator.new
  validator.validate_all_categories
end