#!/usr/bin/env ruby
# frozen_string_literal: true

# Enhanced Test Runner with Real-Time Progress Reporting
# This provides immediate visibility into which test is currently running
# and helps identify hanging tests quickly

puts "🚀 Starting Enhanced Test Suite with Real-Time Progress Reporting..."
puts "   Real-time test execution tracking enabled"
puts "   If a test hangs, you'll see exactly which one!"
puts ""

# Load the real-time test runner components
require_relative 'real_time_test_runner'

# Explicitly call the test loading function that was bypassed
load_test_files

# Run tests with our progress monitoring
exit_code = Minitest.run([])
exit(exit_code)
