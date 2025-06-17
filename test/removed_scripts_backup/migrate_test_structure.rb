#!/usr/bin/env ruby

# Test Suite Reorganization Migration Script
# Moves test files from flat structure to categorized structure

require 'fileutils'

class TestSuiteMigrator
  def initialize
    @base_path = File.dirname(__FILE__)
    @moves_performed = []
    @errors = []
  end

  def migrate!
    puts "=== PATLANG TEST SUITE REORGANIZATION ==="
    puts "Migrating from flat structure to categorized structure..."
    puts

    # Ensure directories exist
    ensure_directories_exist

    # Perform migrations by category
    migrate_infrastructure_tests
    migrate_ruby_implementation_tests  
    migrate_patlang_language_tests
    migrate_helpers

    # Report results
    report_results
  end

  private

  def ensure_directories_exist
    dirs = %w[infrastructure ruby_implementation patlang_language helpers]
    dirs.each do |dir|
      dir_path = File.join(@base_path, dir)
      FileUtils.mkdir_p(dir_path) unless Dir.exist?(dir_path)
      puts "✓ Directory ensured: #{dir}"
    end
    puts
  end

  def migrate_infrastructure_tests
    puts "Migrating Infrastructure Tests (Lexer, Parser, AST)..."
    
    infrastructure_files = [
      'test_lexer.rb',
      'test_lexer_comprehensive.rb',
      'test_lexer_error_recovery.rb', 
      'test_parser.rb',
      'test_parser_edge_cases.rb',
      'test_ast_nodes.rb',
      'test_function_lexer.rb',
      'test_function_parser.rb'
    ]

    move_files(infrastructure_files, 'infrastructure')
  end

  def migrate_ruby_implementation_tests
    puts "Migrating Ruby Implementation Tests (Direct Object Testing)..."
    
    ruby_impl_files = [
      'test_object_model.rb',
      'test_object_model_comprehensive.rb',
      'test_object_model_stress.rb',
      'test_function_evaluator.rb',
      'test_evaluator_edge_cases.rb',
      'test_evaluator_stress.rb',
      'test_string_operations.rb',
      'test_string_literals.rb',
      'test_extended_string_methods.rb'
    ]

    move_files(ruby_impl_files, 'ruby_implementation')
  end

  def migrate_patlang_language_tests
    puts "Migrating Patlang Language Tests (End-to-End Syntax)..."
    
    patlang_files = [
      'test_evaluator.rb',
      'test_object_evaluation.rb',
      'test_flexible_function_syntax.rb',
      'test_control_flow_evaluator.rb',
      'test_is_keyword_implementation.rb',
      'test_integration.rb',
      'test_function_integration.rb',
      'test_function_validation.rb',
      'test_flexible_with_calls.rb',
      'test_regression_core.rb'
    ]

    move_files(patlang_files, 'patlang_language')
  end

  def migrate_helpers
    puts "Migrating Helper Files..."
    
    # Move test_helper.rb to helpers directory
    move_file('test_helper.rb', 'helpers')
  end

  def move_files(files, category)
    files.each do |filename|
      move_file(filename, category)
    end
    puts
  end

  def move_file(filename, category)
    source = File.join(@base_path, filename)
    destination = File.join(@base_path, category, filename)
    
    if File.exist?(source)
      begin
        FileUtils.mv(source, destination)
        @moves_performed << { file: filename, category: category }
        puts "  ✓ Moved #{filename} → #{category}/"
      rescue => e
        @errors << { file: filename, error: e.message }
        puts "  ✗ Failed to move #{filename}: #{e.message}"
      end
    else
      puts "  - Skipped #{filename} (not found)"
    end
  end

  def report_results
    puts "=== MIGRATION SUMMARY ==="
    puts "✓ Successfully moved #{@moves_performed.length} files"
    
    if @errors.any?
      puts "✗ #{@errors.length} errors occurred:"
      @errors.each do |error|
        puts "  - #{error[:file]}: #{error[:error]}"
      end
    end
    
    puts
    puts "Files moved by category:"
    by_category = @moves_performed.group_by { |move| move[:category] }
    by_category.each do |category, moves|
      puts "  #{category}: #{moves.length} files"
      moves.each { |move| puts "    - #{move[:file]}" }
    end
    
    puts
    puts "=== NEXT STEPS ==="
    puts "1. Update require paths in moved files"
    puts "2. Create category-specific test runners"
    puts "3. Configure SimpleCov for category coverage"
    puts "4. Verify all tests still pass"
    puts
    puts "Run 'ruby test/update_require_paths.rb' to update require statements"
  end
end

# Execute migration if script is run directly
if __FILE__ == $0
  migrator = TestSuiteMigrator.new
  migrator.migrate!
end