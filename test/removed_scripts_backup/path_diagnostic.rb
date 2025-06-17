#!/usr/bin/env ruby

puts "=== PATH DIAGNOSTIC ANALYSIS ==="
puts "Current working directory: #{Dir.pwd}"
puts "File location: #{__FILE__}"
puts "File dirname: #{File.dirname(__FILE__)}"
puts

# Test the problematic path operations
base_path = File.dirname(__FILE__)
puts "Base path: #{base_path}"

# Simulate the problematic file path
test_file = File.join(base_path, 'core', 'test_ast_nodes_comprehensive.rb')
puts "Test file: #{test_file}"
puts "Test file exists: #{File.exist?(test_file)}"

begin
  relative_path = Pathname.new(test_file).relative_path_from(Pathname.new(base_path)).to_s
  puts "Relative path calculation: SUCCESS - #{relative_path}"
rescue => e
  puts "Relative path calculation: FAILED - #{e.class}: #{e.message}"
end

# Test discovery stats
discovery_stats = {
  'legitimate_test_files' => 70,
  'previous_discovery_count' => 61
}

improvement = discovery_stats['legitimate_test_files'] - discovery_stats['previous_discovery_count']
puts "Discovery improvement calculation: #{improvement}"

puts "\n=== RECOMMENDATIONS ==="
puts "1. Run from project root directory (e:/patlang) instead of test directory"
puts "2. Fix path resolution to handle Windows absolute paths correctly"