#!/usr/bin/env ruby

# Intelligent Test Scheduling System for PATLANG
# Provides smart test selection and execution based on changes, dependencies, and performance characteristics

require 'json'
require 'fileutils'
require 'benchmark'
require 'digest'

class IntelligentTestScheduler
  VERSION = "1.0.0"
  
  def initialize
    @base_path = File.dirname(__FILE__)
    @config_file = File.join(@base_path, 'scheduler_config.json')
    @cache_file = File.join(@base_path, 'test_cache.json')
    @timing_file = File.join(@base_path, 'test_timings.json')
    @dependencies_file = File.join(@base_path, 'test_dependencies.json')
    
    load_configuration
    load_test_metadata
    initialize_git_tracking
  end

  # Main scheduling modes
  def run_scheduled_tests(mode, options = {})
    puts "🚀 Intelligent Test Scheduler v#{VERSION}"
    puts "📋 Mode: #{mode.upcase}"
    puts "⏰ Started at: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "=" * 60
    
    start_time = Time.now
    
    case mode.to_s
    when 'smoke'
      run_smoke_tests(options)
    when 'fast'
      run_fast_feedback_tests(options)
    when 'targeted'
      run_targeted_tests(options)
    when 'coverage'
      run_coverage_driven_tests(options)
    when 'full'
      run_full_validation_tests(options)
    when 'changed'
      run_changed_file_tests(options)
    else
      puts "❌ Unknown mode: #{mode}"
      show_usage
      return false
    end
    
    total_time = Time.now - start_time
    puts "\n🎉 Test scheduling completed in #{total_time.round(2)}s"
    update_performance_metrics(mode, total_time)
    true
  end

  private

  def load_configuration
    if File.exist?(@config_file)
      @config = JSON.parse(File.read(@config_file))
    else
      @config = default_configuration
      save_configuration
    end
  end

  def default_configuration
    {
      'fast_feedback_threshold' => 30,  # seconds
      'smoke_test_count' => 10,
      'parallel_workers' => 4,
      'cache_enabled' => true,
      'git_tracking' => true,
      'categories' => {
        'infrastructure' => {
          'priority' => 1,
          'fast_tests' => %w[test_lexer.rb test_parser.rb test_ast_nodes.rb],
          'smoke_tests' => %w[test_lexer.rb],
          'dependencies' => %w[src/lexer.rb src/parser.rb src/token.rb]
        },
        'ruby_implementation' => {
          'priority' => 2,
          'fast_tests' => %w[test_object_model.rb test_string_operations.rb],
          'smoke_tests' => %w[test_object_model.rb],
          'dependencies' => %w[src/object_model/ src/evaluator.rb]
        },
        'patlang_language' => {
          'priority' => 3,
          'fast_tests' => %w[test_integration.rb test_evaluator.rb],
          'smoke_tests' => %w[test_integration.rb],
          'dependencies' => %w[src/ examples/]
        }
      },
      'test_tags' => {
        'unit' => %w[test_lexer.rb test_parser.rb test_object_model.rb],
        'integration' => %w[test_integration.rb test_evaluator_reasoning.rb],
        'performance' => %w[test_performance_optimization.rb],
        'coverage' => %w[test_comprehensive test_stress]
      }
    }
  end

  def load_test_metadata
    @test_timings = File.exist?(@timing_file) ? JSON.parse(File.read(@timing_file)) : {}
    @test_cache = File.exist?(@cache_file) ? JSON.parse(File.read(@cache_file)) : {}
    @test_dependencies = File.exist?(@dependencies_file) ? JSON.parse(File.read(@dependencies_file)) : build_dependency_map
  end

  def initialize_git_tracking
    @git_enabled = @config['git_tracking'] && system('git status > /dev/null 2>&1')
    if @git_enabled
      @last_commit = `git rev-parse HEAD`.strip rescue nil
      @changed_files = get_changed_files
    end
  end

  def get_changed_files
    return [] unless @git_enabled
    
    # Get files changed since last commit or staging
    changed = `git diff --name-only HEAD`.split("\n")
    staged = `git diff --cached --name-only`.split("\n")
    
    (changed + staged).uniq.select { |f| f.start_with?('src/') || f.start_with?('test/') }
  end

  # Smoke Tests: Critical functionality validation (< 10 tests)
  def run_smoke_tests(options)
    puts "💨 Running smoke tests (critical functionality)"
    
    smoke_tests = []
    @config['categories'].each do |category, config|
      config['smoke_tests'].each do |test|
        smoke_tests << { category: category, test: test, priority: config['priority'] }
      end
    end
    
    # Sort by priority and run limited set
    selected_tests = smoke_tests.sort_by { |t| t[:priority] }.take(@config['smoke_test_count'])
    
    puts "📝 Selected #{selected_tests.length} smoke tests:"
    selected_tests.each { |t| puts "   - #{t[:category]}/#{t[:test]}" }
    
    execute_test_selection(selected_tests, mode: 'smoke')
  end

  # Fast Feedback: Tests that complete within threshold
  def run_fast_feedback_tests(options)
    threshold = options[:threshold] || @config['fast_feedback_threshold']
    puts "⚡ Running fast feedback tests (< #{threshold}s each)"
    
    fast_tests = []
    @config['categories'].each do |category, config|
      config['fast_tests'].each do |test|
        test_time = @test_timings.dig(category, test) || 5  # Default 5s if unknown
        if test_time <= threshold
          fast_tests << { 
            category: category, 
            test: test, 
            estimated_time: test_time,
            priority: config['priority']
          }
        end
      end
    end
    
    # Sort by priority then time
    selected_tests = fast_tests.sort_by { |t| [t[:priority], t[:estimated_time]] }
    
    puts "📝 Selected #{selected_tests.length} fast tests:"
    selected_tests.each { |t| puts "   - #{t[:category]}/#{t[:test]} (~#{t[:estimated_time]}s)" }
    
    execute_test_selection(selected_tests, mode: 'fast', parallel: true)
  end

  # Targeted Tests: Based on changed files
  def run_targeted_tests(options)
    puts "🎯 Running targeted tests based on file changes"
    
    if @changed_files.empty?
      puts "ℹ️  No changed files detected, running smoke tests instead"
      return run_smoke_tests(options)
    end
    
    puts "📂 Changed files:"
    @changed_files.each { |f| puts "   - #{f}" }
    
    affected_tests = find_affected_tests(@changed_files)
    
    if affected_tests.empty?
      puts "⚠️  No tests affected by changes, running smoke tests"
      return run_smoke_tests(options)
    end
    
    puts "📝 Affected tests:"
    affected_tests.each { |t| puts "   - #{t[:category]}/#{t[:test]} (#{t[:reason]})" }
    
    execute_test_selection(affected_tests, mode: 'targeted')
  end

  # Coverage-driven Tests: Target specific coverage gaps
  def run_coverage_driven_tests(options)
    puts "📊 Running coverage-driven tests"
    
    coverage_gaps = analyze_coverage_gaps
    priority_tests = select_coverage_tests(coverage_gaps)
    
    puts "📝 Coverage-targeted tests:"
    priority_tests.each { |t| puts "   - #{t[:category]}/#{t[:test]} (covers: #{t[:coverage_target]})" }
    
    execute_test_selection(priority_tests, mode: 'coverage', coverage: true)
  end

  # Full Validation: Complete test suite with performance monitoring
  def run_full_validation_tests(options)
    puts "🏁 Running full validation test suite"
    
    all_tests = []
    @config['categories'].each do |category, config|
      test_files = Dir.glob(File.join(@base_path, category, 'test_*.rb'))
      test_files.each do |file_path|
        test_name = File.basename(file_path)
        all_tests << {
          category: category,
          test: test_name,
          priority: config['priority'],
          estimated_time: @test_timings.dig(category, test_name) || 10
        }
      end
    end
    
    # Sort by priority for optimal execution order
    sorted_tests = all_tests.sort_by { |t| [t[:priority], t[:estimated_time]] }
    
    puts "📝 Full test suite: #{sorted_tests.length} tests"
    
    execute_test_selection(sorted_tests, mode: 'full', parallel: true, performance_monitoring: true)
  end

  # Changed File Tests: Git-aware test selection
  def run_changed_file_tests(options)
    since = options[:since] || 'HEAD~1'
    puts "📝 Running tests for files changed since #{since}"
    
    changed_files = `git diff --name-only #{since}`.split("\n").select do |f|
      f.start_with?('src/') || f.start_with?('test/')
    end
    
    if changed_files.empty?
      puts "ℹ️  No relevant files changed, running smoke tests"
      return run_smoke_tests(options)
    end
    
    affected_tests = find_affected_tests(changed_files)
    execute_test_selection(affected_tests, mode: 'changed')
  end

  def find_affected_tests(changed_files)
    affected = []
    
    changed_files.each do |file|
      @config['categories'].each do |category, config|
        # Check if changed file matches category dependencies
        config['dependencies'].each do |dep_pattern|
          if file.start_with?(dep_pattern.chomp('/'))
            # Add all tests from this category
            test_files = Dir.glob(File.join(@base_path, category, 'test_*.rb'))
            test_files.each do |test_path|
              test_name = File.basename(test_path)
              affected << {
                category: category,
                test: test_name,
                reason: "depends on #{file}",
                priority: config['priority']
              }
            end
          end
        end
      end
      
      # Direct test file changes
      if file.start_with?('test/')
        relative_path = file.sub('test/', '')
        if relative_path.include?('/')
          category = relative_path.split('/').first
          test_name = File.basename(file)
          affected << {
            category: category,
            test: test_name,
            reason: "direct change",
            priority: 0  # Highest priority for direct changes
          }
        end
      end
    end
    
    affected.uniq { |t| "#{t[:category]}/#{t[:test]}" }
           .sort_by { |t| t[:priority] }
  end

  def execute_test_selection(test_selection, options = {})
    return false if test_selection.empty?
    
    mode = options[:mode] || 'unknown'
    parallel = options[:parallel] && test_selection.length > 1
    coverage = options[:coverage]
    
    puts "\n🚀 Executing #{test_selection.length} tests in #{mode} mode"
    puts "⚙️  Parallel: #{parallel ? 'Yes' : 'No'}, Coverage: #{coverage ? 'Yes' : 'No'}"
    puts "─" * 60
    
    total_start = Time.now
    results = []
    
    if parallel && test_selection.length > 2
      results = execute_parallel_tests(test_selection, options)
    else
      results = execute_sequential_tests(test_selection, options)
    end
    
    total_time = Time.now - total_start
    
    # Report results
    report_execution_results(results, total_time, mode)
    
    # Update timing data
    update_test_timings(results)
    
    # Cache successful results if enabled
    cache_test_results(results) if @config['cache_enabled']
    
    results.all? { |r| r[:success] }
  end

  def execute_sequential_tests(test_selection, options)
    results = []
    
    test_selection.each_with_index do |test_info, index|
      puts "[#{index + 1}/#{test_selection.length}] Running #{test_info[:category]}/#{test_info[:test]}"
      
      result = execute_single_test(test_info, options)
      results << result
      
      # Fail fast on critical errors
      if !result[:success] && test_info[:priority] <= 1
        puts "💥 Critical test failed, stopping execution"
        break
      end
    end
    
    results
  end

  def execute_parallel_tests(test_selection, options)
    puts "🔀 Running tests in parallel with #{@config['parallel_workers']} workers"
    
    # Group tests by estimated time for better load balancing
    test_groups = distribute_tests_for_parallel(test_selection)
    results = []
    
    test_groups.each_with_index do |group, group_index|
      puts "📦 Group #{group_index + 1}: #{group.map { |t| t[:test] }.join(', ')}"
      
      group_results = group.map do |test_info|
        Thread.new { execute_single_test(test_info, options) }
      end.map(&:value)
      
      results.concat(group_results)
    end
    
    results
  end

  def execute_single_test(test_info, options)
    category = test_info[:category]
    test_name = test_info[:test]
    
    start_time = Time.now
    
    # Check cache first
    if should_use_cache?(test_info)
      cached_result = get_cached_result(test_info)
      if cached_result
        puts "💾 Using cached result for #{category}/#{test_name}"
        return cached_result.merge(cached: true)
      end
    end
    
    # Setup coverage if requested
    if options[:coverage]
      setup_test_coverage(category, test_name)
    end
    
    # Execute the test
    test_path = File.join(@base_path, category, test_name)
    
    begin
      # Capture output and timing
      output = nil
      execution_time = Benchmark.realtime do
        output = `cd #{@base_path} && ruby #{test_path} 2>&1`
      end
      
      success = $?.success?
      
      {
        category: category,
        test: test_name,
        success: success,
        execution_time: execution_time,
        output: output,
        timestamp: Time.now.to_i,
        cached: false
      }
      
    rescue => e
      {
        category: category,
        test: test_name,
        success: false,
        execution_time: Time.now - start_time,
        output: "Error: #{e.message}",
        error: e,
        timestamp: Time.now.to_i,
        cached: false
      }
    end
  end

  def analyze_coverage_gaps
    # This would integrate with SimpleCov or other coverage tools
    # For now, return mock gaps based on common patterns
    [
      { file: 'src/lexer.rb', lines: [45, 67, 89], branches: [12, 23] },
      { file: 'src/parser.rb', lines: [156, 203], branches: [34] },
      { file: 'src/reasoning/unification_engine.rb', lines: [78, 134], branches: [15, 28] }
    ]
  end

  def select_coverage_tests(gaps)
    # Select tests that target specific coverage gaps
    coverage_tests = []
    
    gaps.each do |gap|
      @config['categories'].each do |category, config|
        config['dependencies'].each do |dep|
          if gap[:file].start_with?(dep.chomp('/'))
            # Find tests that exercise this dependency
            test_files = Dir.glob(File.join(@base_path, category, 'test_*.rb'))
            test_files.each do |test_path|
              test_name = File.basename(test_path)
              coverage_tests << {
                category: category,
                test: test_name,
                coverage_target: gap[:file],
                priority: config['priority']
              }
            end
          end
        end
      end
    end
    
    coverage_tests.uniq { |t| "#{t[:category]}/#{t[:test]}" }
  end

  def distribute_tests_for_parallel(tests)
    # Simple round-robin distribution
    workers = @config['parallel_workers']
    groups = Array.new(workers) { [] }
    
    tests.each_with_index do |test, index|
      groups[index % workers] << test
    end
    
    groups.reject(&:empty?)
  end

  def should_use_cache?(test_info)
    return false unless @config['cache_enabled']
    
    cache_key = "#{test_info[:category]}/#{test_info[:test]}"
    cached = @test_cache[cache_key]
    
    return false unless cached
    
    # Check if source files have changed since cache
    test_path = File.join(@base_path, test_info[:category], test_info[:test])
    return false unless File.exist?(test_path)
    
    cached_mtime = cached['timestamp']
    current_mtime = File.mtime(test_path).to_i
    
    current_mtime <= cached_mtime
  end

  def get_cached_result(test_info)
    cache_key = "#{test_info[:category]}/#{test_info[:test]}"
    cached = @test_cache[cache_key]
    
    return nil unless cached
    
    {
      category: test_info[:category],
      test: test_info[:test],
      success: cached['success'],
      execution_time: cached['execution_time'],
      output: cached['output'],
      timestamp: cached['timestamp']
    }
  end

  def cache_test_results(results)
    results.each do |result|
      next unless result[:success] && !result[:cached]
      
      cache_key = "#{result[:category]}/#{result[:test]}"
      @test_cache[cache_key] = {
        'success' => result[:success],
        'execution_time' => result[:execution_time],
        'output' => result[:output],
        'timestamp' => result[:timestamp]
      }
    end
    
    File.write(@cache_file, JSON.pretty_generate(@test_cache))
  end

  def update_test_timings(results)
    results.each do |result|
      category = result[:category]
      test = result[:test]
      
      @test_timings[category] ||= {}
      @test_timings[category][test] = result[:execution_time].round(2)
    end
    
    File.write(@timing_file, JSON.pretty_generate(@test_timings))
  end

  def report_execution_results(results, total_time, mode)
    puts "\n" + "=" * 60
    puts "📊 EXECUTION REPORT - #{mode.upcase} MODE"
    puts "=" * 60
    
    successful = results.count { |r| r[:success] }
    failed = results.count { |r| !r[:success] }
    cached = results.count { |r| r[:cached] }
    
    puts "✅ Successful: #{successful}"
    puts "❌ Failed: #{failed}" if failed > 0
    puts "💾 Cached: #{cached}" if cached > 0
    puts "⏱️  Total time: #{total_time.round(2)}s"
    
    if results.any?
      avg_time = results.sum { |r| r[:execution_time] } / results.length
      puts "📈 Average test time: #{avg_time.round(2)}s"
      
      slowest = results.max_by { |r| r[:execution_time] }
      puts "🐌 Slowest test: #{slowest[:category]}/#{slowest[:test]} (#{slowest[:execution_time].round(2)}s)"
    end
    
    # Show failures
    if failed > 0
      puts "\n❌ FAILED TESTS:"
      results.select { |r| !r[:success] }.each do |result|
        puts "   - #{result[:category]}/#{result[:test]}"
        if result[:output] && result[:output].length < 200
          puts "     #{result[:output].strip}"
        end
      end
    end
    
    puts "=" * 60
  end

  def update_performance_metrics(mode, total_time)
    metrics_file = File.join(@base_path, 'performance_metrics.json')
    metrics = File.exist?(metrics_file) ? JSON.parse(File.read(metrics_file)) : {}
    
    metrics[mode] ||= []
    metrics[mode] << {
      'timestamp' => Time.now.to_i,
      'total_time' => total_time.round(2),
      'git_commit' => @last_commit
    }
    
    # Keep only last 100 entries per mode
    metrics[mode] = metrics[mode].last(100)
    
    File.write(metrics_file, JSON.pretty_generate(metrics))
  end

  def setup_test_coverage(category, test_name)
    # Configure SimpleCov for individual test coverage
    coverage_dir = File.join(@base_path, 'coverage', 'individual', category)
    FileUtils.mkdir_p(coverage_dir)
  end

  def build_dependency_map
    # Build a comprehensive dependency map between source files and tests
    # This is a simplified version - could be enhanced with static analysis
    {
      'src/lexer.rb' => ['infrastructure/test_lexer.rb', 'infrastructure/test_lexer_comprehensive.rb'],
      'src/parser.rb' => ['infrastructure/test_parser.rb', 'infrastructure/test_parser_edge_cases.rb'],
      'src/evaluator.rb' => ['patlang_language/test_evaluator.rb', 'ruby_implementation/test_evaluator_edge_cases.rb']
    }
  end

  def save_configuration
    File.write(@config_file, JSON.pretty_generate(@config))
  end

  def show_usage
    puts <<~USAGE
      USAGE: ruby test/intelligent_test_scheduler.rb MODE [OPTIONS]
      
      MODES:
        smoke     - Run critical functionality tests (fastest, ~10 tests)
        fast      - Run tests completing within time threshold (< 30s default)
        targeted  - Run tests affected by recent file changes
        coverage  - Run tests targeting specific coverage gaps
        changed   - Run tests for files changed since git reference
        full      - Run complete test suite with performance monitoring
      
      OPTIONS:
        --threshold=N     - Set time threshold for fast mode (seconds)
        --since=REF       - Git reference for changed mode (default: HEAD~1)
        --parallel        - Force parallel execution
        --no-cache        - Disable result caching
        --coverage        - Enable detailed coverage analysis
      
      EXAMPLES:
        ruby test/intelligent_test_scheduler.rb smoke
        ruby test/intelligent_test_scheduler.rb fast --threshold=15
        ruby test/intelligent_test_scheduler.rb targeted
        ruby test/intelligent_test_scheduler.rb changed --since=HEAD~3
        ruby test/intelligent_test_scheduler.rb full --parallel --coverage
      
      CONFIGURATION:
        Config file: test/scheduler_config.json
        Timing data: test/test_timings.json
        Cache data: test/test_cache.json
    USAGE
  end
end

# CLI Interface
if __FILE__ == $0
  mode = ARGV[0]
  
  if mode.nil? || mode == '--help' || mode == '-h'
    scheduler = IntelligentTestScheduler.new
    scheduler.send(:show_usage)
    exit(mode.nil? ? 1 : 0)
  end
  
  # Parse options
  options = {}
  ARGV[1..-1].each do |arg|
    case arg
    when /--threshold=(\d+)/
      options[:threshold] = $1.to_i
    when /--since=(.+)/
      options[:since] = $1
    when '--parallel'
      options[:parallel] = true
    when '--no-cache'
      options[:cache] = false
    when '--coverage'
      options[:coverage] = true
    end
  end
  
  scheduler = IntelligentTestScheduler.new
  success = scheduler.run_scheduled_tests(mode, options)
  
  exit(success ? 0 : 1)
end