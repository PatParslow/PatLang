# frozen_string_literal: true

# BuildContext provides build environment and state management
# for PaTLang build tool execution, integrating with the reasoning system
# for intelligent build coordination and optimization.
class BuildContext
  attr_reader :variables, :build_root, :dependency_info, :cache_manager
  
  def initialize(context_data = {})
    @variables = context_data.dup
    @build_root = @variables.delete(:build_root) || Dir.pwd
    @dependency_info = {}
    @cache_manager = BuildCacheManager.new
    @start_time = Time.now
    
    # Set up default build variables
    setup_default_variables
  end

  def get(key)
    @variables[key.to_sym] || @variables[key.to_s]
  end

  def set(key, value)
    @variables[key.to_sym] = value
  end

  def has?(key)
    @variables.key?(key.to_sym) || @variables.key?(key.to_s)
  end

  def get_dependency_info(dep_name)
    @dependency_info[dep_name.to_sym]
  end

  def set_dependency_info(dep_name, info)
    @dependency_info[dep_name.to_sym] = info.merge(updated_at: Time.now)
  end

  def relative_path(path)
    return path if Pathname.new(path).absolute?
    File.join(@build_root, path)
  end

  def expand_path(path)
    File.expand_path(relative_path(path))
  end

  def build_elapsed_time
    Time.now - @start_time
  end

  def to_h
    @variables.dup
  end

  private

  def setup_default_variables
    @variables[:build_root] ||= @build_root
    @variables[:timestamp] ||= @start_time.to_i
    @variables[:build_id] ||= generate_build_id
    @variables[:parallel_jobs] ||= processor_count
    @variables[:verbose] ||= false
  end

  def generate_build_id
    "build_#{Time.now.strftime('%Y%m%d_%H%M%S')}_#{rand(1000..9999)}"
  end

  def processor_count
    # Try to detect number of processors for parallel builds
    begin
      require 'etc'
      Etc.nprocessors
    rescue
      4 # Fallback to reasonable default
    end
  end
end

# Simple cache manager for build artifacts and dependency tracking
class BuildCacheManager
  def initialize
    @cache_dir = '.build_cache'
    @artifact_cache = {}
    @dependency_cache = {}
    ensure_cache_directory
  end

  def cache_artifact(key, data)
    @artifact_cache[key] = {
      data: data,
      timestamp: Time.now,
      size: data.to_s.length
    }
  end

  def get_cached_artifact(key)
    cached = @artifact_cache[key]
    return nil unless cached
    
    # Simple TTL check (1 hour)
    return nil if Time.now - cached[:timestamp] > 3600
    
    cached[:data]
  end

  def cache_dependency_info(target, deps)
    @dependency_cache[target] = {
      dependencies: deps,
      cached_at: Time.now
    }
  end

  def get_cached_dependencies(target)
    cached = @dependency_cache[target]
    return nil unless cached
    
    cached[:dependencies]
  end

  def clear_cache
    @artifact_cache.clear
    @dependency_cache.clear
  end

  def cache_stats
    {
      artifacts: @artifact_cache.length,
      dependencies: @dependency_cache.length,
      total_size: @artifact_cache.values.sum { |v| v[:size] }
    }
  end

  private

  def ensure_cache_directory
    Dir.mkdir(@cache_dir) unless Dir.exist?(@cache_dir)
  end
end