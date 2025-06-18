#!/usr/bin/env ruby

require 'minitest/autorun'
require 'simplecov'
require_relative 'helpers/config_loader'

# Configure SimpleCov using configuration
simplecov_config = TestConfigLoader.simplecov_config
coverage_reporting = TestConfigLoader.coverage_reporting
coverage_thresholds = TestConfigLoader.coverage_thresholds

SimpleCov.start do
  # Apply filters from configuration
  simplecov_config[:filters].each { |filter| add_filter filter }
  
  # Apply groups from configuration
  simplecov_config[:groups].each { |name, pattern| add_group name, pattern }
  
  # Apply tracking and coverage settings
  track_files simplecov_config[:track_files]
  coverage_dir coverage_reporting[:output_directory]
  command_name coverage_reporting[:command_name]
  
  # Enable branch coverage if configured
  if simplecov_config[:enable_branch_coverage]
    enable_coverage :branch
    enable_coverage :line
  end
  
  # Set minimum coverage thresholds
  minimum_coverage(
    line: coverage_thresholds[:minimum_line],
    branch: coverage_thresholds[:minimum_branch]
  )
end

class Phase1TestRunner
  def self.run
    # Load configuration
    phase1_config = TestConfigLoader.test_category('phase_1')
    coverage_targets = TestConfigLoader.all_coverage_targets(:line)
    
    puts "🚀 #{phase1_config['name']}"
    puts "=" * 60
    puts "#{phase1_config['description']}"
    puts "Target Coverage:"
    coverage_targets.each do |component, target|
      icon = case component
             when "AST Nodes" then "📊"
             when "Lexer" then "🔤"
             when "Token" then "🏷️"
             else "📋"
             end
      puts "  #{icon} #{component}: #{target}%+"
    end
    puts "=" * 60

    # Load test helper
    require_relative 'helpers/test_helper'
    
    # Explicitly require source files for coverage tracking
    puts "📝 Loading source files for coverage tracking..."
    require_relative '../src/ast_nodes'
    require_relative '../patlang-core/lexer/lexer'
    require_relative '../patlang-core/lexer/token'
    
    # Load Phase 1 core tests
    puts "📝 Loading Phase 1 test suites..."
    require_relative 'core/test_ast_nodes_comprehensive'
    require_relative 'core/test_lexer_comprehensive'
    
    puts "✅ Test suites loaded successfully"
    puts
    puts "🧪 Running Phase 1 Foundation Tests..."
    puts "   - AST Nodes Comprehensive Tests"
    puts "   - Lexer Comprehensive Tests"
    puts

    # Run tests
    start_time = Time.now
    
    # Run Minitest
    result = Minitest.run([])
    
    end_time = Time.now
    execution_time = (end_time - start_time).round(2)
    
    puts "⏱️  Test execution completed in #{execution_time} seconds"
    
    # Generate coverage report
    puts "📊 Generating Phase 1 coverage report..."
    
    # Force SimpleCov to generate the report
    SimpleCov.result.format!
    
    puts "✅ Coverage report generated in: coverage/"
    puts
    
    # Analyze coverage for Phase 1 components
    analyze_phase1_coverage
    
    result
  end
  
  private
  
  def self.analyze_phase1_coverage
    puts "📈 PHASE 1 COVERAGE ANALYSIS"
    puts "=" * 50
    
    coverage_result = SimpleCov.result
    total_coverage = coverage_result.covered_percent
    
    puts "🎯 Overall Coverage: #{total_coverage.round(1)}%"
    puts
    
    # Phase 1 specific file analysis - using exact filename matching
    phase1_files = {
      'AST Nodes' => find_file_coverage_by_name(coverage_result, 'ast_nodes.rb'),
      'Lexer' => find_file_coverage_by_name(coverage_result, 'lexer.rb'),
      'Token' => find_file_coverage_by_name(coverage_result, 'token.rb')
    }
    
    phase1_results = {}
    target_coverage = TestConfigLoader.all_coverage_targets(:line)
    
    phase1_files.each do |component, coverage|
      if coverage
        status = coverage >= target_coverage[component] ? "✅" : "❌"
        target_status = coverage >= target_coverage[component] ? "TARGET MET" : "NEEDS WORK"
        puts "#{status} #{component}: #{coverage.round(1)}% (#{target_status})"
        phase1_results[component] = coverage >= target_coverage[component]
      else
        puts "❌ #{component}: No coverage data available"
        phase1_results[component] = false
      end
    end
    
    puts
    puts "📋 PHASE 1 DETAILED ANALYSIS"
    puts "-" * 40
    
    # Show current vs target for each component
    phase1_files.each do |component, coverage|
      target = target_coverage[component]
      if coverage
        gap = target - coverage
        if gap <= 0
          puts "✅ #{component}: #{coverage.round(1)}% (#{gap.abs.round(1)}% above target)"
        else
          puts "🔧 #{component}: #{coverage.round(1)}% (#{gap.round(1)}% below target - needs #{gap.round(1)}% more)"
        end
      end
    end
    
    puts
    puts "📋 PHASE 1 SUMMARY"
    puts "-" * 30
    
    passed_count = phase1_results.values.count(true)
    total_count = phase1_results.size
    success_rate = (passed_count.to_f / total_count * 100).round(1)
    
    puts "🎖️  Component Results:"
    phase1_results.each do |component, passed|
      status = passed ? "✅ PASSED" : "❌ FAILED"
      puts "     #{component}: #{status}"
    end
    
    puts
    puts "🎖️  Phase 1 Success Rate: #{passed_count}/#{total_count} (#{success_rate}%)"
    
    if success_rate >= 80
      puts "🎉 PHASE 1 COMPLETE - Excellent foundation coverage!"
      recommendation = "Ready to proceed to Phase 2"
    elsif success_rate >= 60
      puts "🔧 PHASE 1 NEEDS WORK - Review and enhance test coverage"
      recommendation = "Focus on failed components before Phase 2"
    else
      puts "⚠️  PHASE 1 CRITICAL - Major coverage gaps need attention"
      recommendation = "Must improve coverage before proceeding"
    end
    
    puts "💡 Recommendation: #{recommendation}"
    
    # Save results
    save_phase1_results(phase1_results, success_rate, total_coverage, phase1_files)
    
    puts "💾 Phase 1 results saved to: test/phase_1_results.json"
  end
  
  def self.find_file_coverage_by_name(coverage_result, target_filename)
    # Search through all covered files for the one with matching basename
    coverage_result.files.each do |file|
      if File.basename(file.filename) == target_filename
        return file.covered_percent
      end
    end
    nil
  end
  
  def self.save_phase1_results(results, success_rate, total_coverage, detailed_coverage)
    require 'json'
    
    # Create detailed coverage hash with actual percentages
    coverage_details = {}
    detailed_coverage.each do |component, coverage|
      coverage_details[component] = coverage ? coverage.round(1) : 0.0
    end
    
    data = {
      timestamp: Time.now.iso8601,
      success_rate: success_rate,
      total_coverage: total_coverage.round(1),
      component_results: results,
      coverage_details: coverage_details,
      targets: TestConfigLoader.all_coverage_targets(:line),
      status: success_rate >= 80 ? 'PASSED' : success_rate >= 60 ? 'NEEDS_WORK' : 'CRITICAL',
      recommendation: success_rate >= 80 ? 'Ready for Phase 2' : 'Enhance coverage before Phase 2'
    }
    
    File.write('test/phase_1_results.json', JSON.pretty_generate(data))
  end
end

# Run Phase 1 tests if this file is executed directly
if __FILE__ == $0
  Phase1TestRunner.run
end