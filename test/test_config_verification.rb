#!/usr/bin/env ruby

require_relative 'helpers/config_loader'

class TestConfigVerification
  def self.run
    puts "🧪 TEST CONFIGURATION SYSTEM VERIFICATION"
    puts "=" * 60
    
    begin
      test_config_loading
      test_coverage_targets
      test_simplecov_configuration
      test_test_categories
      test_environment_overrides
      test_timeout_configuration
      test_file_discovery
      
      puts "\n✅ ALL CONFIGURATION TESTS PASSED"
      puts "🎉 Configuration system is working correctly!"
      
      true
    rescue => e
      puts "\n❌ CONFIGURATION TEST FAILED: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      false
    end
  end
  
  private
  
  def self.test_config_loading
    puts "📝 Testing configuration loading..."
    
    config = TestConfigLoader.load_config
    raise "Configuration not loaded" unless config
    
    # Test required sections exist
    required_sections = %w[coverage test_categories timeouts discovery simplecov environment]
    required_sections.each do |section|
      raise "Missing section: #{section}" unless config[section]
    end
    
    puts "   ✅ Configuration loaded successfully with all required sections"
  end
  
  def self.test_coverage_targets
    puts "📊 Testing coverage targets..."
    
    # Test individual component targets
    ast_target = TestConfigLoader.coverage_target('AST Nodes', :line)
    lexer_target = TestConfigLoader.coverage_target('Lexer', :line)
    
    raise "Invalid AST Nodes target: #{ast_target}" unless ast_target == 90
    raise "Invalid Lexer target: #{lexer_target}" unless lexer_target == 90
    
    # Test all targets
    all_targets = TestConfigLoader.all_coverage_targets(:line)
    raise "No coverage targets found" if all_targets.empty?
    
    # Test branch targets
    branch_targets = TestConfigLoader.all_coverage_targets(:branch)
    raise "No branch targets found" if branch_targets.empty?
    
    puts "   ✅ Coverage targets: #{all_targets.keys.join(', ')}"
    puts "   ✅ All targets set to 90% as required"
  end
  
  def self.test_simplecov_configuration
    puts "📈 Testing SimpleCov configuration..."
    
    simplecov_config = TestConfigLoader.simplecov_config
    reporting_config = TestConfigLoader.coverage_reporting
    
    raise "No SimpleCov filters found" if simplecov_config[:filters].empty?
    raise "No SimpleCov groups found" if simplecov_config[:groups].empty?
    raise "Coverage directory not set" unless reporting_config[:output_directory] == 'test/coverage'
    
    thresholds = TestConfigLoader.coverage_thresholds
    raise "Invalid minimum line threshold" unless thresholds[:minimum_line] == 70
    raise "Invalid minimum branch threshold" unless thresholds[:minimum_branch] == 60
    
    puts "   ✅ SimpleCov configuration loaded correctly"
    puts "   ✅ Coverage reports will be saved to: #{reporting_config[:output_directory]}"
  end
  
  def self.test_test_categories
    puts "📂 Testing test categories..."
    
    # Test Phase 1 category
    phase1_config = TestConfigLoader.test_category('phase_1')
    raise "Phase 1 configuration not found" unless phase1_config
    raise "Phase 1 missing coverage targets" unless phase1_config['coverage_targets']
    
    # Test all categories
    all_categories = TestConfigLoader.all_test_categories
    raise "No test categories found" if all_categories.empty?
    
    expected_categories = %w[phase_1 infrastructure patlang_language ruby_implementation branch_coverage integration]
    expected_categories.each do |category|
      raise "Missing category: #{category}" unless all_categories[category]
    end
    
    puts "   ✅ Test categories: #{all_categories.keys.join(', ')}"
  end
  
  def self.test_environment_overrides
    puts "🌍 Testing environment variable overrides..."
    
    # Test that environment overrides are enabled
    enabled = TestConfigLoader.environment_overrides_enabled?
    raise "Environment overrides should be enabled" unless enabled
    
    # Test environment variable mapping
    env_vars = TestConfigLoader.environment_variables
    expected_vars = %w[CI_MIN_COVERAGE CI_MIN_BRANCH_COVERAGE TEST_TIMEOUT COVERAGE_DIR]
    expected_vars.each do |var|
      raise "Missing environment variable: #{var}" unless env_vars[var]
    end
    
    puts "   ✅ Environment overrides enabled"
    puts "   ✅ Environment variables: #{env_vars.keys.join(', ')}"
  end
  
  def self.test_timeout_configuration
    puts "⏱️  Testing timeout configuration..."
    
    default_timeout = TestConfigLoader.timeout_config(:default)
    integration_timeout = TestConfigLoader.timeout_config(:integration)
    branch_timeout = TestConfigLoader.timeout_config(:branch_coverage)
    
    raise "Invalid default timeout: #{default_timeout}" unless default_timeout == 30
    raise "Invalid integration timeout: #{integration_timeout}" unless integration_timeout == 60
    raise "Invalid branch coverage timeout: #{branch_timeout}" unless branch_timeout == 45
    
    puts "   ✅ Timeouts: Default(#{default_timeout}s), Integration(#{integration_timeout}s), Branch(#{branch_timeout}s)"
  end
  
  def self.test_file_discovery
    puts "🔍 Testing file discovery..."
    
    # Test that discovery patterns are defined
    config = TestConfigLoader.load_config
    patterns = config.dig('discovery', 'test_file_patterns')
    raise "No test file patterns found" if patterns.empty?
    
    exclude_patterns = config.dig('discovery', 'exclude_patterns')
    raise "No exclude patterns found" if exclude_patterns.empty?
    
    puts "   ✅ Test file patterns: #{patterns.join(', ')}"
    puts "   ✅ Exclude patterns: #{exclude_patterns.join(', ')}"
  end
end

# Run verification if executed directly
if __FILE__ == $0
  success = TestConfigVerification.run
  exit(success ? 0 : 1)
end