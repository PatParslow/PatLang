# Patlang Test Suite Rakefile
# Provides convenient rake tasks for running categorized tests

require 'rake/testtask'

# Default task runs all tests
task default: 'test:all'

namespace :test do
  desc "Run all test categories with combined coverage"
  task :all do
    puts "🚀 Running all Patlang tests with combined coverage..."
    system("ruby test/run_category_tests.rb all") || exit(1)
  end

  desc "Run infrastructure tests (Lexer, Parser, AST)"
  task :infrastructure do
    puts "🔧 Running infrastructure tests..."
    system("ruby test/run_category_tests.rb infrastructure") || exit(1)
  end

  desc "Run Ruby implementation tests (Direct object testing)"
  task :ruby do
    puts "💎 Running Ruby implementation tests..."
    system("ruby test/run_category_tests.rb ruby_implementation") || exit(1)
  end

  desc "Run Patlang language tests (End-to-end syntax)"
  task :patlang do
    puts "🗣️ Running Patlang language tests..."
    system("ruby test/run_category_tests.rb patlang_language") || exit(1)
  end

  desc "Run legacy test suite (for comparison)"
  task :legacy do
    puts "📜 Running legacy test suite..."
    system("ruby test/run_all_tests.rb") || exit(1)
  end

  desc "Show test structure and statistics"
  task :info do
    puts "📊 PATLANG TEST SUITE STRUCTURE"
    puts "=" * 50
    puts
    
    categories = {
      'infrastructure' => 'Infrastructure Tests (Lexer, Parser, AST)',
      'ruby_implementation' => 'Ruby Implementation Tests (Direct Object Testing)', 
      'patlang_language' => 'Patlang Language Tests (End-to-End Syntax)'
    }
    
    total_files = 0
    categories.each do |dir, description|
      test_dir = "test/#{dir}"
      if Dir.exist?(test_dir)
        files = Dir.glob("#{test_dir}/test_*.rb")
        total_files += files.length
        puts "#{description}:"
        puts "  Directory: #{test_dir}"
        puts "  Files: #{files.length}"
        files.each { |f| puts "    - #{File.basename(f)}" }
        puts
      end
    end
    
    puts "SUMMARY:"
    puts "  Total test files: #{total_files}"
    puts "  Categories: #{categories.length}"
    puts
    puts "USAGE:"
    puts "  rake test:all           # Run all tests"
    puts "  rake test:infrastructure # Run infrastructure tests only"
    puts "  rake test:ruby          # Run Ruby implementation tests only"
    puts "  rake test:patlang       # Run Patlang language tests only"
    puts "  rake test:legacy        # Run legacy test suite"
    puts "  rake test:info          # Show this information"
    puts
  end

  desc "Clean coverage reports"
  task :clean do
    puts "🧹 Cleaning coverage reports..."
    coverage_dirs = Dir.glob("test/coverage/*")
    coverage_dirs.each do |dir|
      if Dir.exist?(dir)
        puts "  Removing #{dir}"
        FileUtils.rm_rf(dir)
      end
    end
    puts "✅ Coverage reports cleaned"
  end

  desc "Validate test reorganization"
  task :validate do
    puts "✅ VALIDATING TEST REORGANIZATION"
    puts "=" * 50
    puts
    
    # Check directory structure
    required_dirs = %w[infrastructure ruby_implementation patlang_language helpers]
    required_dirs.each do |dir|
      test_dir = "test/#{dir}"
      if Dir.exist?(test_dir)
        puts "✓ Directory exists: #{test_dir}"
      else
        puts "✗ Missing directory: #{test_dir}"
      end
    end
    puts
    
    # Check that test_helper exists in helpers
    helper_file = "test/helpers/test_helper.rb"
    if File.exist?(helper_file)
      puts "✓ Helper file exists: #{helper_file}"
    else
      puts "✗ Missing helper file: #{helper_file}"
    end
    puts
    
    # Count files in each category
    categories = %w[infrastructure ruby_implementation patlang_language]
    total_test_files = 0
    
    categories.each do |category|
      test_dir = "test/#{category}"
      if Dir.exist?(test_dir)
        files = Dir.glob("#{test_dir}/test_*.rb")
        total_test_files += files.length
        puts "✓ #{category}: #{files.length} test files"
      else
        puts "✗ #{category}: directory missing"
      end
    end
    
    puts
    puts "VALIDATION SUMMARY:"
    puts "  Total categorized test files: #{total_test_files}"
    puts "  Expected: ~27 files (based on migration report)"
    
    if total_test_files >= 25
      puts "✅ Test reorganization appears successful!"
    else
      puts "⚠️  Test reorganization may be incomplete"
    end
    puts
  end
end

# Legacy task aliases for backward compatibility
task :test => 'test:all'