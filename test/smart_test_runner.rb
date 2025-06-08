#!/usr/bin/env ruby

# Smart Test Runner for PATLANG
# Unified CLI interface for intelligent test scheduling and execution

require_relative 'intelligent_test_scheduler'
require_relative 'test_performance_analyzer'
require_relative 'test_dependency_mapper'
require 'optparse'
require 'json'

class SmartTestRunner
  VERSION = "1.0.0"
  
  def initialize
    @options = {
      mode: 'fast',
      threshold: 30,
      parallel: false,
      coverage: false,
      cache: true,
      verbose: false,
      dry_run: false,
      since: 'HEAD~1'
    }
    
    @scheduler = IntelligentTestScheduler.new
    @analyzer = TestPerformanceAnalyzer.new
    @mapper = TestDependencyMapper.new
  end

  def run(args)
    parse_options(args)
    
    if @options[:help]
      show_help
      return true
    end
    
    if @options[:version]
      puts "Smart Test Runner v#{VERSION}"
      return true
    end
    
    setup_environment
    
    case @options[:command]
    when 'run'
      run_tests
    when 'analyze'
      analyze_performance
    when 'map'
      build_dependency_map
    when 'status'
      show_status
    when 'setup'
      setup_system
    else
      puts "❌ Unknown command: #{@options[:command]}"
      show_help
      false
    end
  end

  private

  def parse_options(args)
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} COMMAND [OPTIONS]"
      opts.separator ""
      opts.separator "COMMANDS:"
      opts.separator "  run MODE     Run tests in specified mode (smoke, fast, targeted, coverage, changed, full)"
      opts.separator "  analyze      Analyze test performance and generate optimization recommendations"
      opts.separator "  map          Build test dependency mapping"
      opts.separator "  status       Show current test system status"
      opts.separator "  setup        Setup the intelligent test system"
      opts.separator ""
      opts.separator "OPTIONS:"
      
      opts.on('-t', '--threshold=N', Integer, 'Time threshold for fast mode (seconds)') do |t|
        @options[:threshold] = t
      end
      
      opts.on('-s', '--since=REF', 'Git reference for changed mode') do |ref|
        @options[:since] = ref
      end
      
      opts.on('-p', '--parallel', 'Enable parallel execution') do
        @options[:parallel] = true
      end
      
      opts.on('-c', '--coverage', 'Enable detailed coverage analysis') do
        @options[:coverage] = true
      end
      
      opts.on('--no-cache', 'Disable result caching') do
        @options[:cache] = false
      end
      
      opts.on('-v', '--verbose', 'Verbose output') do
        @options[:verbose] = true
      end
      
      opts.on('-n', '--dry-run', 'Show what would be executed without running') do
        @options[:dry_run] = true
      end
      
      opts.on('-h', '--help', 'Show this help') do
        @options[:help] = true
      end
      
      opts.on('--version', 'Show version') do
        @options[:version] = true
      end
    end
    
    remaining_args = parser.parse!(args)
    
    if remaining_args.any?
      @options[:command] = remaining_args[0]
      @options[:mode] = remaining_args[1] if remaining_args.length > 1
    else
      @options[:command] = 'run'
      @options[:mode] = 'fast'
    end
  end

  def setup_environment
    puts "🚀 PATLANG Smart Test Runner v#{VERSION}" if @options[:verbose]
    puts "⏰ Started at: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}" if @options[:verbose]
    
    # Ensure required directories exist
    ensure_directory('test/coverage')
    ensure_directory('test/reports')
    ensure_directory('test/cache')
  end

  def ensure_directory(path)
    full_path = File.join(File.dirname(__FILE__), '..', path)
    FileUtils.mkdir_p(full_path) unless Dir.exist?(full_path)
  end

  def run_tests
    mode = @options[:mode] || 'fast'
    
    puts "🎯 Running tests in #{mode.upcase} mode"
    puts "⚙️  Configuration:"
    puts "   Parallel: #{@options[:parallel]}"
    puts "   Coverage: #{@options[:coverage]}"
    puts "   Cache: #{@options[:cache]}"
    puts "   Threshold: #{@options[:threshold]}s" if mode == 'fast'
    puts "   Since: #{@options[:since]}" if mode == 'changed'
    puts "   Dry run: #{@options[:dry_run]}"
    puts

    if @options[:dry_run]
      show_dry_run(mode)
      return true
    end

    # Pre-flight checks
    unless validate_system
      puts "❌ System validation failed"
      return false
    end

    # Run the tests using the scheduler
    scheduler_options = {
      threshold: @options[:threshold],
      since: @options[:since],
      parallel: @options[:parallel],
      coverage: @options[:coverage],
      cache: @options[:cache],
      verbose: @options[:verbose]
    }

    success = @scheduler.run_scheduled_tests(mode, scheduler_options)
    
    if success
      puts "✅ Test execution completed successfully"
      generate_execution_summary(mode)
    else
      puts "❌ Test execution failed"
    end

    success
  end

  def analyze_performance
    puts "📊 Analyzing test performance..."
    puts
    
    if @options[:dry_run]
      puts "🔍 Performance analysis would:"
      puts "   - Analyze all test files for execution time"
      puts "   - Generate performance classifications"
      puts "   - Identify bottlenecks and optimization opportunities"
      puts "   - Update timing data for scheduler"
      return true
    end

    @analyzer.analyze_all_tests
    puts "✅ Performance analysis complete"
    true
  end

  def build_dependency_map
    puts "🔗 Building test dependency map..."
    puts
    
    if @options[:dry_run]
      puts "🗺️  Dependency mapping would:"
      puts "   - Scan all source and test files"
      puts "   - Analyze static dependencies (require statements)"
      puts "   - Apply pattern-based dependency rules"
      puts "   - Generate dependency map for smart test selection"
      return true
    end

    @mapper.build_dependency_map
    puts "✅ Dependency mapping complete"
    true
  end

  def show_status
    puts "📋 PATLANG Test System Status"
    puts "=" * 50
    
    # Test organization status
    show_test_organization_status
    
    # Performance data status
    show_performance_status
    
    # Dependency mapping status
    show_dependency_status
    
    # Git integration status
    show_git_status
    
    # Recent execution history
    show_execution_history
    
    true
  end

  def setup_system
    puts "🔧 Setting up PATLANG Intelligent Test System"
    puts "=" * 50
    
    if @options[:dry_run]
      puts "Setup would perform:"
      puts "   1. Build initial dependency map"
      puts "   2. Analyze test performance baselines"
      puts "   3. Generate configuration files"
      puts "   4. Validate test organization"
      puts "   5. Setup Git hooks (if requested)"
      return true
    end

    success = true
    
    puts "1️⃣  Building dependency map..."
    success &= build_dependency_map
    
    puts "\n2️⃣  Analyzing performance baselines..."
    success &= analyze_performance
    
    puts "\n3️⃣  Generating configuration..."
    success &= generate_default_config
    
    puts "\n4️⃣  Validating test organization..."
    success &= validate_test_organization
    
    if success
      puts "\n✅ Setup completed successfully!"
      puts "🚀 You can now use smart test scheduling:"
      puts "   ruby test/smart_test_runner.rb run fast"
      puts "   ruby test/smart_test_runner.rb run targeted"
      puts "   ruby test/smart_test_runner.rb run smoke"
    else
      puts "\n❌ Setup encountered issues"
    end
    
    success
  end

  def show_dry_run(mode)
    puts "🔍 DRY RUN - Would execute in #{mode.upcase} mode:"
    puts
    
    case mode
    when 'smoke'
      puts "   📝 Would run ~10 critical tests"
      puts "   ⏱️  Estimated time: < 30 seconds"
      puts "   🎯 Focus: Core functionality validation"
      
    when 'fast'
      puts "   📝 Would run tests completing within #{@options[:threshold]}s"
      puts "   ⏱️  Estimated time: < #{@options[:threshold] * 3} seconds total"
      puts "   🎯 Focus: Rapid feedback for development"
      
    when 'targeted'
      changed_files = get_changed_files
      if changed_files.any?
        puts "   📂 Changed files detected: #{changed_files.length}"
        changed_files.first(5).each { |f| puts "      - #{f}" }
        puts "      ..." if changed_files.length > 5
        
        # Simulate finding affected tests
        puts "   📝 Would analyze dependencies and run affected tests"
        puts "   ⏱️  Estimated time: Variable based on changes"
      else
        puts "   📂 No changed files detected"
        puts "   📝 Would fall back to smoke tests"
      end
      puts "   🎯 Focus: Tests relevant to recent changes"
      
    when 'coverage'
      puts "   📊 Would analyze coverage gaps"
      puts "   📝 Would run tests targeting uncovered code"
      puts "   ⏱️  Estimated time: Medium (depends on gaps)"
      puts "   🎯 Focus: Improving test coverage"
      
    when 'changed'
      puts "   📂 Would analyze files changed since #{@options[:since]}"
      puts "   📝 Would run tests affected by Git changes"
      puts "   ⏱️  Estimated time: Variable based on change scope"
      puts "   🎯 Focus: Git-aware test selection"
      
    when 'full'
      puts "   📝 Would run complete test suite (~#{count_total_tests} tests)"
      puts "   ⏱️  Estimated time: #{estimate_full_suite_time} minutes"
      puts "   🎯 Focus: Comprehensive validation"
      puts "   🔧 Would include performance monitoring"
    end
    
    puts
    puts "Configuration that would be used:"
    puts "   Parallel: #{@options[:parallel]}"
    puts "   Coverage: #{@options[:coverage]}"
    puts "   Cache: #{@options[:cache]}"
  end

  def show_test_organization_status
    puts "📂 TEST ORGANIZATION:"
    
    categories = %w[infrastructure ruby_implementation patlang_language]
    total_tests = 0
    
    categories.each do |category|
      test_dir = File.join(File.dirname(__FILE__), category)
      if Dir.exist?(test_dir)
        test_files = Dir.glob(File.join(test_dir, 'test_*.rb'))
        total_tests += test_files.length
        puts "   ✅ #{category}: #{test_files.length} test files"
      else
        puts "   ❌ #{category}: Directory missing"
      end
    end
    
    puts "   📊 Total: #{total_tests} test files across #{categories.length} categories"
    puts
  end

  def show_performance_status
    puts "⚡ PERFORMANCE DATA:"
    
    timing_file = File.join(File.dirname(__FILE__), 'test_timings.json')
    if File.exist?(timing_file)
      timings = JSON.parse(File.read(timing_file))
      total_tracked = timings.values.sum { |category| category.keys.length }
      puts "   ✅ Timing data available for #{total_tracked} tests"
      
      # Show performance summary
      all_times = timings.values.flat_map(&:values)
      if all_times.any?
        avg_time = all_times.sum / all_times.length
        puts "   📈 Average test time: #{avg_time.round(2)}s"
        puts "   🚀 Fast tests (< 5s): #{all_times.count { |t| t < 5 }}"
        puts "   🐌 Slow tests (> 30s): #{all_times.count { |t| t > 30 }}"
      end
    else
      puts "   ⚠️  No timing data available - run analysis first"
    end
    puts
  end

  def show_dependency_status
    puts "🔗 DEPENDENCY MAPPING:"
    
    deps_file = File.join(File.dirname(__FILE__), 'test_dependencies.json')
    if File.exist?(deps_file)
      deps = JSON.parse(File.read(deps_file))
      puts "   ✅ Dependency map available"
      puts "   📊 Mapped dependencies: #{deps['dependencies']&.length || 0}"
      puts "   📈 Coverage: #{deps.dig('statistics', 'coverage_percentage') || 0}%"
    else
      puts "   ⚠️  No dependency map available - run mapping first"
    end
    puts
  end

  def show_git_status
    puts "🌿 GIT INTEGRATION:"
    
    if system('git status > /dev/null 2>&1')
      puts "   ✅ Git repository detected"
      
      changed_files = get_changed_files
      if changed_files.any?
        puts "   📝 Changed files: #{changed_files.length}"
      else
        puts "   📝 No changed files detected"
      end
      
      current_branch = `git branch --show-current`.strip rescue 'unknown'
      puts "   🌿 Current branch: #{current_branch}"
    else
      puts "   ❌ Not a Git repository"
    end
    puts
  end

  def show_execution_history
    puts "📊 RECENT EXECUTION HISTORY:"
    
    metrics_file = File.join(File.dirname(__FILE__), 'performance_metrics.json')
    if File.exist?(metrics_file)
      metrics = JSON.parse(File.read(metrics_file))
      
      recent_runs = []
      metrics.each do |mode, runs|
        runs.last(3).each do |run|
          recent_runs << {
            mode: mode,
            time: run['total_time'],
            timestamp: run['timestamp']
          }
        end
      end
      
      recent_runs.sort_by { |r| r[:timestamp] }.reverse.first(5).each do |run|
        time_ago = Time.now.to_i - run[:timestamp]
        puts "   #{run[:mode].ljust(10)} - #{run[:time]}s (#{format_time_ago(time_ago)} ago)"
      end
    else
      puts "   ⚠️  No execution history available"
    end
    puts
  end

  def validate_system
    puts "🔍 Validating system..." if @options[:verbose]
    
    # Check test directory structure
    required_dirs = %w[infrastructure ruby_implementation patlang_language helpers]
    required_dirs.each do |dir|
      test_dir = File.join(File.dirname(__FILE__), dir)
      unless Dir.exist?(test_dir)
        puts "❌ Missing required directory: test/#{dir}"
        return false
      end
    end
    
    # Check helper file
    helper_file = File.join(File.dirname(__FILE__), 'helpers', 'test_helper.rb')
    unless File.exist?(helper_file)
      puts "❌ Missing test helper: test/helpers/test_helper.rb"
      return false
    end
    
    puts "✅ System validation passed" if @options[:verbose]
    true
  end

  def generate_execution_summary(mode)
    puts "\n📋 EXECUTION SUMMARY:"
    puts "   Mode: #{mode.upcase}"
    puts "   Configuration: #{@options.reject { |k, _| k == :command }.to_json}"
    
    # Save execution record
    record = {
      timestamp: Time.now.to_i,
      mode: mode,
      options: @options,
      success: true
    }
    
    records_file = File.join(File.dirname(__FILE__), 'execution_records.json')
    records = File.exist?(records_file) ? JSON.parse(File.read(records_file)) : []
    records << record
    records = records.last(100)  # Keep last 100 records
    
    File.write(records_file, JSON.pretty_generate(records))
  end

  def generate_default_config
    config = {
      version: VERSION,
      default_mode: 'fast',
      fast_threshold: 30,
      parallel_workers: 4,
      cache_enabled: true,
      git_integration: true,
      coverage_enabled: false,
      notification_enabled: false
    }
    
    config_file = File.join(File.dirname(__FILE__), 'smart_runner_config.json')
    File.write(config_file, JSON.pretty_generate(config))
    
    puts "   📝 Configuration saved: #{config_file}"
    true
  end

  def validate_test_organization
    # Run the existing validation from Rakefile
    system('cd .. && rake test:validate > /dev/null 2>&1')
  end

  def get_changed_files
    return [] unless system('git status > /dev/null 2>&1')
    
    changed = `git diff --name-only HEAD`.split("\n")
    staged = `git diff --cached --name-only`.split("\n")
    
    (changed + staged).uniq.select { |f| f.start_with?('src/') || f.start_with?('test/') }
  end

  def count_total_tests
    categories = %w[infrastructure ruby_implementation patlang_language]
    total = 0
    
    categories.each do |category|
      test_dir = File.join(File.dirname(__FILE__), category)
      if Dir.exist?(test_dir)
        total += Dir.glob(File.join(test_dir, 'test_*.rb')).length
      end
    end
    
    total
  end

  def estimate_full_suite_time
    timing_file = File.join(File.dirname(__FILE__), 'test_timings.json')
    return 15 unless File.exist?(timing_file)  # Default estimate
    
    timings = JSON.parse(File.read(timing_file))
    total_time = timings.values.flat_map(&:values).sum
    
    (total_time / 60.0).round(1)
  end

  def format_time_ago(seconds)
    if seconds < 60
      "#{seconds}s"
    elsif seconds < 3600
      "#{(seconds / 60).round}m"
    else
      "#{(seconds / 3600).round}h"
    end
  end

  def show_help
    puts <<~HELP
      PATLANG Smart Test Runner v#{VERSION}
      
      Intelligent test scheduling system for efficient development workflows
      
      USAGE:
        #{$0} COMMAND [MODE] [OPTIONS]
      
      COMMANDS:
        run MODE     Run tests using intelligent scheduling
        analyze      Analyze test performance and generate recommendations
        map          Build test dependency mapping
        status       Show current test system status
        setup        Setup the intelligent test system
      
      TEST MODES:
        smoke        Run critical functionality tests (~10 tests, < 30s)
        fast         Run tests completing within time threshold (default: 30s)
        targeted     Run tests affected by recent file changes
        coverage     Run tests targeting specific coverage gaps
        changed      Run tests for files changed since Git reference
        full         Run complete test suite with performance monitoring
      
      OPTIONS:
        -t, --threshold=N     Time threshold for fast mode (seconds)
        -s, --since=REF       Git reference for changed mode (default: HEAD~1)
        -p, --parallel        Enable parallel execution
        -c, --coverage        Enable detailed coverage analysis
        --no-cache            Disable result caching
        -v, --verbose         Verbose output
        -n, --dry-run         Show what would be executed without running
        -h, --help            Show this help
        --version             Show version
      
      EXAMPLES:
        # Quick development feedback
        #{$0} run fast
        
        # Run tests affected by recent changes
        #{$0} run targeted
        
        # Critical smoke tests before commit
        #{$0} run smoke
        
        # Full validation with parallel execution
        #{$0} run full --parallel --coverage
        
        # Analyze performance and get recommendations
        #{$0} analyze
        
        # Setup the system initially
        #{$0} setup
        
        # Check system status
        #{$0} status
      
      CONFIGURATION:
        Config files are stored in test/ directory:
        - scheduler_config.json     (scheduler configuration)
        - test_timings.json         (performance data)
        - test_dependencies.json    (dependency mapping)
        - smart_runner_config.json  (runner configuration)
      
      For more information, see: docs/testing/test-strategy.md
    HELP
  end
end

# CLI Entry Point
if __FILE__ == $0
  runner = SmartTestRunner.new
  success = runner.run(ARGV)
  exit(success ? 0 : 1)
end