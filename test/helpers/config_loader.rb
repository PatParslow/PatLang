require 'json'
require 'pathname'

module TestConfigLoader
  class ConfigurationError < StandardError; end
  class ValidationError < StandardError; end

  class << self
    attr_reader :config_cache

    # Load and parse test configuration with caching
    def load_config(config_path = nil)
      @config_cache ||= {}
      
      config_path ||= default_config_path
      config_key = config_path.to_s

      return @config_cache[config_key] if @config_cache[config_key]

      unless File.exist?(config_path)
        raise ConfigurationError, "Configuration file not found: #{config_path}"
      end

      begin
        raw_config = File.read(config_path)
        parsed_config = JSON.parse(raw_config)
        validated_config = validate_config(parsed_config)
        processed_config = process_environment_overrides(validated_config)
        
        @config_cache[config_key] = processed_config
        processed_config
      rescue JSON::ParserError => e
        raise ConfigurationError, "Invalid JSON in configuration file: #{e.message}"
      rescue => e
        raise ConfigurationError, "Error loading configuration: #{e.message}"
      end
    end

    # Get coverage target for a specific component
    def coverage_target(component_name, type = :line)
      config = load_config
      
      # Check for component-specific target
      if config.dig('coverage', 'targets', 'components', component_name)
        return config['coverage']['targets']['components'][component_name][type.to_s]
      end
      
      # Fall back to default target
      config.dig('coverage', 'targets', 'default', type.to_s) || 90
    end

    # Get all coverage targets for components
    def all_coverage_targets(type = :line)
      config = load_config
      targets = {}
      
      components = config.dig('coverage', 'targets', 'components') || {}
      default_target = config.dig('coverage', 'targets', 'default', type.to_s) || 90
      
      components.each do |component, settings|
        targets[component] = settings[type.to_s] || default_target
      end
      
      targets
    end

    # Get coverage thresholds
    def coverage_thresholds
      config = load_config
      thresholds = config.dig('coverage', 'thresholds') || {}
      
      {
        minimum_line: thresholds['minimum_line'] || 70,
        minimum_branch: thresholds['minimum_branch'] || 60,
        warning_line: thresholds['warning_line'] || 80,
        warning_branch: thresholds['warning_branch'] || 75
      }
    end

    # Get coverage reporting configuration
    def coverage_reporting
      config = load_config
      reporting = config.dig('coverage', 'reporting') || {}
      
      {
        output_directory: reporting['output_directory'] || 'test/coverage',
        formats: reporting['formats'] || ['html'],
        save_reports: reporting['save_reports'] != false,
        command_name: reporting['command_name'] || 'Test Suite'
      }
    end

    # Get SimpleCov configuration
    def simplecov_config
      config = load_config
      simplecov = config['simplecov'] || {}
      
      {
        filters: simplecov['filters'] || ['/test/'],
        groups: simplecov['groups'] || {},
        track_files: simplecov['track_files'] || 'src/**/*.rb',
        enable_branch_coverage: simplecov['enable_branch_coverage'] != false
      }
    end

    # Get test category configuration
    def test_category(category_name)
      config = load_config
      category = config.dig('test_categories', category_name)
      
      raise ConfigurationError, "Test category '#{category_name}' not found" unless category
      
      # Process file discovery if needed
      if category['test_directory'] && !category['test_files']
        category['test_files'] = discover_test_files(category['test_directory'])
      end
      
      category
    end

    # Get all test categories
    def all_test_categories
      config = load_config
      config['test_categories'] || {}
    end

    # Get timeout configuration
    def timeout_config(test_type = :default)
      config = load_config
      timeouts = config['timeouts'] || {}
      multiplier = timeouts['global_timeout_multiplier'] || 1.0
      
      case test_type
      when :integration
        (timeouts['integration_test_timeout'] || 60) * multiplier
      when :branch_coverage
        (timeouts['branch_coverage_timeout'] || 45) * multiplier
      when :phase
        (timeouts['phase_test_timeout'] || 120) * multiplier
      else
        (timeouts['default_test_timeout'] || 30) * multiplier
      end
    end

    # Discover test files in a directory
    def discover_test_files(test_directory)
      config = load_config
      patterns = config.dig('discovery', 'test_file_patterns') || ['test/**/test_*.rb']
      exclude_patterns = config.dig('discovery', 'exclude_patterns') || []
      
      found_files = []
      
      patterns.each do |pattern|
        # Adjust pattern to be relative to test directory
        adjusted_pattern = pattern.gsub('test/**/', "#{test_directory}/")
        Dir.glob(adjusted_pattern).each do |file|
          next if exclude_patterns.any? { |exclude| File.fnmatch(exclude, file) }
          found_files << file
        end
      end
      
      found_files.sort.uniq
    end

    # Get component file pattern
    def component_file_pattern(component_name)
      config = load_config
      component_config = config.dig('coverage', 'targets', 'components', component_name)
      component_config ? component_config['file_pattern'] : nil
    end

    # Check if environment overrides are enabled
    def environment_overrides_enabled?
      @config_cache ||= {}
      return @config_cache[:environment_enabled] if @config_cache.key?(:environment_enabled)
      
      config_path = default_config_path
      return false unless File.exist?(config_path)
      
      begin
        raw_config = File.read(config_path)
        parsed_config = JSON.parse(raw_config)
        enabled = parsed_config.dig('environment', 'allow_environment_overrides') != false
        @config_cache[:environment_enabled] = enabled
        enabled
      rescue
        false
      end
    end

    # Get environment variable mapping
    def environment_variables
      @config_cache ||= {}
      return @config_cache[:environment_variables] if @config_cache[:environment_variables]
      
      config_path = default_config_path
      return {} unless File.exist?(config_path)
      
      begin
        raw_config = File.read(config_path)
        parsed_config = JSON.parse(raw_config)
        env_vars = parsed_config.dig('environment', 'environment_variables') || {}
        @config_cache[:environment_variables] = env_vars
        env_vars
      rescue
        {}
      end
    end

    # Validate configuration structure
    def validate_config(config)
      required_sections = %w[coverage test_categories timeouts]
      missing_sections = required_sections - config.keys
      
      unless missing_sections.empty?
        raise ValidationError, "Missing required configuration sections: #{missing_sections.join(', ')}"
      end
      
      # Validate coverage targets
      if config.dig('coverage', 'targets', 'default').nil?
        raise ValidationError, "Default coverage targets are required"
      end
      
      # Validate coverage targets are numeric and reasonable
      validate_coverage_targets(config.dig('coverage', 'targets'))
      
      config
    end

    # Clear configuration cache (useful for testing)
    def clear_cache!
      @config_cache = {}
    end

    # Reload configuration (clears cache and reloads)
    def reload_config!
      clear_cache!
      load_config
    end

    private

    def default_config_path
      File.join(File.dirname(__FILE__), '..', 'test_config.json')
    end

    def validate_coverage_targets(targets)
      return unless targets

      # Validate default targets
      default_targets = targets['default']
      if default_targets
        validate_target_values(default_targets, 'default')
      end

      # Validate component targets
      components = targets['components']
      if components
        components.each do |component, settings|
          validate_target_values(settings, component) if settings.is_a?(Hash)
        end
      end
    end

    def validate_target_values(targets, context)
      %w[line branch].each do |type|
        if targets[type]
          value = targets[type]
          unless value.is_a?(Numeric) && value >= 0 && value <= 100
            raise ValidationError, "Invalid #{type} coverage target for #{context}: #{value}. Must be between 0 and 100."
          end
        end
      end
    end

    def process_environment_overrides(config)
      # Check environment overrides directly from config to avoid circular dependency
      return config unless config.dig('environment', 'allow_environment_overrides') != false

      # Process CI coverage overrides
      if ENV['CI_MIN_COVERAGE']
        min_coverage = ENV['CI_MIN_COVERAGE'].to_i
        if min_coverage > 0 && min_coverage <= 100
          config['coverage']['targets']['default']['line'] = min_coverage
        end
      end

      if ENV['CI_MIN_BRANCH_COVERAGE']
        min_branch_coverage = ENV['CI_MIN_BRANCH_COVERAGE'].to_i
        if min_branch_coverage > 0 && min_branch_coverage <= 100
          config['coverage']['targets']['default']['branch'] = min_branch_coverage
        end
      end

      # Process timeout overrides
      if ENV['TEST_TIMEOUT']
        timeout = ENV['TEST_TIMEOUT'].to_i
        if timeout > 0
          config['timeouts']['default_test_timeout'] = timeout
        end
      end

      # Process coverage directory override
      if ENV['COVERAGE_DIR']
        config['coverage']['reporting']['output_directory'] = ENV['COVERAGE_DIR']
      end

      config
    end
  end
end