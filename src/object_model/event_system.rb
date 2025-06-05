# Event System for Patlang Object Model
#
# Provides comprehensive event management, message passing infrastructure,
# and performance optimization for the object-oriented architecture.

module EventSystem
  # Event handler registry and management
  class EventRegistry
    def initialize
      @handlers = {}
      @global_handlers = []
      @event_history = []
      @max_history_size = 1000
    end
    
    # Register an event handler for a specific event type
    def register_handler(event_type, handler = nil, &block)
      handler ||= block
      raise ArgumentError, "Handler must be provided" unless handler
      
      @handlers[event_type] ||= []
      @handlers[event_type] << handler
      
      # Return handler ID for potential removal
      handler.object_id
    end
    
    # Register a global handler that receives all events
    def register_global_handler(handler = nil, &block)
      handler ||= block
      raise ArgumentError, "Handler must be provided" unless handler
      
      @global_handlers << handler
      handler.object_id
    end
    
    # Remove a specific handler
    def remove_handler(event_type, handler_id)
      return false unless @handlers[event_type]
      
      @handlers[event_type].reject! { |h| h.object_id == handler_id }
      @handlers.delete(event_type) if @handlers[event_type].empty?
      true
    end
    
    # Remove a global handler
    def remove_global_handler(handler_id)
      @global_handlers.reject! { |h| h.object_id == handler_id }
      true
    end
    
    # Fire an event to all registered handlers
    def fire_event(event_type, event_data = {})
      event = create_event(event_type, event_data)
      
      # Add to history
      add_to_history(event)
      
      # Fire to specific handlers
      handlers = @handlers[event_type] || []
      handlers.each do |handler|
        begin
          handler.call(event)
        rescue => e
          # Log error but don't stop other handlers
          warn "Event handler error for #{event_type}: #{e.message}"
        end
      end
      
      # Fire to global handlers (always get full event)
      @global_handlers.each do |handler|
        begin
          handler.call(event)
        rescue => e
          warn "Global event handler error: #{e.message}"
        end
      end
      
      event
    end
    
    # Get event history
    def event_history(limit = nil)
      limit ? @event_history.last(limit) : @event_history.dup
    end
    
    # Clear event history
    def clear_history
      @event_history.clear
    end
    
    # Get events of a specific type from history
    def events_of_type(event_type, limit = nil)
      events = @event_history.select { |e| e[:type] == event_type }
      limit ? events.last(limit) : events
    end
    
    private
    
    def create_event(event_type, event_data)
      {
        type: event_type,
        data: event_data,
        timestamp: Time.now,
        event_id: generate_event_id
      }
    end
    
    def add_to_history(event)
      @event_history << event
      
      # Trim history if it gets too large
      if @event_history.size > @max_history_size
        @event_history = @event_history.last(@max_history_size * 0.8)
      end
    end
    
    def generate_event_id
      @event_id_counter ||= 0
      @event_id_counter += 1
    end
  end
  
  # Mixin module for objects that can participate in the event system
  module EventCapable
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      # Class-level event registry
      def event_registry
        @event_registry ||= EventRegistry.new
      end
      
      # Register class-level event handlers
      def on_event(event_type, &block)
        event_registry.register_handler(event_type, block)
      end
      
      # Register global event handlers at class level
      def on_all_events(&block)
        event_registry.register_global_handler(block)
      end
    end
    
    def initialize_event_system
      @instance_event_registry = EventRegistry.new
      @event_subscriptions = {}
    end
    
    # Instance-level event handling
    def on_event(event_type, &block)
      initialize_event_system unless @instance_event_registry
      @instance_event_registry.register_handler(event_type, block)
    end
    
    def on_all_events(&block)
      initialize_event_system unless @instance_event_registry
      @instance_event_registry.register_global_handler(block)
    end
    
    # Register for cross-object events (receives full event objects)
    def on_cross_object_event(event_type, &block)
      @cross_object_event_registry ||= EventRegistry.new
      @cross_object_event_registry.register_handler(event_type, block)
    end
    
    # Register for all cross-object events (receives full event objects)
    def on_all_cross_object_events(&block)
      @cross_object_event_registry ||= EventRegistry.new
      @cross_object_event_registry.register_global_handler(block)
    end
    
    # Fire an event from this object
    def fire_event(event_type, event_data = {})
      # Add source object information
      enhanced_data = event_data.merge(source: self)
      
      # Fire on instance handlers
      if @instance_event_registry
        @instance_event_registry.fire_event(event_type, enhanced_data)
      end
      
      # Fire on cross-object handlers
      if @cross_object_event_registry
        @cross_object_event_registry.fire_event(event_type, enhanced_data)
      end
      
      # Fire on class handlers
      self.class.event_registry.fire_event(event_type, enhanced_data)
    end
    
    # Subscribe to events from another object (gets full event objects)
    def subscribe_to(other_object, event_type = nil, &block)
      subscription_id = block.object_id
      
      if event_type
        handler_id = other_object.on_cross_object_event(event_type, &block)
      else
        handler_id = other_object.on_all_cross_object_events(&block)
      end
      
      # Track subscription for cleanup
      @event_subscriptions ||= {}
      @event_subscriptions[subscription_id] = {
        object: other_object,
        handler_id: handler_id,
        event_type: event_type
      }
      
      subscription_id
    end
    
    # Unsubscribe from events
    def unsubscribe(subscription_id)
      return false unless @event_subscriptions&.[](subscription_id)
      
      subscription = @event_subscriptions[subscription_id]
      if subscription[:event_type]
        subscription[:object].remove_event_handler(subscription[:event_type], subscription[:handler_id])
      else
        subscription[:object].remove_global_handler(subscription[:handler_id])
      end
      
      @event_subscriptions.delete(subscription_id)
      true
    end
    
    # Clear all subscriptions (useful for cleanup)
    def clear_all_subscriptions
      return unless @event_subscriptions
      
      @event_subscriptions.each do |subscription_id, _|
        unsubscribe(subscription_id)
      end
    end
    
    # Remove specific event handlers (tries both instance and cross-object registries)
    def remove_event_handler(event_type, handler_id)
      result = false
      
      # Try instance registry first
      if @instance_event_registry
        result = @instance_event_registry.remove_handler(event_type, handler_id) || result
      end
      
      # Try cross-object registry
      if @cross_object_event_registry
        result = @cross_object_event_registry.remove_handler(event_type, handler_id) || result
      end
      
      result
    end
    
    def remove_global_handler(handler_id)
      result = false
      
      # Try instance registry first
      if @instance_event_registry
        result = @instance_event_registry.remove_global_handler(handler_id) || result
      end
      
      # Try cross-object registry
      if @cross_object_event_registry
        result = @cross_object_event_registry.remove_global_handler(handler_id) || result
      end
      
      result
    end
    
    # Get event history for this object
    def event_history(limit = nil)
      return [] unless @instance_event_registry
      @instance_event_registry.event_history(limit)
    end
    
    # Get events of specific type for this object
    def events_of_type(event_type, limit = nil)
      return [] unless @instance_event_registry
      @instance_event_registry.events_of_type(event_type, limit)
    end
  end
  
  # Message passing system built on top of events
  class MessageBus
    include EventCapable
    
    def initialize
      initialize_event_system
      @message_queue = []
      @processing = false
    end
    
    # Send a message through the bus
    def send_message(from_object, to_object, message_type, payload = {})
      message = {
        id: generate_message_id,
        from: from_object,
        to: to_object,
        type: message_type,
        payload: payload,
        timestamp: Time.now,
        status: :pending
      }
      
      @message_queue << message
      fire_event(:message_queued, message)
      
      # Process immediately if not already processing
      process_messages unless @processing
      
      message[:id]
    end
    
    # Process all queued messages
    def process_messages
      return if @processing
      @processing = true
      
      begin
        while message = @message_queue.shift
          process_single_message(message)
        end
      ensure
        @processing = false
      end
    end
    
    # Get message queue status
    def queue_status
      {
        pending_messages: @message_queue.size,
        processing: @processing
      }
    end
    
    private
    
    def process_single_message(message)
      begin
        message[:status] = :processing
        fire_event(:message_processing, message)
        
        # Deliver message to target object
        if message[:to].respond_to?(:receive_message)
          message[:to].receive_message(message)
          message[:status] = :delivered
          fire_event(:message_delivered, message)
        else
          message[:status] = :failed
          message[:error] = "Target object does not support message receiving"
          fire_event(:message_failed, message)
        end
      rescue => e
        message[:status] = :failed
        message[:error] = e.message
        fire_event(:message_failed, message)
      end
    end
    
    def generate_message_id
      @message_id_counter ||= 0
      @message_id_counter += 1
      "msg_#{@message_id_counter}"
    end
  end
  
  # Global message bus instance
  def self.message_bus
    @message_bus ||= MessageBus.new
  end
  
  # Convenience method for global message sending
  def self.send_message(from_object, to_object, message_type, payload = {})
    message_bus.send_message(from_object, to_object, message_type, payload)
  end
  
  # Global event registry for system-wide events
  def self.global_registry
    @global_registry ||= EventRegistry.new
  end
  
  # Global subscribe method for testing and system-wide event handling
  def self.subscribe(event_type, &block)
    global_registry.register_handler(event_type, block)
  end
  
  # Global fire event method
  def self.fire_global_event(event_type, event_data = {})
    global_registry.fire_event(event_type, event_data)
  end
  
  # Clear global event handlers (useful for testing)
  def self.clear_global_handlers
    @global_registry = EventRegistry.new
  end
end