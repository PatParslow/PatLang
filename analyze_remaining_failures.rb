#!/usr/bin/env ruby

puts "=== ANALYZING REMAINING 5 FAILURES IN test_object_model.rb ==="
puts

puts "FAILURE 1: test_event_registry_basic (line 279)"
puts "  Error: Expected: 'test' Actual: {:data=>'test'}"
puts "  Issue: Registry event handler receives full event object instead of just data"
puts

puts "FAILURE 2: test_value_modification (line 113)" 
puts "  Error: Expected: 10 Actual: nil"
puts "  Issue: Event handler not being called for value_changed event"
puts

puts "FAILURE 3: test_ping_pong_messages (line 215)"
puts "  Error: Expected to receive pong response"  
puts "  Issue: Message handlers not working properly"
puts

puts "FAILURE 4: test_message_passing (line 195)"
puts "  Error: Expected: 1 Actual: nil"
puts "  Issue: Message event handlers not being triggered"
puts

puts "FAILURE 5: test_object_destruction (line 236)"
puts "  Error: Expected: 1 Actual: nil" 
puts "  Issue: Object destruction event handler not working"
puts

puts "=== ROOT CAUSE HYPOTHESIS ==="
puts "The issue seems to be that object instance events (on_event) are handled"
puts "differently from global events (EventSystem.subscribe). Instance events"
puts "might be passing the data directly while global events pass full objects."
puts

puts "Let me check the PatlangObject fire_event method to see how it calls handlers..."