#!/usr/bin/env ruby

require 'fileutils'

class TestRequirePathFixer
  def initialize
    @fixes_applied = 0
    @test_files_processed = 0
    @errors = []
    @fixes_log = []
    
    # Define the migration mapping
    @path_mappings = {
      # Core language files moved to patlang-core/
      'require_relative \'../../src/lexer\'' => 'require_relative \'../../patlang-core/lexer/lexer\'',
      'require_relative \'../../src/token\'' => 'require_relative \'../../patlang-core/lexer/token\'',
      'require_relative \'../../src/ast_nodes\'' => 'require_relative \'../../patlang-core/ast/ast_nodes\'',
      'require_relative \'../../src/parser\'' => 'require_relative \'../../patlang-core/parser/parser\'',
      'require_relative \'../../src/evaluator\'' => 'require_relative \'../../patlang-core/evaluator/evaluator\'',
      'require_relative \'../../src/exceptions\'' => 'require_relative \'../../patlang-core/exceptions\'',
      
      # For files one level deeper (like test/infrastructure/, test/patlang_language/)
      'require_relative \'../../../src/lexer\'' => 'require_relative \'../../../patlang-core/lexer/lexer\'',
      'require_relative \'../../../src/token\'' => 'require_relative \'../../../patlang-core/lexer/token\'',
      'require_relative \'../../../src/ast_nodes\'' => 'require_relative \'../../../patlang-core/ast/ast_nodes\'',
      'require_relative \'../../../src/parser\'' => 'require_relative \'../../../patlang-core/parser/parser\'',
      'require_relative \'../../../src/evaluator\'' => 'require_relative \'../../../patlang-core/evaluator/evaluator\'',
      'require_relative \'../../../src/exceptions\'' => 'require_relative \'../../../patlang-core/exceptions\'',
      
      # Additional specific mappings
      'require_relative \'../../src/reasoning\'' => 'require_relative \'../../patlang-core/reasoning/reasoning\'',
      'require_relative \'../../src/object_model\'' => 'require_relative \'../../patlang-core/object_model/patlang_object\'',
      'require_relative \'../../../src/reasoning\'' => 'require_relative \'../../../patlang-core/reasoning/reasoning\'',
      'require_relative \'../../../src/object_model\'' => 'require_relative \'../../../patlang-core/object_model/patlang_object\'',
      
      # Specific module files
      'require_relative \'../../src/scope_manager\'' => 'require_relative \'../../patlang-core/evaluator/scope_manager\'',
      'require_relative \'../../../src/scope_manager\'' => 'require_relative \'../../../patlang-core/evaluator/scope_manager\'',
      'require_relative \'../../src/token_resolver\'' => 'require_relative \'../../patlang-core/parser/token_resolver\'',
      'require_relative \'../../../src/token_resolver\'' => 'require_relative \'../../../patlang-core/parser/token_resolver\'',
      
      # Ruby host files
      'require_relative \'../../src/patlang\'' => 'require_relative \'../../ruby-host/bootstrap/patlang\'',
      'require_relative \'../../../src/patlang\'' => 'require_relative \'../../../ruby-host/bootstrap/patlang\'',
    }
  end
  
  def run
    puts "🔧 Test Require Path Fixer - Analyzing test files after codebase migration"
    puts "=" * 80
    
    # Find all test files
    test_files = find_test_files
    puts "📁 Found #{test_files.size} test files to check"
    
    # Process each test file
    test_files.each { |file| process_test_file(file) }
    
    # Generate report
    generate_report
  end
  
  private
  
  def find_test_files
    Dir.glob("test/**/*.rb").select { |f| File.file?(f) }
  end
  
  def process_test_file(file_path)
    begin
      @test_files_processed += 1
      content = File.read(file_path)
      original_content = content.dup
      
      # Apply all path mappings
      @path_mappings.each do |old_path, new_path|
        if content.include?(old_path)
          content.gsub!(old_path, new_path)
          @fixes_applied += 1
          @fixes_log << "#{file_path}: #{old_path} → #{new_path}"
          puts "  ✅ Fixed: #{file_path}"
        end
      end
      
      # Write back if changes were made
      if content != original_content
        File.write(file_path, content)
        puts "    💾 Updated: #{file_path}"
      end
      
    rescue => e
      @errors << "Error processing #{file_path}: #{e.message}"
      puts "  ❌ Error: #{file_path} - #{e.message}"
    end
  end
  
  def generate_report
    puts "\n" + "=" * 80
    puts "📊 TEST REQUIRE PATH FIX SUMMARY"
    puts "=" * 80
    puts "Test files processed: #{@test_files_processed}"
    puts "Require path fixes applied: #{@fixes_applied}"
    puts "Errors encountered: #{@errors.size}"
    
    if @fixes_log.any?
      puts "\n📝 FIXES APPLIED:"
      @fixes_log.each { |fix| puts "  • #{fix}" }
    end
    
    if @errors.any?
      puts "\n❌ ERRORS:"
      @errors.each { |error| puts "  • #{error}" }
    end
    
    puts "\n✅ Test require path fixing complete!"
  end
end

# Run the fixer
if __FILE__ == $0
  fixer = TestRequirePathFixer.new
  fixer.run
end