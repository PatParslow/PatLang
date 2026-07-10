#!/usr/bin/env ruby
# Test runner to identify failing UnificationEngine tests

# Set up basic reporting

# Set up load paths
$LOAD_PATH.unshift(File.expand_path('src', __dir__))
$LOAD_PATH.unshift(File.expand_path('test', __dir__))

puts "🧪 Running UnificationEngine Tests"
puts "=" * 50

begin
  # Load the test file
  require_relative 'test/infrastructure/test_unification_engine.rb'
  
  puts "✅ Test file loaded successfully"
  puts "📊 Running tests..."
  
rescue LoadError => e
  puts "❌ Failed to load test dependencies: #{e.message}"
  puts "🔍 Checking for missing files..."
  
  required_files = [
    'test/helpers/test_helper.rb',
    'src/reasoning/unification_engine.rb',
    'src/object_model/patlang_object.rb'
  ]
  
  required_files.each do |file|
    if File.exist?(file)
      puts "  ✅ #{file}"
    else
      puts "  ❌ #{file} - MISSING"
    end
  end
  
rescue => e
  puts "💥 Unexpected error: #{e.message}"
  puts e.backtrace.first(5)
end