#!/usr/bin/env ruby

require_relative 'test/infrastructure/test_type_constraint_parser'
require 'minitest'

# Test if the event system fix works
puts "=== Testing Event System Fix ==="

test = TestTypeConstraintParser.new(:test_parse_simple_type_annotation)
begin
  test.setup
  puts 'Setup completed'
  
  # Test that parser now has event support
  code = "x :: Number"
  parser = test.send(:create_parser, code)
  puts "Parser responds to on_event?: #{parser.respond_to?(:on_event)}"
  puts "Parser responds to fire_event?: #{parser.respond_to?(:fire_event)}"
  
  # Run the actual test
  test.test_parse_simple_type_annotation
  puts 'Test completed successfully - EVENT SYSTEM FIXED!'
rescue => e
  puts 'Test error: ' + e.message
  puts e.backtrace.first(10).join('\n')
end