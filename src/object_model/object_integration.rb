require_relative 'patlang_object'
require_relative 'event_system'

# Object Model Integration Layer
#
# Provides seamless integration between the existing Patlang evaluator
# and the new object model, ensuring backward compatibility while
# enabling object-oriented features.

module ObjectModelIntegration
  # Object factory for creating PatlangObjects from evaluation results
  class ObjectFactory
    # Convert raw Ruby values to PatlangObjects
    def self.create_object(value)
      PatlangObject.wrap(value)
    end
    
    # Create objects with specific types
    def self.create_number_object(value)
      PatlangObject.create_number(value)
    end
    
    def self.create_string_object(value)
      PatlangObject.create_string(value)
    end
    
    def self.create_boolean_object(value)
      PatlangObject.create_boolean(value)
    end
    
    def self.create_nil_object
      PatlangObject.create_nil
    end
  end
  
  # Value extractor for getting raw values from PatlangObjects
  class ValueExtractor
    # Extract raw value, handling both objects and raw values
    def self.extract_value(value)
      case value
      when PatlangObject
        value.value
      else
        value
      end
    end
    
    # Extract values from multiple inputs
    def self.extract_values(*values)
      values.map { |v| extract_value(v) }
    end
    
    # Check if value is a PatlangObject
    def self.is_patlang_object?(value)
      value.is_a?(PatlangObject)
    end
  end
  
  # Evaluator mixin to add object model capabilities
  module EvaluatorObjectSupport
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      attr_accessor :object_mode_enabled
      
      def enable_object_mode
        self.object_mode_enabled = true
      end
      
      def disable_object_mode
        self.object_mode_enabled = false
      end
      
      def object_mode_enabled?
        !!object_mode_enabled
      end
    end
    
    def initialize(*args)
      super(*args) if defined?(super)
      @object_mode = self.class.object_mode_enabled?
      @object_event_handlers = {}
      setup_object_event_handlers if @object_mode
    end
    
    # Wrap evaluation results in objects if object mode is enabled
    def wrap_result(value)
      if @object_mode
        ObjectFactory.create_object(value)
      else
        value
      end
    end
    
    # Extract value for computation, handling both objects and raw values
    def extract_value(value)
      ValueExtractor.extract_value(value)
    end
    
    # Extract multiple values
    def extract_values(*values)
      ValueExtractor.extract_values(*values)
    end
    
    # Check if object mode is enabled
    def object_mode?
      @object_mode
    end
    
    # Enable object mode for this evaluator instance
    def enable_object_mode
      @object_mode = true
      setup_object_event_handlers
    end
    
    # Disable object mode for this evaluator instance
    def disable_object_mode
      @object_mode = false
      cleanup_object_event_handlers
    end
    
    # Set up event handlers for object lifecycle events
    def setup_object_event_handlers
      # Handler for object creation events
      @object_event_handlers[:creation] = PatlangObject.on_event(:object_created) do |event|
        handle_object_created(event)
      end
      
      # Handler for value change events
      @object_event_handlers[:value_change] = PatlangObject.on_event(:value_changed) do |event|
        handle_value_changed(event)
      end
      
      # Handler for message events
      @object_event_handlers[:message] = PatlangObject.on_event(:message_sent) do |event|
        handle_message_sent(event)
      end
    end
    
    # Clean up event handlers
    def cleanup_object_event_handlers
      @object_event_handlers.each do |type, handler_id|
        # Note: This would need the actual EventSystem cleanup mechanism
        # For now, we'll just clear our tracking
      end
      @object_event_handlers.clear
    end
    
    # Object lifecycle event handlers (can be overridden by evaluators)
    def handle_object_created(event)
      # Default: do nothing
      # Subclasses can override to add specific behavior
    end
    
    def handle_value_changed(event)
      # Default: do nothing
      # Could be used for reactive programming features
    end
    
    def handle_message_sent(event)
      # Default: do nothing
      # Could be used for debugging or logging
    end
    
    # Helper methods for working with object operations
    def perform_object_operation(left_obj, operator, right_obj)
      # Extract raw values for computation
      left_val, right_val = extract_values(left_obj, right_obj)
      
      # Perform the operation on raw values
      result = yield(left_val, right_val)
      
      # Wrap result if in object mode
      wrapped_result = wrap_result(result)
      
      # If both operands were objects, fire an operation event
      if object_mode? && ValueExtractor.is_patlang_object?(left_obj) && ValueExtractor.is_patlang_object?(right_obj)
        fire_operation_event(left_obj, operator, right_obj, wrapped_result)
      end
      
      wrapped_result
    end
    
    def fire_operation_event(left_obj, operator, right_obj, result)
      # Create operation event data
      event_data = {
        operation: operator,
        left_operand: left_obj.object_id,
        right_operand: right_obj.object_id,
        result: result.is_a?(PatlangObject) ? result.object_id : result
      }
      
      # Fire event on both operands
      left_obj.fire_event(:operation_performed, event_data) if left_obj.is_a?(PatlangObject)
      right_obj.fire_event(:operation_performed, event_data) if right_obj.is_a?(PatlangObject)
    end
  end
  
  # Compatibility layer for existing code
  module CompatibilityLayer
    # Ensure truthiness evaluation works with both objects and raw values
    def self.is_truthy(value)
      case value
      when PatlangObject
        value.to_boolean
      when false, nil
        false
      else
        true
      end
    end
    
    # Ensure string conversion works with both objects and raw values
    def self.to_string(value)
      case value
      when PatlangObject
        value.to_string
      else
        value.to_s
      end
    end
    
    # Ensure numeric conversion works with both objects and raw values
    def self.to_number(value)
      case value
      when PatlangObject
        value.to_number
      when Numeric
        value.to_f
      else
        Float(value.to_s)
      end
    end
    
    # Type checking that works with both objects and raw values
    def self.is_number?(value)
      case value
      when PatlangObject
        value.is_type?(:number)
      else
        value.is_a?(Numeric)
      end
    end
    
    def self.is_string?(value)
      case value
      when PatlangObject
        value.is_type?(:string)
      else
        value.is_a?(String)
      end
    end
    
    def self.is_boolean?(value)
      case value
      when PatlangObject
        value.is_type?(:boolean)
      else
        value.is_a?(TrueClass) || value.is_a?(FalseClass)
      end
    end
  end
  
  # Configuration for object model integration
  class ObjectModelConfig
    @@config = {
      default_object_mode: false,
      auto_wrap_results: true,
      enable_operation_events: true,
      enable_lifecycle_events: true,
      max_object_registry_size: 10000,
      enable_message_passing: true
    }
    
    def self.configure
      yield(@@config) if block_given?
    end
    
    def self.get(key)
      @@config[key]
    end
    
    def self.set(key, value)
      @@config[key] = value
    end
    
    def self.reset_to_defaults
      @@config = {
        default_object_mode: false,
        auto_wrap_results: true,
        enable_operation_events: true,
        enable_lifecycle_events: true,
        max_object_registry_size: 10000,
        enable_message_passing: true
      }
    end
  end
end