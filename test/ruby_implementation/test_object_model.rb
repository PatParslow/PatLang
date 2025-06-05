require_relative '../helpers/test_helper'
require_relative '../../src/object_model/patlang_object'
require_relative '../../src/object_model/event_system'
require_relative '../../src/object_model/object_integration'

class TestObjectModel < Minitest::Test
  def setup
    # Clear object registry before each test
    PatlangObject.clear_registry
  end
  
  def teardown
    # Clean up after each test
    PatlangObject.clear_registry
  end
  
  # Test basic object creation and properties
  def test_object_creation
    obj = PatlangObject.new(42, :number)
    
    assert_equal 42, obj.value
    assert_equal 42, obj.raw_value
    assert_equal :number, obj.object_type
    assert obj.object_id > 0
    assert obj.object_id.is_a?(Integer)
  end
  
  def test_object_factory_methods
    num_obj = PatlangObject.create_number(3.14)
    str_obj = PatlangObject.create_string("hello")
    bool_obj = PatlangObject.create_boolean(true)
    nil_obj = PatlangObject.create_nil
    
    assert_equal 3.14, num_obj.value
    assert_equal :number, num_obj.object_type
    
    assert_equal "hello", str_obj.value
    assert_equal :string, str_obj.object_type
    
    assert_equal true, bool_obj.value
    assert_equal :boolean, bool_obj.object_type
    
    assert_nil nil_obj.value
    assert_equal :nil, nil_obj.object_type
  end
  
  def test_object_wrap_method
    # Test wrapping various Ruby types
    num_obj = PatlangObject.wrap(42)
    str_obj = PatlangObject.wrap("test")
    bool_obj = PatlangObject.wrap(true)
    nil_obj = PatlangObject.wrap(nil)
    
    assert_equal :number, num_obj.object_type
    assert_equal :string, str_obj.object_type
    assert_equal :boolean, bool_obj.object_type
    assert_equal :nil, nil_obj.object_type
    
    # Test wrapping already wrapped object
    already_wrapped = PatlangObject.wrap(num_obj)
    assert_same num_obj, already_wrapped
  end
  
  # Test object registry functionality
  def test_object_registry
    assert_equal 0, PatlangObject.object_count
    
    obj1 = PatlangObject.create_number(1)
    obj2 = PatlangObject.create_string("test")
    
    assert_equal 2, PatlangObject.object_count
    assert_same obj1, PatlangObject.find_object(obj1.object_id)
    assert_same obj2, PatlangObject.find_object(obj2.object_id)
    
    all_objects = PatlangObject.all_objects
    assert_includes all_objects, obj1
    assert_includes all_objects, obj2
  end
  
  def test_objects_by_type
    num1 = PatlangObject.create_number(1)
    num2 = PatlangObject.create_number(2)
    str1 = PatlangObject.create_string("test")
    
    numbers = PatlangObject.objects_of_type(:number)
    strings = PatlangObject.objects_of_type(:string)
    
    assert_equal 2, numbers.length
    assert_includes numbers, num1
    assert_includes numbers, num2
    
    assert_equal 1, strings.length
    assert_includes strings, str1
  end
  
  # Test value modification and events
  def test_value_modification
    obj = PatlangObject.create_number(10)
    events_fired = []
    
    # Set up event listener
    obj.on_event(:value_changed) do |event|
      events_fired << event
    end
    
    # Change the value
    obj.value = 20
    
    assert_equal 20, obj.value
    assert_equal 1, events_fired.length
    
    event = events_fired.first
    assert_equal 10, event[:data][:old_value]
    assert_equal 20, event[:data][:new_value]
  end
  
  # Test type conversion methods
  def test_type_conversions
    # Number conversions
    num_obj = PatlangObject.create_number(42.5)
    assert_equal 42.5, num_obj.to_number
    assert_equal "42.5", num_obj.to_string
    assert_equal true, num_obj.to_boolean
    
    # String conversions
    str_obj = PatlangObject.create_string("123.45")
    assert_equal 123.45, str_obj.to_number
    assert_equal "123.45", str_obj.to_string
    assert_equal true, str_obj.to_boolean
    
    # Boolean conversions
    bool_obj = PatlangObject.create_boolean(false)
    assert_equal 0.0, bool_obj.to_number
    assert_equal "false", bool_obj.to_string
    assert_equal false, bool_obj.to_boolean
    
    # Nil conversions
    nil_obj = PatlangObject.create_nil
    assert_equal "", nil_obj.to_string
    assert_equal false, nil_obj.to_boolean
  end
  
  def test_type_checking
    num_obj = PatlangObject.create_number(42)
    str_obj = PatlangObject.create_string("test")
    
    assert num_obj.is_type?(:number)
    refute num_obj.is_type?(:string)
    
    assert str_obj.is_type?(:string)
    refute str_obj.is_type?(:number)
  end
  
  # Test metadata functionality
  def test_metadata
    obj = PatlangObject.create_number(42)
    events_fired = []
    
    obj.on_event(:metadata_changed) do |event|
      events_fired << event
    end
    
    obj.set_metadata(:description, "A meaningful number")
    obj.set_metadata(:category, "important")
    
    assert_equal "A meaningful number", obj.get_metadata(:description)
    assert_equal "important", obj.get_metadata(:category)
    assert_nil obj.get_metadata(:nonexistent)
    
    assert_equal 2, events_fired.length
  end
  
  # Test message passing between objects
  def test_message_passing
    sender = PatlangObject.create_number(1)
    receiver = PatlangObject.create_number(2)
    
    messages_sent = []
    messages_received = []
    
    sender.on_event(:message_sent) do |event|
      messages_sent << event
    end
    
    receiver.on_event(:message_received) do |event|
      messages_received << event
    end
    
    message = sender.send_message(receiver, :greeting, { text: "Hello!" })
    
    assert_equal 1, messages_sent.length
    assert_equal 1, messages_received.length
    
    sent_data = messages_sent.first
    assert_equal sender.object_id, sent_data[:data][:from]
    assert_equal receiver.object_id, sent_data[:data][:to]
    assert_equal :greeting, sent_data[:data][:type]
  end
  
  def test_ping_pong_messages
    obj1 = PatlangObject.create_number(1)
    obj2 = PatlangObject.create_number(2)
    
    pong_received = false
    obj1.on_event(:message_received) do |event|
      if event[:data][:type] == :pong
        pong_received = true
      end
    end
    
    # Send ping message
    obj1.send_message(obj2, :ping, { test: "data" })
    
    # Should receive pong response
    assert pong_received, "Expected to receive pong response"
  end
  
  # Test object lifecycle
  def test_object_destruction
    obj = PatlangObject.create_number(42)
    object_id = obj.object_id
    
    assert_same obj, PatlangObject.find_object(object_id)
    
    destruction_events = []
    obj.on_event(:object_destroyed) do |event|
      destruction_events << event
    end
    
    obj.destroy
    
    assert_nil PatlangObject.find_object(object_id)
    assert_equal 1, destruction_events.length
    
    event = destruction_events.first
    assert_equal object_id, event[:data][:object_id]
    assert_equal 42, event[:data][:final_value]
  end
  
  # Test equality comparison
  def test_equality
    obj1 = PatlangObject.create_number(42)
    obj2 = PatlangObject.create_number(42)
    obj3 = PatlangObject.create_number(43)
    
    assert obj1 == obj2  # Same value
    assert obj1 == 42    # Compare with raw value
    refute obj1 == obj3  # Different value
    refute obj1 == 43    # Different raw value
  end
  
  # Test string representation
  def test_string_representation
    obj = PatlangObject.create_number(42)
    
    str = obj.to_s
    assert_includes str, "PatlangObject"
    assert_includes str, obj.object_id.to_s
    assert_includes str, ":number"
    assert_includes str, "42"
  end
end

# Test the Event System independently
class TestEventSystem < Minitest::Test
  def test_event_registry_basic
    registry = EventSystem::EventRegistry.new
    events_received = []
    
    # Register handler
    handler_id = registry.register_handler(:test_event) do |event|
      events_received << event
    end
    
    # Fire event
    event = registry.fire_event(:test_event, "test")
    
    assert_equal 1, events_received.length
    assert_equal "test", events_received.first[:data]
  end
  
  def test_global_event_handlers
    registry = EventSystem::EventRegistry.new
    global_events = []
    specific_events = []
    
    # Register global handler
    registry.register_global_handler do |event|
      global_events << event
    end
    
    # Register specific handler
    registry.register_handler(:specific) do |event|
      specific_events << event
    end
    
    # Fire different events
    registry.fire_event(:specific, { test: 1 })
    registry.fire_event(:other, { test: 2 })
    
    # Global handler should receive both
    assert_equal 2, global_events.length
    # Specific handler should receive only one
    assert_equal 1, specific_events.length
  end
  
  def test_event_history
    registry = EventSystem::EventRegistry.new
    
    # Fire several events
    registry.fire_event(:event1, { data: 1 })
    registry.fire_event(:event2, { data: 2 })
    registry.fire_event(:event1, { data: 3 })
    
    # Check full history
    history = registry.event_history
    assert_equal 3, history.length
    
    # Check limited history
    limited = registry.event_history(2)
    assert_equal 2, limited.length
    
    # Check events of specific type
    event1s = registry.events_of_type(:event1)
    assert_equal 2, event1s.length
  end
end

# Test Object Integration
class TestObjectIntegration < Minitest::Test
  def test_object_factory
    num_obj = ObjectModelIntegration::ObjectFactory.create_number_object(42)
    str_obj = ObjectModelIntegration::ObjectFactory.create_string_object("test")
    
    assert_equal 42, num_obj.value
    assert_equal :number, num_obj.object_type
    assert_equal "test", str_obj.value
    assert_equal :string, str_obj.object_type
  end
  
  def test_value_extractor
    raw_value = 42
    obj_value = PatlangObject.create_number(42)
    
    # Test extraction
    assert_equal 42, ObjectModelIntegration::ValueExtractor.extract_value(raw_value)
    assert_equal 42, ObjectModelIntegration::ValueExtractor.extract_value(obj_value)
    
    # Test multiple extraction
    values = ObjectModelIntegration::ValueExtractor.extract_values(raw_value, obj_value, "test")
    assert_equal [42, 42, "test"], values
    
    # Test type checking
    refute ObjectModelIntegration::ValueExtractor.is_patlang_object?(raw_value)
    assert ObjectModelIntegration::ValueExtractor.is_patlang_object?(obj_value)
  end
  
  def test_compatibility_layer
    # Test with raw values
    assert ObjectModelIntegration::CompatibilityLayer.is_truthy(42)
    refute ObjectModelIntegration::CompatibilityLayer.is_truthy(false)
    refute ObjectModelIntegration::CompatibilityLayer.is_truthy(nil)
    
    # Test with object values
    true_obj = PatlangObject.create_boolean(true)
    false_obj = PatlangObject.create_boolean(false)
    
    assert ObjectModelIntegration::CompatibilityLayer.is_truthy(true_obj)
    refute ObjectModelIntegration::CompatibilityLayer.is_truthy(false_obj)
  end
  
  def test_configuration
    # Test default configuration
    config = ObjectModelIntegration::ObjectModelConfig
    refute config.get(:default_object_mode)
    assert config.get(:auto_wrap_results)
    
    # Test configuration change
    config.set(:default_object_mode, true)
    assert config.get(:default_object_mode)
    
    # Test reset
    config.reset_to_defaults
    refute config.get(:default_object_mode)
  end
end