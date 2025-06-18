require_relative 'event_system'

# PatlangObject - Universal base class for all language elements in Patlang
# 
# This class implements the core "everything is an object" philosophy where
# numbers, strings, functions, and all other language elements are objects
# with lifecycle management, event capabilities, and message passing.
class PatlangObject
  include EventSystem::EventCapable
  
  # Class-level object registry for tracking all objects
  @@object_registry = {}
  @@next_object_id = 1
  
  attr_reader :object_id, :object_type, :raw_value, :metadata
  
  def initialize(value, type = nil)
    @object_id = generate_object_id
    @raw_value = value
    @object_type = type || infer_type(value)
    @metadata = {}
    @created_at = Time.now
    @modified_at = @created_at
    
    # Register this object
    @@object_registry[@object_id] = self
    
    # Fire creation event
    creation_event_data = {
      object_id: @object_id,
      type: @object_type,
      value: @raw_value,
      timestamp: @created_at
    }
    fire_event(:object_created, creation_event_data)
    EventSystem.fire_global_event(:object_created, creation_event_data)
  end
  
  # Get the actual value, providing seamless integration with existing code
  def value
    @raw_value
  end
  
  # Set a new value, firing change events
  def value=(new_value)
    old_value = @raw_value
    old_type = @object_type
    
    @raw_value = new_value
    @object_type = infer_type(new_value)
    @modified_at = Time.now
    
    # Fire value change event
    fire_event(:value_changed, {
      object_id: @object_id,
      old_value: old_value,
      new_value: @raw_value,
      old_type: old_type,
      new_type: @object_type,
      timestamp: @modified_at
    })
  end
  
  # Message passing between objects
  def send_message(target_object, message_type, payload = {})
    unless target_object.is_a?(PatlangObject)
      raise ArgumentError, "Target must be a PatlangObject"
    end
    
    message = {
      from: @object_id,
      to: target_object.object_id,
      type: message_type,
      payload: payload,
      timestamp: Time.now
    }
    
    # Fire message sent event on sender
    fire_event(:message_sent, message)
    
    # Deliver message to target
    target_object.receive_message(message)
    
    message
  end
  
  # Receive and process messages from other objects
  def receive_message(message)
    # Fire message received event
    fire_event(:message_received, message)
    
    # Default message processing (can be overridden by subclasses)
    process_message(message)
  end
  
  # Metadata management for extensibility
  def set_metadata(key, value)
    old_value = @metadata[key]
    @metadata[key] = value
    @modified_at = Time.now
    
    fire_event(:metadata_changed, {
      object_id: @object_id,
      key: key,
      old_value: old_value,
      new_value: value,
      timestamp: @modified_at
    })
  end
  
  def get_metadata(key)
    @metadata[key]
  end
  
  # Alias for set_metadata to maintain compatibility
  def set_attribute(key, value)
    set_metadata(key, value)
  end
  
  # Type checking and conversion
  def is_type?(type)
    @object_type == type
  end
  
  def to_number
    case @object_type
    when :number
      @raw_value
    when :string
      begin
        Float(@raw_value)
      rescue ArgumentError
        raise "Cannot convert string '#{@raw_value}' to number"
      end
    when :boolean
      @raw_value ? 1.0 : 0.0
    else
      raise "Cannot convert #{@object_type} to number"
    end
  end
  
  def to_string
    case @object_type
    when :string
      @raw_value
    when :number
      @raw_value.to_s
    when :boolean
      @raw_value.to_s
    when :nil
      ""
    else
      @raw_value.to_s
    end
  end
  
  def to_boolean
    case @object_type
    when :boolean
      @raw_value
    when :nil
      false
    when :number
      @raw_value != 0
    when :string
      !@raw_value.empty?
    else
      true
    end
  end
  
  # Object lifecycle management
  def destroy
    # Fire destruction event
    fire_event(:object_destroyed, {
      object_id: @object_id,
      type: @object_type,
      final_value: @raw_value,
      timestamp: Time.now
    })
    
    # Remove from registry
    @@object_registry.delete(@object_id)
    
    # Clean up event subscriptions
    clear_all_subscriptions
  end
  
  # Class methods for object management
  def self.find_object(object_id)
    @@object_registry[object_id]
  end
  
  def self.all_objects
    @@object_registry.values
  end
  
  def self.objects_of_type(type)
    @@object_registry.values.select { |obj| obj.object_type == type }
  end
  
  def self.object_count
    @@object_registry.size
  end
  
  def self.clear_registry
    @@object_registry.clear
    @@next_object_id = 1
  end
  
  # Factory methods for creating typed objects
  def self.create_number(value)
    # Preserve original numeric type (Integer vs Float) for proper type inference
    numeric_value = value.is_a?(Numeric) ? value : value.to_f
    new(numeric_value, :number)
  end
  
  def self.create_string(value)
    new(value.to_s, :string)
  end
  
  def self.create_boolean(value)
    new(!!value, :boolean)
  end
  
  def self.create_nil
    new(nil, :nil)
  end
  
  # Wrap existing Ruby values in PatlangObjects
  def self.wrap(value)
    case value
    when PatlangObject
      value  # Already wrapped
    when Numeric
      create_number(value)
    when String
      create_string(value)
    when TrueClass, FalseClass
      create_boolean(value)
    when NilClass
      create_nil
    else
      new(value, :object)
    end
  end
  
  # String representation
  def to_s
    "PatlangObject(id=#{@object_id}, type=:#{@object_type}, value=#{@raw_value})"
  end
  
  def inspect
    to_s
  end
  
  # Equality comparison
  def ==(other)
    if other.is_a?(PatlangObject)
      @raw_value == other.raw_value
    else
      @raw_value == other
    end
  end
  
  private
  
  def generate_object_id
    id = @@next_object_id
    @@next_object_id += 1
    id
  end
  
  def infer_type(value)
    case value
    when Numeric
      :number
    when String
      :string
    when TrueClass, FalseClass
      :boolean
    when NilClass
      :nil
    else
      :object
    end
  end
  
  # Default message processing (can be overridden)
  def process_message(message)
    # Default: log the message (in a real implementation, this might do more)
    case message[:type]
    when :ping
      # Respond to ping with pong
      sender = self.class.find_object(message[:from])
      if sender
        sender.receive_message({
          from: @object_id,
          to: message[:from],
          type: :pong,
          payload: { original_message: message },
          timestamp: Time.now
        })
      end
    else
      # Default: do nothing for unknown message types
    end
  end
  
  public
  
  # Convert to string for concatenation - returns just the value as string
  def to_string
    case @object_type
    when :string
      @raw_value
    when :number
      @raw_value.to_s
    when :boolean
      @raw_value.to_s
    when :nil
      ""
    else
      @raw_value.to_s
    end
  end
  
  # Class methods for finding objects
  def self.find_object(object_id)
    @@object_registry[object_id]
  end
  
  # Add merge method for Hash compatibility
  def merge(other)
    return self unless other.respond_to?(:each) || other.is_a?(Hash)
    
    # If other is a hash, merge into our attributes
    if other.is_a?(Hash)
      other.each do |key, value|
        if self.respond_to?("#{key}=")
          self.send("#{key}=", value)
        elsif self.respond_to?(:set_attribute)
          self.set_attribute(key, value)
        end
      end
    end
    
    self
  end
  
  # Add + operator for string concatenation compatibility
  def +(other)
    if self.respond_to?(:value) && other.respond_to?(:value)
      self.class.new(self.value.to_s + other.value.to_s)
    elsif self.respond_to?(:value)
      self.class.new(self.value.to_s + other.to_s)
    else
      self.to_s + other.to_s
    end
  end
end