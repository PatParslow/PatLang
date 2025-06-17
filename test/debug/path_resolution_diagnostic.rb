#!/usr/bin/env ruby
require 'pathname'

puts "=== DETAILED PATH RESOLUTION DIAGNOSTIC ==="
puts "Current working directory: #{Dir.pwd}"

# Simulate the exact conditions in the test runner
base_path = File.join(Dir.pwd, 'test')
puts "Base path (test dir): #{base_path}"

# Find a real test file
test_files = Dir.glob(File.join(base_path, '**', 'test_*.rb'))
sample_file = test_files.first
puts "Sample test file: #{sample_file}"

if sample_file
  puts "\n=== PATH RESOLUTION ATTEMPT ==="
  begin
    # This is the exact line failing in the runner (line 183)
    relative_path = Pathname.new(sample_file).relative_path_from(Pathname.new(base_path)).to_s
    puts "SUCCESS: #{relative_path}"
  rescue => e
    puts "FAILED: #{e.class}: #{e.message}"
    puts "Sample file pathname: #{Pathname.new(sample_file)}"
    puts "Base path pathname: #{Pathname.new(base_path)}"
    puts "Sample file absolute?: #{Pathname.new(sample_file).absolute?}"
    puts "Base path absolute?: #{Pathname.new(base_path).absolute?}"
  end
end

puts "\n=== DISCOVERY STATS ISSUE ==="
# Test the nil issue on line 814
discovery_stats = nil
puts "discovery_stats is nil: #{discovery_stats.nil?}"

begin
  improvement = discovery_stats['legitimate_test_files'] - discovery_stats['previous_discovery_count']
  puts "SUCCESS: #{improvement}"
rescue => e
  puts "FAILED: #{e.class}: #{e.message}"
end