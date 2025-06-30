#!/usr/bin/env ruby
# Simple test runner to identify failing UnificationEngine tests

require 'minitest/autorun'

# Set up load paths
$LOAD_PATH.unshift(File.expand_path('src', __dir__))
$LOAD_PATH.unshift(File.expand_path('test', __dir__))

puts "🧪 Running UnificationEngine Tests (Simple Version)"
puts "=" * 50

begin
  # Load required dependencies
  require_relative 'test/helpers/test_helper'
  require_relative 'test/infrastructure/test_unification_engine'
  
  puts "✅ Test files loaded successfully"
  
rescue LoadError => e
  puts "❌ Failed to load dependencies: #{e.message}"
  puts "🔍 Stack trace:"
  puts e.backtrace.first(10)
  
  # Check what files exist
  puts "\n📂 File existence check:"
  files_to_check = [
    'test/helpers/test_helper.rb',
    'test/helpers/test_constants.rb', 
    'src/reasoning/unification_engine.rb',
    'src/object_model/patlang_object.rb',
    'src/exceptions.rb'
  ]
  
  files_to_check.each do |file|
    if File.exist?(file)
      puts "  ✅ #{file}"
    else
      puts "  ❌ #{file} - MISSING"
    end
  end
  
rescue => e
  puts "💥 Unexpected error: #{e.message}"
  puts "🔍 Error class: #{e.class}"
  puts e.backtrace.first(10)
end

puts "\n🏁 Test execution completed"