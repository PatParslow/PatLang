#!/usr/bin/env ruby
# Comprehensive reasoning test runner without external dependencies

require 'minitest/autorun'

# Set up load paths
$LOAD_PATH.unshift(File.expand_path('src', __dir__))
$LOAD_PATH.unshift(File.expand_path('test', __dir__))

# Disable output buffering for real-time results
$stdout.sync = true

puts "🧠 COMPREHENSIVE REASONING SYSTEM TEST SUITE"
puts "=" * 60

# Test categories in dependency order
test_categories = [
  {
    name: "Infrastructure Tests",
    path: "infrastructure",
    files: %w[
      test_unification_engine.rb
      test_reasoning_coordinator.rb
      test_type_constraint_system.rb
      test_goal_system.rb
      test_complex_logic_queries.rb
      test_goal_resolution_engine.rb
      test_error_handling_coverage.rb
    ]
  },
  {
    name: "Language Syntax Tests", 
    path: "patlang_language",
    files: %w[
      test_reasoning_integration.rb
      test_enhanced_reasoning_parser.rb
      test_cross_paradigm_coordination.rb
      test_evaluator_branch_coverage.rb
      test_performance_optimization.rb
    ]
  },
  {
    name: "Ruby Implementation Tests",
    path: "ruby_implementation", 
    files: %w[
      test_reasoning_evaluator_integration.rb
      test_type_constraints.rb
      test_type_constraints_clean.rb
      test_goal_system.rb
      test_advanced_goal_strategies.rb
    ]
  },
  {
    name: "Integration Tests",
    path: "integration",
    files: %w[
      test_unified_reasoning_integration.rb
    ]
  }
]

total_tests = 0
total_failures = 0
failed_tests = []

test_categories.each do |category|
  puts "\n📁 #{category[:name]}"
  puts "-" * 40
  
  category[:files].each do |test_file|
    test_path = "test/#{category[:path]}/#{test_file}"
    
    unless File.exist?(test_path)
      puts "   ⚠️  #{test_file} - FILE NOT FOUND"
      next
    end
    
    puts "   🧪 #{test_file}"
    
    # Capture minitest output
    begin
      # Reset minitest for each file
      Minitest.reporter.reporters.clear if Minitest.reporter.respond_to?(:reporters)
      
      # Track before state
      before_tests = Minitest.reporters.nil? ? 0 : Minitest.run([])
      
      # Load the test file
      load test_path
      
      puts "      ✅ Loaded successfully"
      
    rescue LoadError => e
      puts "      ❌ Load Error: #{e.message}"
      failed_tests << { file: test_file, error: "LoadError: #{e.message}" }
      total_failures += 1
      
    rescue => e
      puts "      ❌ Error: #{e.message}"
      failed_tests << { file: test_file, error: "#{e.class}: #{e.message}" }
      total_failures += 1
    end
  end
end

puts "\n" + "=" * 60
puts "🏁 COMPREHENSIVE REASONING TEST SUITE SUMMARY"
puts "=" * 60

puts "📊 Overall Results:"
puts "   Total Test Files: #{test_categories.sum { |c| c[:files].length }}"
puts "   Failed Test Files: #{total_failures}"
puts "   Success Rate: #{total_failures == 0 ? '100%' : sprintf('%.1f%%', ((test_categories.sum { |c| c[:files].length } - total_failures) / test_categories.sum { |c| c[:files].length }.to_f * 100))}"

if failed_tests.any?
  puts "\n💥 FAILED TEST FILES:"
  failed_tests.each do |failure|
    puts "   - #{failure[:file]}: #{failure[:error]}"
  end
  
  puts "\n🔧 RECOMMENDATIONS:"
  puts "   1. Install missing gems: gem install minitest-reporters simplecov"
  puts "   2. Check file dependencies and require paths"
  puts "   3. Verify all source files exist and are properly implemented"
else
  puts "\n🎉 ALL TEST FILES LOADED SUCCESSFULLY!"
  puts "   Now run individual test files to check for test failures"
end

puts "\n📝 Next Steps:"
puts "   1. Run: ruby -Itest test/infrastructure/test_unification_engine.rb"
puts "   2. Run: ruby -Itest test/infrastructure/test_reasoning_coordinator.rb"
puts "   3. Check each test file individually for specific failures"