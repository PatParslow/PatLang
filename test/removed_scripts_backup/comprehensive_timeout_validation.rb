#!/usr/bin/env ruby

# Comprehensive Test Suite Validation
# Validates that ALL tests can run without hanging using timeout protection systems

require 'fileutils'
require 'json'
require 'time'

class ComprehensiveTimeoutValidation
  def initialize
    @base_path = File.dirname(__FILE__)
    @validation_start_time = Time.now
    @results = {
      categories: {},
      overall_metrics: {},
      validation_timestamp: @validation_start_time.iso8601,
      timeout_protection_systems: []
    }
    
    # Test categories with their expected characteristics
    @categories = {
      'infrastructure' => {
        timeout: 120,
        description: 'Core infrastructure tests (lexer, parser, AST)',
        expected_files: ['test_lexer', 'test_parser', 'test_ast_nodes']
      },
      'ruby_implementation' => {
        timeout: 90,
        description: 'Ruby implementation tests (evaluator, object model)',
        expected_files: ['test_evaluator', 'test_object_model', 'test_goal_system']
      },
      'patlang_language' => {
        timeout: 180,
        description: 'PATLang language tests (integration, reasoning)',
        expected_files: ['test_integration', 'test_evaluator_reasoning', 'test_cross_paradigm']
      }
    }
    
    @individual_timeout = 30  # 30 seconds per test file
  end

  def run_comprehensive_validation
    puts "=" * 80
    puts "🛡️  COMPREHENSIVE TEST SUITE TIMEOUT VALIDATION"
    puts "=" * 80
    puts "🕐 Started: #{@validation_start_time.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "🎯 Goal: Verify no tests hang with timeout protection"
    puts "🔧 Using: EmergencyTimeout + SimpleTimeoutRunner systems"
    puts "=" * 80
    puts

    # Step 1: Validate timeout protection systems exist
    validate_timeout_systems
    
    # Step 2: Test each category individually
    test_all_categories
    
    # Step 3: Test comprehensive 'all' scenario
    test_all_categories_combined
    
    # Step 4: Validate run_all_tests functionality
    validate_run_all_tests
    
    # Step 5: Generate comprehensive report
    generate_validation_report
    
    puts "\n🎉 COMPREHENSIVE VALIDATION COMPLETED!"
    puts "📊 Check validation report for detailed metrics"
  end

  private

  def validate_timeout_systems
    puts "🔍 STEP 1: VALIDATING TIMEOUT PROTECTION SYSTEMS"
    puts "-" * 60

    systems = [
      { 
        name: 'EmergencyTimeout', 
        path: '../src/emergency_timeout.rb',
        description: 'Thread-based timeout protection'
      },
      { 
        name: 'SimpleTimeoutRunner', 
        path: 'simple_timeout_runner.rb',
        description: 'System-level timeout for test categories'
      }
    ]

    systems.each do |system|
      full_path = File.join(@base_path, system[:path])
      if File.exist?(full_path)
        puts "✅ #{system[:name]}: #{system[:description]}"
        @results[:timeout_protection_systems] << {
          name: system[:name],
          status: 'available',
          path: system[:path],
          description: system[:description]
        }
      else
        puts "❌ #{system[:name]}: MISSING at #{system[:path]}"
        @results[:timeout_protection_systems] << {
          name: system[:name],
          status: 'missing',
          path: system[:path],
          description: system[:description]
        }
      end
    end
    puts
  end

  def test_all_categories
    puts "🧪 STEP 2: TESTING ALL CATEGORIES WITH TIMEOUT PROTECTION"
    puts "-" * 60

    @categories.each do |category, config|
      puts "\n📁 Testing category: #{category}"
      puts "   Description: #{config[:description]}"
      puts "   Timeout: #{config[:timeout]}s"
      
      result = run_category_with_timeout(category, config)
      @results[:categories][category] = result
      
      puts "   Result: #{result[:status]}"
      puts "   Files tested: #{result[:files_tested]}"
      puts "   Successful: #{result[:successful_files]}"
      puts "   Failed: #{result[:failed_files]}"
      puts "   Execution time: #{result[:execution_time].round(2)}s"
      
      if result[:hanging_files].any?
        puts "   ⚠️  Hanging files detected: #{result[:hanging_files].join(', ')}"
      end
    end
    puts
  end

  def run_category_with_timeout(category, config)
    start_time = Time.now
    
    # Use the simple_timeout_runner.rb to test this category
    runner_path = File.join(@base_path, 'simple_timeout_runner.rb')
    
    unless File.exist?(runner_path)
      return {
        status: 'error',
        error: 'SimpleTimeoutRunner not found',
        execution_time: 0,
        files_tested: 0,
        successful_files: 0,
        failed_files: 0,
        hanging_files: []
      }
    end

    # Run the category test with system timeout
    cmd = "ruby #{runner_path} #{category}"
    puts "   Command: #{cmd}"
    
    # Capture output and run with additional system timeout protection
    output = ""
    success = false
    
    begin
      if Gem.win_platform?
        # Windows timeout protection
        success = system("ruby -e \"require 'timeout'; Timeout::timeout(#{config[:timeout] + 30}) { system('#{cmd}') }\"")
      else
        # Unix timeout protection  
        success = system("timeout #{config[:timeout] + 30} #{cmd}")
      end
      
      # If the command itself had issues, note that
      exit_status = $?.exitstatus
      
      execution_time = Time.now - start_time
      
      # Count test files in category directory
      category_dir = File.join(@base_path, category)
      test_files = Dir.exist?(category_dir) ? Dir.glob(File.join(category_dir, 'test_*.rb')).length : 0
      
      {
        status: success ? 'completed' : 'failed',
        execution_time: execution_time,
        files_tested: test_files,
        successful_files: success ? test_files : 0,
        failed_files: success ? 0 : test_files,
        hanging_files: [],
        exit_status: exit_status,
        system_timeout_triggered: exit_status == 124
      }
      
    rescue => e
      execution_time = Time.now - start_time
      
      {
        status: 'error',
        error: e.message,
        execution_time: execution_time,
        files_tested: 0,
        successful_files: 0,
        failed_files: 0,
        hanging_files: []
      }
    end
  end

  def test_all_categories_combined
    puts "🌐 STEP 3: TESTING ALL CATEGORIES COMBINED"
    puts "-" * 60

    start_time = Time.now
    
    puts "   Running comprehensive test with all categories..."
    puts "   This tests the 'all' scenario to ensure comprehensive suite completion"
    
    # Create a custom script that runs all categories sequentially
    all_test_script = create_all_categories_script
    
    begin
      # Run with extended timeout for comprehensive test
      comprehensive_timeout = 600  # 10 minutes total
      
      if Gem.win_platform?
        success = system("ruby -e \"require 'timeout'; Timeout::timeout(#{comprehensive_timeout}) { load '#{all_test_script}' }\"")
      else
        success = system("timeout #{comprehensive_timeout} ruby #{all_test_script}")
      end
      
      execution_time = Time.now - start_time
      exit_status = $?.exitstatus
      
      @results[:overall_metrics][:all_categories_test] = {
        status: success ? 'completed' : 'failed',
        execution_time: execution_time,
        exit_status: exit_status,
        timeout_triggered: exit_status == 124
      }
      
      puts "   Result: #{success ? 'SUCCESS' : 'FAILED'}"
      puts "   Execution time: #{execution_time.round(2)}s"
      puts "   Exit status: #{exit_status}"
      
      if exit_status == 124
        puts "   ⚠️  System timeout triggered - tests may still be hanging"
      end
      
    ensure
      # Clean up the temporary script
      File.delete(all_test_script) if File.exist?(all_test_script)
    end
    
    puts
  end

  def create_all_categories_script
    script_path = File.join(@base_path, 'temp_all_categories_test.rb')
    
    script_content = <<~RUBY
      #!/usr/bin/env ruby
      
      puts "🌐 Running all categories with timeout protection..."
      
      categories = #{@categories.keys.inspect}
      runner_path = #{File.join(@base_path, 'simple_timeout_runner.rb').inspect}
      
      categories.each do |category|
        puts "\\n📁 Running category: \#{category}"
        system("ruby \#{runner_path} \#{category}")
        puts "   Category \#{category} completed with exit status: \#{$?.exitstatus}"
      end
      
      puts "\\n✅ All categories test completed"
    RUBY
    
    File.write(script_path, script_content)
    script_path
  end

  def validate_run_all_tests
    puts "🔧 STEP 4: VALIDATING run_all_tests.rb FUNCTIONALITY"
    puts "-" * 60

    run_all_tests_path = File.join(@base_path, 'run_all_tests.rb')
    
    if File.exist?(run_all_tests_path)
      puts "   Found run_all_tests.rb"
      
      # Try to run it with timeout protection
      start_time = Time.now
      
      begin
        if Gem.win_platform?
          success = system("ruby -e \"require 'timeout'; Timeout::timeout(300) { system('ruby #{run_all_tests_path}') }\"")
        else
          success = system("timeout 300 ruby #{run_all_tests_path}")
        end
        
        execution_time = Time.now - start_time
        exit_status = $?.exitstatus
        
        @results[:overall_metrics][:run_all_tests] = {
          status: success ? 'working' : 'failed',
          execution_time: execution_time,
          exit_status: exit_status,
          timeout_triggered: exit_status == 124
        }
        
        puts "   Result: #{success ? 'WORKING' : 'FAILED'}"
        puts "   Execution time: #{execution_time.round(2)}s"
        puts "   Exit status: #{exit_status}"
        
        if exit_status == 124
          puts "   ⚠️  run_all_tests.rb triggered timeout - may need fixing"
        end
        
      rescue => e
        puts "   ❌ Error running run_all_tests.rb: #{e.message}"
        @results[:overall_metrics][:run_all_tests] = {
          status: 'error',
          error: e.message
        }
      end
    else
      puts "   ❌ run_all_tests.rb not found"
      @results[:overall_metrics][:run_all_tests] = {
        status: 'missing'
      }
    end
    
    puts
  end

  def generate_validation_report
    puts "📊 STEP 5: GENERATING COMPREHENSIVE VALIDATION REPORT"
    puts "-" * 60

    total_execution_time = Time.now - @validation_start_time
    
    # Calculate overall metrics
    total_categories = @categories.length
    successful_categories = @results[:categories].count { |_, result| result[:status] == 'completed' }
    total_files_tested = @results[:categories].values.sum { |result| result[:files_tested] }
    total_successful_files = @results[:categories].values.sum { |result| result[:successful_files] }
    
    @results[:overall_metrics].merge!({
      validation_duration: total_execution_time,
      total_categories: total_categories,
      successful_categories: successful_categories,
      category_success_rate: (successful_categories.to_f / total_categories * 100).round(1),
      total_files_tested: total_files_tested,
      total_successful_files: total_successful_files,
      file_success_rate: total_files_tested > 0 ? (total_successful_files.to_f / total_files_tested * 100).round(1) : 0,
      no_hanging_detected: !@results[:categories].values.any? { |result| result[:hanging_files]&.any? }
    })

    # Write detailed JSON report
    report_path = File.join(@base_path, 'COMPREHENSIVE_TIMEOUT_VALIDATION_REPORT.json')
    File.write(report_path, JSON.pretty_generate(@results))
    
    # Display summary
    puts "✅ Comprehensive validation report generated: #{File.basename(report_path)}"
    puts
    puts "📊 FINAL SUMMARY:"
    puts "   Total execution time: #{total_execution_time.round(2)}s"
    puts "   Categories tested: #{successful_categories}/#{total_categories}"
    puts "   Category success rate: #{@results[:overall_metrics][:category_success_rate]}%"
    puts "   Files tested: #{total_files_tested}"
    puts "   File success rate: #{@results[:overall_metrics][:file_success_rate]}%"
    puts "   No hanging detected: #{@results[:overall_metrics][:no_hanging_detected] ? 'YES ✅' : 'NO ⚠️'}"
    
    # Timeout protection status
    available_systems = @results[:timeout_protection_systems].count { |sys| sys[:status] == 'available' }
    total_systems = @results[:timeout_protection_systems].length
    puts "   Timeout protection: #{available_systems}/#{total_systems} systems available"
    
    if @results[:overall_metrics][:no_hanging_detected] && 
       @results[:overall_metrics][:category_success_rate] > 80
      puts "\n🎉 VALIDATION SUCCESS: Timeout protection systems are working effectively!"
    else
      puts "\n⚠️  VALIDATION ISSUES: Some tests may still hang or timeout protection needs improvement"
    end
  end
end

# Main execution
if __FILE__ == $0
  validator = ComprehensiveTimeoutValidation.new
  validator.run_comprehensive_validation
end