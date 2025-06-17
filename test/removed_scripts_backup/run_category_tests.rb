#!/usr/bin/env ruby

# Category-Specific Test Runner with Coverage
# Runs tests by category with separate coverage reporting

require 'simplecov'
require 'fileutils'

class CategoryTestRunner
  def initialize
    @base_path = File.dirname(__FILE__)
    @categories = {
      'infrastructure' => 'Infrastructure Tests (Lexer, Parser, AST)',
      'ruby_implementation' => 'Ruby Implementation Tests (Direct Object Testing)',
      'patlang_language' => 'Patlang Language Tests (End-to-End Syntax)',
      'all' => 'All Categories Combined'
    }
  end

  def run_category(category)
    category_description = @categories[category]
    unless category_description
      puts "❌ Unknown category: #{category}"
      puts "Available categories: #{@categories.keys.join(', ')}"
      return false
    end
    
    puts "=== RUNNING #{category_description.upcase} ==="
    puts

    case category
    when 'infrastructure'
      run_infrastructure_tests
    when 'ruby_implementation'
      run_ruby_implementation_tests
    when 'patlang_language'
      run_patlang_language_tests
    when 'all'
      run_all_categories
    end
  end

  def run_infrastructure_tests
    configure_coverage('infrastructure', 'Infrastructure Coverage')
    load_category_tests('infrastructure')
  end

  def run_ruby_implementation_tests
    configure_coverage('ruby_implementation', 'Ruby Implementation Coverage')
    load_category_tests('ruby_implementation')
  end

  def run_patlang_language_tests
    configure_coverage('patlang_language', 'Patlang Language Coverage')
    load_category_tests('patlang_language')
  end

  def run_all_categories
    configure_coverage('all', 'Combined Coverage Report')
    
    # Load all test categories
    %w[infrastructure ruby_implementation patlang_language].each do |category|
      puts "Loading #{category} tests..."
      load_category_tests(category)
    end
  end

  def show_usage
    puts "USAGE: ruby test/run_category_tests.rb [CATEGORY]"
    puts
    puts "Available categories:"
    @categories.each do |key, description|
      puts "  #{key.ljust(20)} - #{description}"
    end
    puts
    puts "Examples:"
    puts "  ruby test/run_category_tests.rb infrastructure"
    puts "  ruby test/run_category_tests.rb patlang_language"
    puts "  ruby test/run_category_tests.rb all"
    puts
  end

  private

  def configure_coverage(category, report_name)
    SimpleCov.start do
      enable_coverage :branch
      add_filter '/test/'
      track_files 'src/**/*.rb'
      
      # Category-specific coverage directory
      coverage_dir "test/coverage/#{category}"
      
      # Detailed coverage reporting
      formatter SimpleCov::Formatter::MultiFormatter.new([
        SimpleCov::Formatter::HTMLFormatter,
        SimpleCov::Formatter::SimpleFormatter
      ])
      
      # Category-specific coverage requirements
      case category
      when 'infrastructure'
        minimum_coverage line: 10, branch: 45  # Lower for unit tests (focused testing)
      when 'ruby_implementation'
        minimum_coverage line: 15, branch: 50  # Medium for implementation
      when 'patlang_language'
        minimum_coverage line: 25, branch: 45  # Higher for end-to-end
      when 'all'
        minimum_coverage line: 20, branch: 50  # Overall realistic target
      end

      # Add groups for better organization
      add_group 'Lexer', 'src/lexer.rb'
      add_group 'Parser', ['src/parser.rb', 'src/parser/']
      add_group 'Evaluator', ['src/evaluator.rb', 'src/evaluator/']
      add_group 'Object Model', 'src/object_model/'
      add_group 'Core', ['src/patlang.rb', 'src/token.rb', 'src/ast_nodes.rb']
    end

    puts "📊 Coverage configured for: #{report_name}"
    puts "   Report will be saved to: test/coverage/#{category}/"
    puts
  end

  def load_category_tests(category)
    # Always load test_helper first
    require_relative 'helpers/test_helper'
    
    category_dir = File.join(@base_path, category)
    unless Dir.exist?(category_dir)
      puts "❌ Category directory not found: #{category_dir}"
      return false
    end

    test_files = Dir.glob(File.join(category_dir, 'test_*.rb')).sort
    
    if test_files.empty?
      puts "⚠️  No test files found in #{category}"
      return false
    end

    puts "🧪 Loading #{test_files.length} test files from #{category}:"
    test_files.each do |file_path|
      filename = File.basename(file_path, '.rb')
      puts "   - #{filename}"
      require_relative File.join(category, File.basename(file_path))
    end
    
    puts "✅ All #{category} tests loaded successfully!"
    puts
    true
  end

end

# Main execution
if __FILE__ == $0
  category = ARGV[0]
  
  if category.nil?
    runner = CategoryTestRunner.new
    runner.show_usage
    exit 1
  end

  runner = CategoryTestRunner.new
  success = runner.run_category(category)
  
  unless success
    exit 1
  end
  
  puts "🎉 Test execution completed!"
  puts "📊 Check coverage reports in test/coverage/#{category}/"
end