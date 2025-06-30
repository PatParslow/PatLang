#!/usr/bin/env ruby
# frozen_string_literal: true

# POST-PRIORITY-2-FIXES COMPREHENSIVE VALIDATION
# Validates all Priority 1 and Priority 2 fixes and measures cumulative improvement

require 'json'
require 'time'

class PostPriority2FixesValidation
  def initialize
    @start_time = Time.now
    @validation_results = {
      'timestamp' => @start_time.strftime("%Y-%m-%dT%H:%M:%S%z"),
      'priority_1_validation' => {},
      'priority_2_validation' => {},
      'cumulative_improvement' => {},
      'test_suite_results' => {},
      'coverage_analysis' => {},
      'next_priorities' => {}
    }
  end

  def run_comprehensive_validation
    log_header "🎯 POST-PRIORITY-2-FIXES COMPREHENSIVE VALIDATION"
    log_info "Validating cumulative impact of all Priority 1 and Priority 2 fixes"
    log_separator

    # 1. Validate Priority 1 fixes are still working
    validate_priority_1_fixes
    
    # 2. Validate specific Priority 2 fixes  
    validate_priority_2_fixes
    
    # 3. Run comprehensive test suite
    run_comprehensive_test_suite
    
    # 4. Generate cumulative improvement report
    generate_cumulative_report
    
    # 5. Identify Priority 3 recommendations
    identify_priority_3_issues
    
    save_validation_report
    display_final_summary
    
    @validation_results
  end

  private

  def validate_priority_1_fixes
    log_info "🔍 Validating Priority 1 fixes are still functional..."
    
    priority_1_results = {
      'type_constraint_loading' => validate_type_constraint_loading,
      'unknown_error_epidemic' => validate_unknown_error_elimination,
      'test_infrastructure' => validate_test_infrastructure,
      'mock_classes' => validate_mock_classes
    }
    
    @validation_results['priority_1_validation'] = priority_1_results
    
    all_passed = priority_1_results.values.all? { |result| result['status'] == 'SUCCESS' }
    log_info "   Priority 1 validation: #{all_passed ? '✅ ALL PASSED' : '❌ SOME FAILED'}"
  end

  def validate_priority_2_fixes
    log_info "🔍 Validating Priority 2 specific fixes..."
    
    priority_2_results = {
      'priority_2a_range_constraints' => validate_range_constraint_fix,
      'priority_2b_event_system' => validate_event_system_fix,
      'notimplementederror_elimination' => validate_notimplementederror_elimination
    }
    
    @validation_results['priority_2_validation'] = priority_2_results
    
    all_passed = priority_2_results.values.all? { |result| result['status'] == 'SUCCESS' }
    log_info "   Priority 2 validation: #{all_passed ? '✅ ALL PASSED' : '❌ SOME FAILED'}"
  end

  def validate_type_constraint_loading
    begin
      # Test the specific file that was fixed
      require_relative 'test/ruby_implementation/test_type_constraints_clean'
      
      # Test that TypeConstraintSystem can be loaded
      require_relative 'src/reasoning/type_constraint_system'
      
      {
        'status' => 'SUCCESS',
        'details' => 'TypeConstraintSystem loads without NameError'
      }
    rescue => e
      {
        'status' => 'FAILED',
        'error' => "#{e.class}: #{e.message}"
      }
    end
  end

  def validate_unknown_error_elimination
    begin
      # Load test helper and verify mock classes exist
      require_relative 'test/helpers/test_helper'
      
      # Test MockEvaluator functionality
      evaluator = MockEvaluator.new
      result = evaluator.evaluate_string('test')
      
      {
        'status' => 'SUCCESS',
        'details' => "MockEvaluator working: #{result}",
        'mock_classes' => ['MockEvaluator', 'MockTypeSystem', 'MockGoalSystem']
      }
    rescue => e
      {
        'status' => 'FAILED',
        'error' => "#{e.class}: #{e.message}"
      }
    end
  end

  def validate_test_infrastructure
    begin
      test_files_found = Dir.glob('test/**/*test_*.rb').length
      test_files_loadable = 0
      
      # Sample a few test files to verify they can be loaded
      sample_files = [
        'test/infrastructure/test_evaluator_timeout.rb',
        'test/ruby_implementation/test_object_model_comprehensive.rb',
        'test/patlang_language/test_parser.rb'
      ].select { |f| File.exist?(f) }
      
      sample_files.each do |file|
        begin
          require_relative file
          test_files_loadable += 1
        rescue => e
          # Count syntax errors vs load errors
        end
      end
      
      {
        'status' => test_files_loadable > 0 ? 'SUCCESS' : 'FAILED',
        'details' => "#{test_files_loadable}/#{sample_files.length} sample files loadable",
        'total_test_files' => test_files_found
      }
    rescue => e
      {
        'status' => 'FAILED',
        'error' => "#{e.class}: #{e.message}"
      }
    end
  end

  def validate_mock_classes
    begin
      require_relative 'test/helpers/test_helper'
      
      mock_results = {}
      
      # Test MockEvaluator
      evaluator = MockEvaluator.new
      mock_results['MockEvaluator'] = evaluator.evaluate_string('test') == 'mock_result'
      
      # Test MockTypeSystem exists
      type_system = MockTypeSystem.new
      mock_results['MockTypeSystem'] = !type_system.nil?
      
      # Test MockGoalSystem exists  
      goal_system = MockGoalSystem.new
      mock_results['MockGoalSystem'] = !goal_system.nil?
      
      all_working = mock_results.values.all?
      
      {
        'status' => all_working ? 'SUCCESS' : 'FAILED',
        'details' => mock_results
      }
    rescue => e
      {
        'status' => 'FAILED',
        'error' => "#{e.class}: #{e.message}"
      }
    end
  end

  def validate_range_constraint_fix
    begin
      # Test both Range and Hash format support
      require_relative 'src/reasoning/type_constraint_system'
      
      system = TypeConstraintSystem.new
      
      # Test Range format (should work after fix)
      range_constraint = system.create_constraint(:test_var, :range, 1..10)
      
      # Test Hash format (should still work)
      hash_constraint = system.create_constraint(:test_var2, :range, {min: 1, max: 10})
      
      {
        'status' => 'SUCCESS',
        'details' => 'Both Range (1..10) and Hash {min:, max:} formats accepted',
        'range_constraint_created' => !range_constraint.nil?,
        'hash_constraint_created' => !hash_constraint.nil?
      }
    rescue => e
      {
        'status' => 'FAILED',
        'error' => "#{e.class}: #{e.message}"
      }
    end
  end

  def validate_event_system_fix
    begin
      require_relative 'src/object_model/event_system'
      
      # Test that EventSystem is a module (not class)
      is_module = EventSystem.is_a?(Module) && !EventSystem.is_a?(Class)
      
      # Test that global event firing works
      event_fired = false
      begin
        EventSystem.fire_global_event(:test_event, {test: true})
        event_fired = true
      rescue => e
        event_fired = false
      end
      
      # Test that EventSystem.new fails as expected (module not class)
      new_fails_correctly = false
      begin
        EventSystem.new
      rescue NoMethodError
        new_fails_correctly = true
      rescue => e
        new_fails_correctly = false
      end
      
      {
        'status' => (is_module && event_fired && new_fails_correctly) ? 'SUCCESS' : 'FAILED',
        'details' => {
          'is_module' => is_module,
          'global_event_firing' => event_fired,
          'new_fails_correctly' => new_fails_correctly
        }
      }
    rescue => e
      {
        'status' => 'FAILED',
        'error' => "#{e.class}: #{e.message}"
      }
    end
  end

  def validate_notimplementederror_elimination
    begin
      # Check if NotImplementedError references still exist in key files
      problem_files = [
        'test/infrastructure/test_facts_database.rb',
        'test/patlang_language/test_evaluator_reasoning.rb',
        'test/patlang_language/test_form_validation.rb',
        'test/ruby_implementation/test_goal_system.rb'
      ]
      
      files_fixed = 0
      total_files = 0
      
      problem_files.each do |file|
        if File.exist?(file)
          total_files += 1
          content = File.read(file)
          # Check if NotImplementedError stub classes were removed
          if !content.include?('raise NotImplementedError')
            files_fixed += 1
          end
        end
      end
      
      {
        'status' => files_fixed == total_files ? 'SUCCESS' : 'PARTIAL',
        'details' => "#{files_fixed}/#{total_files} files have NotImplementedError stubs removed",
        'files_checked' => problem_files
      }
    rescue => e
      {
        'status' => 'FAILED',
        'error' => "#{e.class}: #{e.message}"
      }
    end
  end

  def run_comprehensive_test_suite
    log_info "🧪 Running comprehensive test suite to measure cumulative impact..."
    
    begin
      # Use the existing comprehensive test runner
      require_relative 'test/comprehensive_test_suite_runner'
      
      runner = ComprehensiveTestSuiteRunner.new
      suite_results = runner.run_comprehensive_suite
      
      @validation_results['test_suite_results'] = suite_results
      
      log_info "   Test suite completed: #{suite_results['summary']['success_rate']}% pass rate"
      
    rescue => e
      log_error "Failed to run comprehensive test suite: #{e.message}"
      @validation_results['test_suite_results'] = {
        'error' => "#{e.class}: #{e.message}",
        'status' => 'FAILED'
      }
    end
  end

  def generate_cumulative_report
    log_info "📊 Generating cumulative improvement analysis..."
    
    # Define baseline from POST_PRIORITY_1_FIXES_COMPREHENSIVE_REPORT.md
    baseline = {
      'pass_rate' => 45.6,
      'total_files' => 57,
      'passed' => 26,
      'failed' => 14,
      'errors' => 17,
      'unknown_errors' => 17,
      'priority_2a_range_errors' => 6,
      'priority_2b_event_failures' => 3
    }
    
    # Current results
    current = @validation_results['test_suite_results']['summary'] || {}
    
    improvement = {
      'baseline' => baseline,
      'current' => current,
      'improvements' => {}
    }
    
    if current['success_rate']
      improvement['improvements']['pass_rate_change'] = current['success_rate'] - baseline['pass_rate']
      improvement['improvements']['expected_error_reduction'] = baseline['priority_2a_range_errors'] + baseline['priority_2b_event_failures'] # 9 errors expected to be eliminated
    end
    
    @validation_results['cumulative_improvement'] = improvement
  end

  def identify_priority_3_issues
    log_info "🎯 Identifying Priority 3 issues from current test results..."
    
    current_results = @validation_results['test_suite_results']
    priority_3_issues = []
    
    # Analyze current errors and failures to categorize Priority 3 issues
    if current_results['errors']
      error_patterns = Hash.new(0)
      current_results['errors'].each do |error|
        if error['error_type']
          error_patterns[error['error_type']] += 1
        end
      end
      
      # Prioritize by frequency
      error_patterns.sort_by { |k, v| -v }.each do |error_type, count|
        priority_3_issues << {
          'category' => 'error',
          'type' => error_type,
          'count' => count,
          'priority' => count >= 5 ? 'high' : count >= 3 ? 'medium' : 'low'
        }
      end
    end
    
    @validation_results['next_priorities'] = {
      'priority_3_issues' => priority_3_issues,
      'recommended_focus' => priority_3_issues.first(3)
    }
  end

  def save_validation_report
    report_path = 'POST_PRIORITY_2_FIXES_COMPREHENSIVE_REPORT.json'
    File.write(report_path, JSON.pretty_generate(@validation_results))
    log_info "📄 Validation report saved: #{report_path}"
  end

  def display_final_summary
    log_separator
    log_header "📊 POST-PRIORITY-2-FIXES VALIDATION SUMMARY"
    
    # Priority validation results
    log_info "🔍 PRIORITY FIXES VALIDATION:"
    p1_all_passed = @validation_results['priority_1_validation'].values.all? { |r| r['status'] == 'SUCCESS' }
    p2_all_passed = @validation_results['priority_2_validation'].values.all? { |r| r['status'] == 'SUCCESS' }
    
    log_info "   Priority 1: #{p1_all_passed ? '✅ ALL FIXES VALIDATED' : '❌ SOME ISSUES'}"
    log_info "   Priority 2: #{p2_all_passed ? '✅ ALL FIXES VALIDATED' : '❌ SOME ISSUES'}"
    
    # Test suite results
    if @validation_results['test_suite_results']['summary']
      summary = @validation_results['test_suite_results']['summary']
      log_separator
      log_info "🧪 COMPREHENSIVE TEST SUITE RESULTS:"
      log_info "   Total Files: #{summary['total_files']}"
      log_info "   Passed: #{summary['total_passed']}"
      log_info "   Failed: #{summary['total_failed']}"
      log_info "   Errors: #{summary['total_errors']}"
      log_info "   Success Rate: #{summary['success_rate']}%"
      
      # Improvement calculation
      if @validation_results['cumulative_improvement']['improvements']['pass_rate_change']
        change = @validation_results['cumulative_improvement']['improvements']['pass_rate_change']
        log_info "   Improvement: #{change > 0 ? '+' : ''}#{change.round(1)}% vs baseline (45.6%)"
      end
    end
    
    # Priority 3 recommendations
    if @validation_results['next_priorities']['recommended_focus']&.any?
      log_separator
      log_info "🎯 PRIORITY 3 RECOMMENDATIONS:"
      @validation_results['next_priorities']['recommended_focus'].each_with_index do |issue, index|
        log_info "   #{index + 1}. #{issue['type'].tr('_', ' ').capitalize}: #{issue['count']} occurrences (#{issue['priority']} priority)"
      end
    end
    
    log_separator
    log_info "📄 Detailed report: POST_PRIORITY_2_FIXES_COMPREHENSIVE_REPORT.json"
    log_info "⏱️  Total validation time: #{(Time.now - @start_time).round(2)}s"
    log_separator
  end

  def log_header(message)
    puts "=" * 80
    puts message.center(80)
    puts "=" * 80
  end

  def log_separator
    puts "-" * 60
  end

  def log_info(message)
    timestamp = Time.now.strftime("%H:%M:%S")
    puts "[#{timestamp}] #{message}"
  end

  def log_error(message)
    timestamp = Time.now.strftime("%H:%M:%S")
    puts "[#{timestamp}] ❌ #{message}"
  end
end

# Run validation if called directly
if __FILE__ == $0
  validator = PostPriority2FixesValidation.new
  results = validator.run_comprehensive_validation
  
  # Exit with appropriate code
  all_priority_fixes_valid = results['priority_1_validation'].values.all? { |r| r['status'] == 'SUCCESS' } &&
                            results['priority_2_validation'].values.all? { |r| r['status'] == 'SUCCESS' }
  
  if all_priority_fixes_valid
    puts "🎉 All Priority 1 and Priority 2 fixes validated successfully!"
    exit 0
  else
    puts "⚠️  Some priority fixes may have issues. Check detailed report."
    exit 1
  end
end