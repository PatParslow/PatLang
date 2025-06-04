require_relative 'test_helper'
require_relative '../src/object_model/patlang_object'
require_relative '../src/object_model/event_system'
require_relative '../src/object_model/object_integration'

class TestObjectModelStress < Minitest::Test
  def setup
    PatlangObject.clear_registry
  end
  
  def teardown
    PatlangObject.clear_registry
  end

  # =============================================================================
  # STRESS TESTING AND PERFORMANCE VALIDATION
  # =============================================================================

  def test_object_registry_size_limits
    # Test approaching the configured limit
    config = ObjectModelIntegration::ObjectModelConfig
    original_limit = config.get(:max_object_registry_size)
    
    # Set a smaller limit for testing
    config.set(:max_object_registry_size, 100)
    
    objects = []
    
    # Create objects up to the limit
    100.times do |i|
      objects << PatlangObject.create_number(i)
    end
    
    assert_equal 100, PatlangObject.object_count
    
    # Creating more should still work (implementation may handle this differently)
    extra_obj = PatlangObject.create_number(999)
    assert_instance_of PatlangObject, extra_obj
    
    # Cleanup
    objects.each(&:destroy)
    extra_obj.destroy
    
    # Restore original limit
    config.set(:max_object_registry_size, original_limit)
  end

  def test_high_frequency_message_passing
    sender = PatlangObject.create_number(1)
    receiver = PatlangObject.create_number(2)
    
    messages_received = 0
    receiver.on_event(:message_received) do |event|
      messages_received += 1
    end
    
    start_time = Time.now
    
    # Send many messages rapidly
    1000.times do |i|
      sender.send_message(receiver, :stress_test, { count: i })
    end
    
    processing_time = Time.now - start_time
    
    # Verify all messages received
    assert_equal 1000, messages_received
    
    # Should complete in reasonable time
    assert processing_time < 2.0, "Message passing took too long: #{processing_time}s"
  end

  def test_deep_event_subscription_chains
    # Create a chain of objects that forward events
    chain_length = 50
    objects = []
    
    chain_length.times do |i|
      objects << PatlangObject.create_number(i)
    end
    
    final_events = []
    
    # Set up final receiver first
    objects.last.on_event(:chain_event) do |event|
      final_events << event
    end
    
    # Set up chain: each object forwards events to the next
    (chain_length - 1).times do |i|
      current_obj = objects[i]
      next_obj = objects[i + 1]
      
      current_obj.on_event(:chain_event) do |event|
        next_obj.fire_event(:chain_event, event[:data])
      end
    end
    
    # Start the chain
    objects.first.fire_event(:chain_event, { start: "chain_test" })
    
    # Should reach the end
    assert_equal 1, final_events.length
    assert_equal "chain_test", final_events.first[:data][:start]
  end

  def test_concurrent_object_destruction
    # Create many objects with cross-references
    objects = []
    100.times do |i|
      objects << PatlangObject.create_number(i)
    end
    
    # Create subscriptions between random objects
    subscriptions = []
    50.times do
      obj1 = objects.sample
      obj2 = objects.sample
      next if obj1 == obj2
      
      subscription = obj1.subscribe_to(obj2, :test) { |e| }
      subscriptions << [obj1, subscription]
    end
    
    # Destroy all objects (simulating concurrent destruction)
    destruction_errors = []
    objects.each do |obj|
      begin
        obj.destroy
      rescue => e
        destruction_errors << e
      end
    end
    
    # Should handle destruction gracefully
    assert_empty destruction_errors
    assert_equal 0, PatlangObject.object_count
  end

  def test_memory_intensive_metadata_operations
    obj = PatlangObject.create_number(42)
    
    # Add large amounts of metadata
    1000.times do |i|
      obj.set_metadata("key_#{i}", "value_#{i}" * 100)  # Large string values
    end
    
    # Verify metadata is accessible
    assert_equal "value_500" * 100, obj.get_metadata("key_500")
    
    # Modify metadata rapidly
    start_time = Time.now
    
    100.times do |i|
      obj.set_metadata("rapid_key", "rapid_value_#{i}")
    end
    
    modification_time = Time.now - start_time
    
    # Should complete quickly
    assert modification_time < 0.5, "Metadata modification took too long: #{modification_time}s"
    
    assert_equal "rapid_value_99", obj.get_metadata("rapid_key")
  end

  def test_event_history_under_stress
    registry = EventSystem::EventRegistry.new
    
    # Fire events rapidly with different types
    event_types = [:type1, :type2, :type3, :type4, :type5]
    
    start_time = Time.now
    
    5000.times do |i|
      event_type = event_types[i % event_types.length]
      registry.fire_event(event_type, { count: i, data: "stress_test_#{i}" })
    end
    
    processing_time = Time.now - start_time
    
    # Verify history management
    history = registry.event_history
    assert history.length <= 1000  # Should be capped at max history size
    
    # Verify type-specific queries work under stress
    type1_events = registry.events_of_type(:type1)
    assert type1_events.length > 0
    
    # Should complete in reasonable time
    assert processing_time < 1.0, "Event processing under stress took too long: #{processing_time}s"
  end

  def test_message_bus_under_heavy_load
    bus = EventSystem::MessageBus.new
    
    # Create multiple senders and receivers
    senders = 10.times.map { |i| PatlangObject.create_number(i) }
    receivers = 10.times.map { |i| PatlangObject.create_number(i + 100) }
    
    messages_processed = 0
    
    receivers.each do |receiver|
      receiver.on_event(:message_received) do |event|
        messages_processed += 1
      end
    end
    
    start_time = Time.now
    
    # Each sender sends messages to each receiver
    senders.each do |sender|
      receivers.each do |receiver|
        10.times do |i|
          bus.send_message(sender, receiver, :stress_message, { round: i })
        end
      end
    end
    
    # Process all messages
    bus.process_messages
    
    processing_time = Time.now - start_time
    
    # Verify all messages processed
    expected_messages = senders.length * receivers.length * 10
    assert_equal expected_messages, messages_processed
    
    # Should complete in reasonable time
    assert processing_time < 2.0, "Message bus under load took too long: #{processing_time}s"
    
    # Queue should be empty
    status = bus.queue_status
    assert_equal 0, status[:pending_messages]
  end

  def test_type_conversion_performance
    # Test performance of type conversions under stress
    numbers = 1000.times.map { |i| PatlangObject.create_number(i * 3.14) }
    strings = 1000.times.map { |i| PatlangObject.create_string("value_#{i}") }
    booleans = 1000.times.map { |i| PatlangObject.create_boolean(i.even?) }
    
    start_time = Time.now
    
    # Perform many conversions
    numbers.each do |num|
      num.to_string
      num.to_boolean
    end
    
    strings.each do |str|
      str.to_boolean
      # Skip to_number for non-numeric strings to avoid errors
    end
    
    booleans.each do |bool|
      bool.to_string
      bool.to_number
    end
    
    conversion_time = Time.now - start_time
    
    # Should complete in reasonable time
    assert conversion_time < 1.0, "Type conversions took too long: #{conversion_time}s"
  end

  def test_object_equality_performance
    # Create many objects with same values
    objects1 = 1000.times.map { PatlangObject.create_number(42) }
    objects2 = 1000.times.map { PatlangObject.create_number(42) }
    
    start_time = Time.now
    
    # Compare all objects
    comparison_results = []
    objects1.each do |obj1|
      objects2.each do |obj2|
        comparison_results << (obj1 == obj2)
        break  # Just test one comparison per object to keep it reasonable
      end
    end
    
    comparison_time = Time.now - start_time
    
    # All should be equal (same values)
    assert comparison_results.all?, "Not all comparisons returned true"
    
    # Should complete in reasonable time
    assert comparison_time < 0.5, "Object comparisons took too long: #{comparison_time}s"
  end

  def test_registry_lookup_performance_under_stress
    # Create many objects
    objects = 5000.times.map { |i| PatlangObject.create_number(i) }
    
    start_time = Time.now
    
    # Perform many random lookups
    1000.times do
      random_obj = objects.sample
      found_obj = PatlangObject.find_object(random_obj.object_id)
      assert_same random_obj, found_obj
    end
    
    lookup_time = Time.now - start_time
    
    # Should complete quickly even with large registry
    assert lookup_time < 1.0, "Registry lookups took too long: #{lookup_time}s"
    
    # Test all_objects performance
    start_time = Time.now
    all_objects = PatlangObject.all_objects
    all_objects_time = Time.now - start_time
    
    assert_equal 5000, all_objects.length
    assert all_objects_time < 0.1, "all_objects call took too long: #{all_objects_time}s"
    
    # Test objects_of_type performance
    start_time = Time.now
    number_objects = PatlangObject.objects_of_type(:number)
    type_query_time = Time.now - start_time
    
    assert_equal 5000, number_objects.length
    assert type_query_time < 0.5, "objects_of_type call took too long: #{type_query_time}s"
  end
end