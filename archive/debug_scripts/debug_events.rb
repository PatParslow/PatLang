require_relative 'test/infrastructure/test_unification_engine.rb'

# Simple debug script to see event structure
engine = UnificationEngine.new
received_events = []

engine.on_event(:unification_started) do |event_data|
  puts "Received unification_started event:"
  puts "Event data class: #{event_data.class}"
  puts "Event data: #{event_data.inspect}"
  puts "Keys: #{event_data.keys if event_data.respond_to?(:keys)}"
  puts "---"
  received_events << event_data
end

engine.on_event(:unification_completed) do |event_data|
  puts "Received unification_completed event:"
  puts "Event data class: #{event_data.class}"
  puts "Event data: #{event_data.inspect}"
  puts "Keys: #{event_data.keys if event_data.respond_to?(:keys)}"
  puts "---"
  received_events << event_data
end

puts "Testing simple unification..."
result = engine.unify(:hello, :hello, {})
puts "Unification result: #{result}"
puts "Total events received: #{received_events.length}"