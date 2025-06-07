#!/usr/bin/env ruby
# frozen_string_literal: true

# Enhanced Test Runner with Real-Time Progress Reporting
# This provides immediate visibility into which test is currently running
# and helps identify hanging tests quickly

puts "🚀 Starting Enhanced Test Suite with Real-Time Progress Reporting..."
puts "   Real-time test execution tracking enabled"
puts "   If a test hangs, you'll see exactly which one!"
puts ""

# Load and execute the real-time test runner
require_relative 'real_time_test_runner'

# The real_time_test_runner.rb handles everything when required
# It will automatically run when this file is executed
