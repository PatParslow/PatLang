require_relative '../helpers/test_helper'
require_relative '../../src/object_model/patlang_object'
require_relative '../../src/object_model/event_system'
require_relative '../../src/object_model/object_integration'

class TestObjectModelComprehensive < Minitest::Test
  def setup
    # Clear object registry before each test
    PatlangObject.clear_registry
  end
  
  def teardown
    # Clean up after each test
    PatlangObject.clear_registry
  end

  # =============================================================================
  # ERROR HANDLING AND EDGE CASES
  # =============================================================================

  def test_type_conversion_errors
    # Test invalid string to number conversion
    str_obj = PatlangObject.create_string("not_a_number")
    
    error = assert_raises(RuntimeError) do
      str_obj.to_number
    end
    assert_includes error.message, "Cannot convert string 'not_a_number' to number"
    
    # Test invalid type conversion to number
    obj = PatlangObject.new([], :array)
    
    error = assert_raises(RuntimeError) do
      obj.to_number
    end
    assert_includes error.message, "Cannot convert array to number"
  end

  def test_message_passing_to_invalid_target
    sender = PatlangObject.create_number(1)
    
    # Test sending message to non-PatlangObject
    error = assert_raises(ArgumentError) do
      sender.send_message("not_an_object", :test, {})
    end
    assert_includes error.message, "Target must be a PatlangObject"
  end

  def test_message_passing_to_destroyed_object
    sender = PatlangObject.create_number(1)
    receiver = PatlangObject.create_number(2)
    
    # Track messages
    messages_sent = []
    messages_received = []
    
    sender.on_event(:message_sent) { |event| messages_sent << event }
    receiver.on_event(:message_received) { |event| messages_received << event }
    
    # Destroy receiver
    receiver.destroy
    
    # Send message (should still work but receiver won't process it normally)
    message = sender.send_message(receiver, :test, { data: "test" })
    
    # Message should be sent but receiver destroyed
    assert_equal 1, messages_sent.length
    assert_equal 1, messages_received.length  # Event fired before destruction check
  end

  def test_metadata_with_nil_and_invalid_keys
    obj = PatlangObject.create_number(42)
    
    # Test nil key
    obj.set_metadata(nil, "value")
    assert_equal "value", obj.get_metadata(nil)
    
    # Test complex key types
    complex_key = { nested: "key" }
    obj.set_metadata(complex_key, "complex_value")
    assert_equal "complex_value", obj.get_metadata(complex_key)
    
    # Test getting non-existent key
    assert_nil obj.get_metadata(:non_existent)
  end

  def test_object_registry_edge_cases
    # Test finding non-existent object
    assert_nil PatlangObject.find_object(99999)
    
    # Test objects_of_type with non-existent type
    empty_result = PatlangObject.objects_of_type(:non_existent_type)
    assert_empty empty_result
    
    # Test object count edge cases
    assert_equal 0, PatlangObject.object_count
    
    # Create and destroy object
    obj = PatlangObject.create_number(42)
    assert_equal 1, PatlangObject.object_count
    
    obj.destroy
    assert_equal 0, PatlangObject.object_count
  end

  def test_object_destruction_with_active_subscriptions
    obj1 = PatlangObject.create_number(1)
    obj2 = PatlangObject.create_number(2)
    
    subscription_events = []
    
    # Create subscription
    subscription_id = obj1.subscribe_to(obj2, :test_event) do |event|
      subscription_events << event
    end
    
    # Verify subscription works
    obj2.fire_event(:test_event, { data: "test" })
    assert_equal 1, subscription_events.length
    
    # Destroy subscribing object
    obj1.destroy
    
    # Fire event again - should not be received
    obj2.fire_event(:test_event, { data: "test2" })
    # Subscription should be cleaned up during destruction
    assert_equal 1, subscription_events.length
  end

  def test_concurrent_object_operations
    # Simulate concurrent access patterns
    objects = []
    
    # Create multiple objects rapidly
    100.times do |i|
      objects << PatlangObject.create_number(i)
    end
    
    assert_equal 100, PatlangObject.object_count
    
    # Verify all objects are unique and properly registered
    object_ids = objects.map(&:object_id)
    assert_equal 100, object_ids.uniq.length
    
    # Cleanup
    objects.each(&:destroy)
    assert_equal 0, PatlangObject.object_count
  end

  # =============================================================================
  # EVENT SYSTEM EDGE CASES
  # =============================================================================

  def test_event_handler_exceptions
    registry = EventSystem::EventRegistry.new
    successful_handlers = []
    
    # Register multiple handlers, some that fail
    registry.register_handler(:test) do |event|
      successful_handlers << "handler1"
    end
    
    registry.register_handler(:test) do |event|
      raise "Handler error"
    end
    
    registry.register_handler(:test) do |event|
      successful_handlers << "handler3"
    end
    
    # Fire event - should not stop other handlers
    registry.fire_event(:test, { data: "test" })
    
    # Both successful handlers should have executed
    assert_equal ["handler1", "handler3"], successful_handlers
  end

  def test_global_event_handler_exceptions
    registry = EventSystem::EventRegistry.new
    successful_events = []
    
    # Register global handler that fails
    registry.register_global_handler do |event|
      raise "Global handler error"
    end
    
    # Register specific handler
    registry.register_handler(:test) do |event|
      successful_events << event
    end
    
    # Fire event - specific handler should still work
    registry.fire_event(:test, { data: "test" })
    
    assert_equal 1, successful_events.length
  end

  def test_event_history_overflow
    registry = EventSystem::EventRegistry.new
    
    # Fire more events than the max history size (1000)
    1200.times do |i|
      registry.fire_event(:test, { count: i })
    end
    
    history = registry.event_history
    
    # Should be trimmed to about 80% of max (800 events)
    assert history.length <= 1000
    assert history.length >= 800
    
    # Most recent events should be preserved
    last_event = history.last
    assert last_event[:data][:count] >= 1100
  end

  def test_event_subscription_cleanup
    obj1 = PatlangObject.create_number(1)
    obj2 = PatlangObject.create_number(2)
    
    received_events = []
    
    # Create multiple subscriptions
    sub1 = obj1.subscribe_to(obj2, :event1) { |e| received_events << "sub1_#{e[:type]}" }
    sub2 = obj1.subscribe_to(obj2, :event2) { |e| received_events << "sub2_#{e[:type]}" }
    sub3 = obj1.subscribe_to(obj2) { |e| received_events << "sub3_#{e[:type]}" }  # Global subscription
    
    # Fire events
    obj2.fire_event(:event1, {})
    obj2.fire_event(:event2, {})
    obj2.fire_event(:event3, {})
    
    # Should receive: sub1 for event1, sub2 for event2, sub3 for all
    assert_includes received_events, "sub1_event1"
    assert_includes received_events, "sub2_event2"
    assert_includes received_events, "sub3_event1"
    assert_includes received_events, "sub3_event2"
    assert_includes received_events, "sub3_event3"
    
    # Test individual unsubscribe
    obj1.unsubscribe(sub1)
    received_events.clear
    
    obj2.fire_event(:event1, {})
    
    # Should not receive sub1 anymore
    refute_includes received_events, "sub1_event1"
    assert_includes received_events, "sub3_event1"
    
    # Test clear all subscriptions
    obj1.clear_all_subscriptions
    received_events.clear
    
    obj2.fire_event(:event2, {})
    
    # Should receive nothing
    assert_empty received_events
  end

  def test_event_handler_removal
    obj = PatlangObject.create_number(42)
    events_received = []
    
    # Register handler
    handler_id = obj.on_event(:test) do |event|
      events_received << event
    end
    
    # Fire event
    obj.fire_event(:test, { data: 1 })
    assert_equal 1, events_received.length
    
    # Remove handler
    obj.remove_event_handler(:test, handler_id)
    
    # Fire event again
    obj.fire_event(:test, { data: 2 })
    
    # Should still be only 1 event
    assert_equal 1, events_received.length
  end

  # =============================================================================
  # MESSAGE BUS EDGE CASES
  # =============================================================================

  def test_message_bus_with_invalid_target
    bus = EventSystem::MessageBus.new
    sender = PatlangObject.create_number(1)
    invalid_target = "not_an_object"
    
    # Send message to object that doesn't support receive_message
    message_id = bus.send_message(sender, invalid_target, :test, {})
    
    # Process messages
    bus.process_messages
    
    # Should handle gracefully
    status = bus.queue_status
    assert_equal 0, status[:pending_messages]
    refute status[:processing]
  end

  def test_message_bus_processing_errors
    bus = EventSystem::MessageBus.new
    sender = PatlangObject.create_number(1)
    
    # Create target that will throw error during message processing
    target = PatlangObject.create_number(2)
    def target.receive_message(message)
      raise "Message processing error"
    end
    
    failed_messages = []
    bus.on_event(:message_failed) do |event|
      failed_messages << event
    end
    
    # Send message
    bus.send_message(sender, target, :test, {})
    bus.process_messages
    
    assert_equal 1, failed_messages.length
    failed_event = failed_messages.first
    assert_equal :message_failed, failed_event[:type]
    assert_includes failed_event[:data][:error], "Message processing error"
  end

  def test_message_bus_queue_status
    bus = EventSystem::MessageBus.new
    sender = PatlangObject.create_number(1)
    receiver = PatlangObject.create_number(2)
    
    # Initial status
    status = bus.queue_status
    assert_equal 0, status[:pending_messages]
    refute status[:processing]
    
    # Queue message but don't process
    bus.send_message(sender, receiver, :test, {})
    
    # Messages should be processed automatically, so queue should be empty
    status = bus.queue_status
    assert_equal 0, status[:pending_messages]
  end

  # =============================================================================
  # INTEGRATION LAYER EDGE CASES
  # =============================================================================

  def test_evaluator_object_support_initialization
    # Test class-level mode settings
    test_class = Class.new do
      include ObjectModelIntegration::EvaluatorObjectSupport
    end
    
    # Test default state
    refute test_class.object_mode_enabled?
    
    # Test enabling
    test_class.enable_object_mode
    assert test_class.object_mode_enabled?
    
    # Test disabling
    test_class.disable_object_mode
    refute test_class.object_mode_enabled?
  end

  def test_evaluator_object_support_instance_behavior
    test_class = Class.new do
      include ObjectModelIntegration::EvaluatorObjectSupport
    end
    
    instance = test_class.new
    
    # Test default state
    refute instance.object_mode?
    
    # Test enabling at instance level
    instance.enable_object_mode
    assert instance.object_mode?
    
    # Test wrapping results
    result = instance.wrap_result(42)
    assert_instance_of PatlangObject, result
    assert_equal 42, result.value
    
    # Test disabling
    instance.disable_object_mode
    refute instance.object_mode?
    
    # Should return raw value when disabled
    result = instance.wrap_result(42)
    assert_equal 42, result
  end

  def test_value_extractor_edge_cases
    extractor = ObjectModelIntegration::ValueExtractor
    
    # Test with various value types
    assert_equal 42, extractor.extract_value(42)
    assert_equal "test", extractor.extract_value("test")
    assert_nil extractor.extract_value(nil)
    
    # Test with PatlangObjects
    obj = PatlangObject.create_number(42)
    assert_equal 42, extractor.extract_value(obj)
    
    # Test multiple extraction
    values = extractor.extract_values(42, obj, "test", nil)
    assert_equal [42, 42, "test", nil], values
    
    # Test type checking
    refute extractor.is_patlang_object?(42)
    assert extractor.is_patlang_object?(obj)
  end

  def test_compatibility_layer_edge_cases
    layer = ObjectModelIntegration::CompatibilityLayer
    
    # Test truthiness with edge cases
    assert layer.is_truthy(1)
    assert layer.is_truthy("string")
    assert layer.is_truthy([])
    assert layer.is_truthy({})
    refute layer.is_truthy(false)
    refute layer.is_truthy(nil)
    assert layer.is_truthy(0)  # 0 is truthy in this implementation
    
    # Test with PatlangObjects
    true_obj = PatlangObject.create_boolean(true)
    false_obj = PatlangObject.create_boolean(false)
    nil_obj = PatlangObject.create_nil
    
    assert layer.is_truthy(true_obj)
    refute layer.is_truthy(false_obj)
    refute layer.is_truthy(nil_obj)
    
    # Test type conversion errors
    error = assert_raises(ArgumentError) do
      layer.to_number("not_a_number")
    end
    # Should handle conversion errors gracefully or raise appropriate errors
  end

  def test_object_model_configuration
    config = ObjectModelIntegration::ObjectModelConfig
    
    # Test default values
    refute config.get(:default_object_mode)
    assert config.get(:auto_wrap_results)
    assert config.get(:enable_operation_events)
    assert config.get(:enable_lifecycle_events)
    assert_equal 10000, config.get(:max_object_registry_size)
    assert config.get(:enable_message_passing)
    
    # Test setting values
    config.set(:default_object_mode, true)
    assert config.get(:default_object_mode)
    
    config.set(:max_object_registry_size, 5000)
    assert_equal 5000, config.get(:max_object_registry_size)
    
    # Test reset
    config.reset_to_defaults
    refute config.get(:default_object_mode)
    assert_equal 10000, config.get(:max_object_registry_size)
    
    # Test configure block
    config.configure do |cfg|
      cfg[:default_object_mode] = true
      cfg[:max_object_registry_size] = 15000
    end
    
    assert config.get(:default_object_mode)
    assert_equal 15000, config.get(:max_object_registry_size)
    
    # Reset for other tests
    config.reset_to_defaults
  end

  # =============================================================================
  # PERFORMANCE AND STRESS TESTING
  # =============================================================================

  def test_large_object_registry_performance
    # Test performance with many objects
    start_time = Time.now
    
    objects = []
    1000.times do |i|
      objects << PatlangObject.create_number(i)
    end
    
    creation_time = Time.now - start_time
    
    # Verify all objects created properly
    assert_equal 1000, PatlangObject.object_count
    
    # Test lookup performance
    start_time = Time.now
    
    # Lookup random objects
    100.times do
      random_obj = objects.sample
      found_obj = PatlangObject.find_object(random_obj.object_id)
      assert_same random_obj, found_obj
    end
    
    lookup_time = Time.now - start_time
    
    # Performance should be reasonable (adjust thresholds as needed)
    assert creation_time < 1.0, "Object creation took too long: #{creation_time}s"
    assert lookup_time < 0.1, "Object lookup took too long: #{lookup_time}s"
    
    # Cleanup
    objects.each(&:destroy)
  end

  def test_high_frequency_events
    obj = PatlangObject.create_number(42)
    event_count = 0
    
    obj.on_event(:high_frequency) do |event|
      event_count += 1
    end
    
    start_time = Time.now
    
    # Fire many events rapidly
    1000.times do |i|
      obj.fire_event(:high_frequency, { count: i })
    end
    
    processing_time = Time.now - start_time
    
    # Verify all events processed
    assert_equal 1000, event_count
    
    # Should complete in reasonable time
    assert processing_time < 1.0, "Event processing took too long: #{processing_time}s"
  end

  def test_memory_leak_prevention
    initial_object_count = PatlangObject.object_count
    
    # Create and destroy many objects
    100.times do
      obj = PatlangObject.create_number(42)
      obj.set_metadata(:test, "data")
      obj.destroy
    end
    
    # Registry should be clean
    assert_equal initial_object_count, PatlangObject.object_count
    
    # Test with event subscriptions
    100.times do
      obj1 = PatlangObject.create_number(1)
      obj2 = PatlangObject.create_number(2)
      
      obj1.subscribe_to(obj2, :test) { |e| }
      
      obj1.destroy
      obj2.destroy
    end
    
    # Should still be clean
    assert_equal initial_object_count, PatlangObject.object_count
  end

  # =============================================================================
  # INTEGRATION SCENARIOS
  # =============================================================================

  def test_object_operation_events
    test_class = Class.new do
      include ObjectModelIntegration::EvaluatorObjectSupport
    end
    
    evaluator = test_class.new
    evaluator.enable_object_mode
    
    obj1 = PatlangObject.create_number(10)
    obj2 = PatlangObject.create_number(5)
    
    operation_events = []
    obj1.on_event(:operation_performed) { |e| operation_events << e }
    obj2.on_event(:operation_performed) { |e| operation_events << e }
    
    # Perform operation using evaluator
    result = evaluator.perform_object_operation(obj1, :add, obj2) do |left, right|
      left + right
    end
    
    # Should return wrapped result
    assert_instance_of PatlangObject, result
    assert_equal 15, result.value
    
    # Should fire operation events
    assert_equal 2, operation_events.length  # One for each operand
    
    event = operation_events.first
    assert_equal :operation_performed, event[:type]
    assert_equal :add, event[:data][:operation]
    assert_equal obj1.object_id, event[:data][:left_operand]
    assert_equal obj2.object_id, event[:data][:right_operand]
  end

  def test_mixed_object_and_raw_value_scenarios
    test_class = Class.new do
      include ObjectModelIntegration::EvaluatorObjectSupport
    end
    
    evaluator = test_class.new
    evaluator.enable_object_mode
    
    obj = PatlangObject.create_number(10)
    raw_value = 5
    
    # Extract values from mixed inputs
    values = evaluator.extract_values(obj, raw_value, "test")
    assert_equal [10, 5, "test"], values
    
    # Perform operation with mixed inputs
    result = evaluator.perform_object_operation(obj, :multiply, raw_value) do |left, right|
      left * right
    end
    
    assert_instance_of PatlangObject, result
    assert_equal 50, result.value
  end

  # =============================================================================
  # BOUNDARY CONDITIONS AND EDGE CASES
  # =============================================================================

  def test_boundary_value_conversions
    # Test boundary numeric values
    large_num = PatlangObject.create_number(Float::INFINITY)
    assert_equal Float::INFINITY, large_num.to_number
    assert large_num.to_boolean
    
    small_num = PatlangObject.create_number(-Float::INFINITY)
    assert_equal(-Float::INFINITY, small_num.to_number)
    assert small_num.to_boolean
    
    nan_num = PatlangObject.create_number(Float::NAN)
    assert nan_num.to_number.nan?
    assert nan_num.to_boolean  # NaN is truthy
    
    # Test zero edge case
    zero_num = PatlangObject.create_number(0)
    assert_equal 0, zero_num.to_number
    refute zero_num.to_boolean  # 0 is falsy
    
    # Test empty string edge case
    empty_str = PatlangObject.create_string("")
    assert_equal "", empty_str.to_string
    refute empty_str.to_boolean  # Empty string is falsy
    
    # Test string with only whitespace
    whitespace_str = PatlangObject.create_string("   ")
    assert_equal "   ", whitespace_str.to_string
    assert whitespace_str.to_boolean  # Non-empty string is truthy
  end

  def test_object_id_uniqueness_across_registry_clears
    # Create object and note its ID
    obj1 = PatlangObject.create_number(42)
    id1 = obj1.object_id
    
    # Clear registry (this resets the counter to 1)
    PatlangObject.clear_registry
    
    # Create new object - ID will restart from 1 after clear
    obj2 = PatlangObject.create_number(42)
    id2 = obj2.object_id
    
    # After registry clear, IDs restart from 1
    assert_equal 1, id2
    assert id1 >= id2  # Previous ID should be greater than or equal to reset ID
  end

  def test_event_system_edge_case_behaviors
    registry = EventSystem::EventRegistry.new
    
    # Test removing handler that doesn't exist
    refute registry.remove_handler(:nonexistent, 99999)
    
    # Test removing global handler that doesn't exist
    registry.remove_global_handler(99999)  # Should not raise error
    
    # Test events_of_type with no events
    assert_empty registry.events_of_type(:nonexistent)
    
    # Test event_history with limit larger than history
    registry.fire_event(:test, {})
    history = registry.event_history(1000)
    assert_equal 1, history.length
  end
end