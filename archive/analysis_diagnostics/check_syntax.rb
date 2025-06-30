#!/usr/bin/env ruby

files = [
  'src/reasoning/advanced_goal_strategies.rb',
  'src/reasoning/complex_logic_engine.rb',
  'src/reasoning/cross_paradigm_coordinator.rb',
  'src/reasoning/performance_optimizer.rb'
]

files.each do |file|
  puts "Checking syntax for #{file}..."
  system("ruby -c #{file}")
  puts "---"
end