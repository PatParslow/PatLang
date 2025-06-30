#!/usr/bin/env ruby

# =============================================================================
# 🎓 PATLANG OBJECT-ORIENTED EVENT SYSTEM TUTORIAL
# =============================================================================
#
# Interactive step-by-step tutorial for learning Patlang's revolutionary 
# object model and event system. This tutorial progressively builds 
# understanding from basic concepts to advanced patterns.
#
# 🎯 LEARNING OBJECTIVES:
# - Understand the "everything is objects" philosophy
# - Master event-driven reactive programming patterns
# - Learn message passing between objects
# - Apply concepts to real-world scenarios
# - Explore performance and scalability features
#
# =============================================================================

require_relative '../src/object_model/patlang_object'
require_relative '../src/object_model/event_system'
require_relative '../src/object_model/object_integration'

class OOEventTutorial
  def initialize
    @current_lesson = 0
    @completed_lessons = []
    @user_objects = []
    setup_tutorial_environment
  end
  
  def start_tutorial
    puts "🎓 Welcome to the Patlang Object-Oriented Event System Tutorial!"
    puts "=" * 65
    puts ""
    puts "This interactive tutorial will teach you Patlang's revolutionary"
    puts "'everything is objects' philosophy and built-in event system."
    puts ""
    puts "📚 Tutorial Structure:"
    puts "  1. Object Basics & Lifecycle Events"
    puts "  2. Custom Event Handlers"
    puts "  3. Reactive Programming Patterns"
    puts "  4. Message Passing Between Objects"
    puts "  5. Real-World Banking Example"
    puts "  6. Performance & Advanced Patterns"
    puts ""
    
    interactive_mode_menu
  end
  
  private
  
  def setup_tutorial_environment
    # Set up global event monitoring for educational purposes
    @event_log = []
    
    PatlangObject.on_all_events do |event|
      @event_log << {
        type: event[:type],
        data: event[:data],
        timestamp: Time.now
      }
    end
  end
  
  def interactive_mode_menu
    loop do
      puts "\n🎯 TUTORIAL MENU"
      puts "-" * 30
      puts "1. Start Lesson 1: Object Basics"
      puts "2. Start Lesson 2: Event Handlers"
      puts "3. Start Lesson 3: Reactive Programming"
      puts "4. Start Lesson 4: Message Passing"
      puts "5. Start Lesson 5: Banking Example"
      puts "6. Start Lesson 6: Advanced Patterns"
      puts "7. Review Event Log"
      puts "8. Clean Up Objects"
      puts "9. Exit Tutorial"
      puts ""
      print "Choose a lesson (1-9): "
      
      choice = gets.chomp
      
      case choice
      when "1"
        lesson_1_object_basics
      when "2"
        lesson_2_event_handlers
      when "3"
        lesson_3_reactive_programming
      when "4"
        lesson_4_message_passing
      when "5"
        lesson_5_banking_example
      when "6"
        lesson_6_advanced_patterns
      when "7"
        review_event_log
      when "8"
        cleanup_objects
      when "9"
        puts "👋 Thank you for completing the tutorial!"
        break
      else
        puts "❌ Invalid choice. Please select 1-9."
      end
    end
  end
  
  # ==========================================================================
  # LESSON 1: OBJECT BASICS & LIFECYCLE EVENTS
  # ==========================================================================
  
  def lesson_1_object_basics
    lesson_header(1, "Object Basics & Lifecycle Events")
    
    puts "📖 LESSON OVERVIEW:"
    puts "In Patlang, EVERYTHING is an object - numbers, strings, booleans."
    puts "Every object automatically has:"
    puts "  • Unique identity and lifecycle management"
    puts "  • Built-in event capabilities"
    puts "  • Automatic event firing for creation and modification"
    puts ""
    
    step_pause("Ready to create your first objects?")
    
    puts "🔹 STEP 1: Creating Objects"
    puts "Let's create some basic objects and observe their automatic events:"
    puts ""
    
    clear_event_log
    
    puts ">>> person_name = PatlangObject.create_string('Alice')"
    person_name = PatlangObject.create_string("Alice")
    @user_objects << person_name
    
    puts ">>> person_age = PatlangObject.create_number(25)"
    person_age = PatlangObject.create_number(25)
    @user_objects << person_age
    
    puts ">>> is_active = PatlangObject.create_boolean(true)"
    is_active = PatlangObject.create_boolean(true)
    @user_objects << is_active
    
    puts ""
    puts "✨ Notice how each object creation automatically fired an 'object_created' event!"
    puts "   Each object received a unique ID and type classification."
    puts ""
    
    step_pause("Ready to see object properties?")
    
    puts "🔹 STEP 2: Object Properties & Inspection"
    puts "Every object has built-in properties you can inspect:"
    puts ""
    
    puts ">>> person_name.object_id"
    puts "   #{person_name.object_id}"
    puts ">>> person_name.object_type"
    puts "   #{person_name.object_type}"
    puts ">>> person_name.value"
    puts "   #{person_name.value}"
    puts ""
    
    puts "📊 Global object registry statistics:"
    puts "   Total objects: #{PatlangObject.object_count}"
    puts "   String objects: #{PatlangObject.objects_of_type(:string).length}"
    puts "   Number objects: #{PatlangObject.objects_of_type(:number).length}"
    puts "   Boolean objects: #{PatlangObject.objects_of_type(:boolean).length}"
    puts ""
    
    step_pause("Ready to modify values and see change events?")
    
    puts "🔹 STEP 3: Value Changes & Automatic Events"
    puts "When you change an object's value, it automatically fires events:"
    puts ""
    
    clear_event_log
    
    puts ">>> person_name.value = 'Bob'"
    person_name.value = "Bob"
    
    puts ">>> person_age.value = 30"
    person_age.value = 30
    
    puts ">>> is_active.value = false"
    is_active.value = false
    
    puts ""
    puts "✨ Each value change automatically fired a 'value_changed' event with:"
    puts "   • Old value and new value"
    puts "   • Timestamp of the change"
    puts "   • Object identity information"
    puts ""
    
    step_pause("Ready to explore metadata?")
    
    puts "🔹 STEP 4: Metadata & Object Extension"
    puts "Objects can store additional metadata for flexibility:"
    puts ""
    
    puts ">>> person_name.set_metadata(:full_name, 'Bob Smith')"
    person_name.set_metadata(:full_name, "Bob Smith")
    
    puts ">>> person_name.set_metadata(:title, 'Dr.')"
    person_name.set_metadata(:title, "Dr.")
    
    puts ">>> person_age.set_metadata(:birth_year, 1994)"
    person_age.set_metadata(:birth_year, 1994)
    
    puts ""
    puts ">>> person_name.get_metadata(:full_name)"
    puts "   #{person_name.get_metadata(:full_name)}"
    puts ""
    
    puts "✨ Metadata changes also fire events automatically!"
    puts ""
    
    lesson_complete(1)
  end
  
  # ==========================================================================
  # LESSON 2: CUSTOM EVENT HANDLERS
  # ==========================================================================
  
  def lesson_2_event_handlers
    lesson_header(2, "Custom Event Handlers")
    
    puts "📖 LESSON OVERVIEW:"
    puts "Learn to register custom event handlers that respond to object changes."
    puts "This is the foundation of reactive programming in Patlang."
    puts ""
    
    step_pause("Ready to create objects with custom event handlers?")
    
    puts "🔹 STEP 1: Registering Event Handlers"
    puts "Let's create a temperature sensor with custom event handlers:"
    puts ""
    
    clear_event_log
    
    puts ">>> temperature = PatlangObject.create_number(20.0)"
    temperature = PatlangObject.create_number(20.0)
    @user_objects << temperature
    
    puts ""
    puts "Now let's register a custom handler for temperature changes:"
    puts ""
    
    puts ">>> temperature.on_event(:value_changed) do |event|"
    puts "      temp = event[:data][:new_value]"
    puts "      if temp > 25"
    puts "        puts '🔥 Temperature is getting hot: #{temp}°C'"
    puts "      elsif temp < 10"
    puts "        puts '🧊 Temperature is getting cold: #{temp}°C'"
    puts "      else"
    puts "        puts '🌡️ Temperature is normal: #{temp}°C'"
    puts "      end"
    puts "    end"
    
    temperature.on_event(:value_changed) do |event|
      temp = event[:data][:new_value]
      if temp > 25
        puts "    🔥 Temperature is getting hot: #{temp}°C"
      elsif temp < 10
        puts "    🧊 Temperature is getting cold: #{temp}°C"
      else
        puts "    🌡️ Temperature is normal: #{temp}°C"
      end
    end
    
    puts ""
    step_pause("Ready to test the event handler?")
    
    puts "🔹 STEP 2: Testing Event Handlers"
    puts "Let's change the temperature and see our custom handler in action:"
    puts ""
    
    test_temperatures = [30.0, 5.0, 15.0, 35.0]
    test_temperatures.each do |temp|
      puts ">>> temperature.value = #{temp}"
      temperature.value = temp
      puts ""
    end
    
    step_pause("Ready to learn about multiple event handlers?")
    
    puts "🔹 STEP 3: Multiple Event Handlers"
    puts "Objects can have multiple event handlers for the same event:"
    puts ""
    
    puts ">>> temperature.on_event(:value_changed) do |event|"
    puts "      # Second handler - logging"
    puts "      puts '📊 LOG: Temperature changed to #{event[:data][:new_value]}°C at #{event[:data][:timestamp]}'"
    puts "    end"
    
    temperature.on_event(:value_changed) do |event|
      puts "    📊 LOG: Temperature changed to #{event[:data][:new_value]}°C at #{event[:data][:timestamp].strftime('%H:%M:%S')}"
    end
    
    puts ""
    puts ">>> temperature.on_event(:value_changed) do |event|"
    puts "      # Third handler - alerts"
    puts "      if event[:data][:new_value] > 40"
    puts "        puts '🚨 CRITICAL ALERT: Overheating detected!'"
    puts "      end"
    puts "    end"
    
    temperature.on_event(:value_changed) do |event|
      if event[:data][:new_value] > 40
        puts "    🚨 CRITICAL ALERT: Overheating detected!"
      end
    end
    
    puts ""
    puts "Now when we change temperature, ALL handlers will execute:"
    puts ""
    
    puts ">>> temperature.value = 45.0"
    temperature.value = 45.0
    
    puts ""
    puts "✨ Notice how all three handlers executed in order!"
    puts ""
    
    step_pause("Ready to learn about metadata event handlers?")
    
    puts "🔹 STEP 4: Metadata Event Handlers"
    puts "You can also handle metadata changes:"
    puts ""
    
    puts ">>> temperature.on_event(:metadata_changed) do |event|"
    puts "      key = event[:data][:key]"
    puts "      value = event[:data][:new_value]"
    puts "      puts '🏷️ Metadata updated: #{key} = #{value}'"
    puts "    end"
    
    temperature.on_event(:metadata_changed) do |event|
      key = event[:data][:key]
      value = event[:data][:new_value]
      puts "    🏷️ Metadata updated: #{key} = #{value}"
    end
    
    puts ""
    puts ">>> temperature.set_metadata(:location, 'Living Room')"
    temperature.set_metadata(:location, "Living Room")
    
    puts ">>> temperature.set_metadata(:sensor_id, 'TEMP-001')"
    temperature.set_metadata(:sensor_id, "TEMP-001")
    
    puts ""
    lesson_complete(2)
  end
  
  # ==========================================================================
  # LESSON 3: REACTIVE PROGRAMMING PATTERNS
  # ==========================================================================
  
  def lesson_3_reactive_programming
    lesson_header(3, "Reactive Programming Patterns")
    
    puts "📖 LESSON OVERVIEW:"
    puts "Learn how objects can automatically react to changes in other objects,"
    puts "creating powerful reactive programming patterns without any frameworks."
    puts ""
    
    step_pause("Ready to build a reactive data pipeline?")
    
    puts "🔹 STEP 1: Creating a Reactive Chain"
    puts "Let's build a temperature monitoring system with automatic reactions:"
    puts ""
    
    clear_event_log
    
    # Create the reactive objects
    puts ">>> celsius_sensor = PatlangObject.create_number(20.0)"
    celsius_sensor = PatlangObject.create_number(20.0)
    @user_objects << celsius_sensor
    
    puts ">>> fahrenheit_display = PatlangObject.create_number(0.0)"
    fahrenheit_display = PatlangObject.create_number(0.0)
    @user_objects << fahrenheit_display
    
    puts ">>> status_indicator = PatlangObject.create_string('Unknown')"
    status_indicator = PatlangObject.create_string("Unknown")
    @user_objects << status_indicator
    
    puts ">>> alert_system = PatlangObject.create_boolean(false)"
    alert_system = PatlangObject.create_boolean(false)
    @user_objects << alert_system
    
    puts ""
    step_pause("Ready to connect them reactively?")
    
    puts "🔹 STEP 2: Setting Up Reactive Connections"
    puts "Now let's connect these objects so they automatically react to each other:"
    puts ""
    
    puts ">>> # When Celsius changes, update Fahrenheit display"
    puts ">>> celsius_sensor.on_event(:value_changed) do |event|"
    puts "      celsius = event[:data][:new_value]"
    puts "      fahrenheit = (celsius * 9.0 / 5.0) + 32.0"
    puts "      fahrenheit_display.value = fahrenheit"
    puts "      puts '🌡️ Converted: #{celsius}°C → #{fahrenheit.round(1)}°F'"
    puts "    end"
    
    celsius_sensor.on_event(:value_changed) do |event|
      celsius = event[:data][:new_value]
      fahrenheit = (celsius * 9.0 / 5.0) + 32.0
      fahrenheit_display.value = fahrenheit
      puts "    🌡️ Converted: #{celsius}°C → #{fahrenheit.round(1)}°F"
    end
    
    puts ""
    puts ">>> # When Fahrenheit changes, update status"
    puts ">>> fahrenheit_display.on_event(:value_changed) do |event|"
    puts "      temp_f = event[:data][:new_value]"
    puts "      status = case temp_f"
    puts "               when 0..32 then 'Freezing'"
    puts "               when 32..60 then 'Cold'"
    puts "               when 60..80 then 'Comfortable'"
    puts "               when 80..100 then 'Hot'"
    puts "               else 'Extreme'"
    puts "               end"
    puts "      status_indicator.value = status"
    puts "      puts '📊 Status updated: #{status}'"
    puts "    end"
    
    fahrenheit_display.on_event(:value_changed) do |event|
      temp_f = event[:data][:new_value]
      status = case temp_f
               when 0..32 then "Freezing"
               when 32..60 then "Cold" 
               when 60..80 then "Comfortable"
               when 80..100 then "Hot"
               else "Extreme"
               end
      status_indicator.value = status
      puts "    📊 Status updated: #{status}"
    end
    
    puts ""
    puts ">>> # When status changes, update alerts"
    puts ">>> status_indicator.on_event(:value_changed) do |event|"
    puts "      status = event[:data][:new_value]"
    puts "      should_alert = ['Freezing', 'Extreme'].include?(status)"
    puts "      alert_system.value = should_alert"
    puts "      puts should_alert ? '🚨 ALERT ACTIVE' : '✅ ALERT CLEARED'"
    puts "    end"
    
    status_indicator.on_event(:value_changed) do |event|
      status = event[:data][:new_value]
      should_alert = ["Freezing", "Extreme"].include?(status)
      alert_system.value = should_alert
      puts should_alert ? "    🚨 ALERT ACTIVE" : "    ✅ ALERT CLEARED"
    end
    
    puts ""
    step_pause("Ready to test the reactive chain?")
    
    puts "🔹 STEP 3: Testing the Reactive Pipeline"
    puts "Watch how changing the sensor triggers a cascade of automatic reactions:"
    puts ""
    
    test_temps = [0.0, 25.0, 40.0, -10.0, 15.0]
    test_temps.each do |temp|
      puts "🔄 Setting sensor to #{temp}°C..."
      celsius_sensor.value = temp
      puts "   Final state: #{fahrenheit_display.value.round(1)}°F, #{status_indicator.value}, Alert: #{alert_system.value}"
      puts ""
      sleep(0.5)
    end
    
    puts "✨ Each temperature change triggered a complete reactive cascade!"
    puts "   Celsius → Fahrenheit → Status → Alert"
    puts ""
    
    step_pause("Ready to learn about reactive collections?")
    
    puts "🔹 STEP 4: Reactive Collections & Aggregation"
    puts "Let's create multiple sensors that feed into an aggregator:"
    puts ""
    
    # Create multiple sensors
    sensors = []
    3.times do |i|
      sensor = PatlangObject.create_number(20.0 + i * 5)
      sensor.set_metadata(:sensor_id, "SENSOR-#{i+1}")
      sensors << sensor
      @user_objects << sensor
    end
    
    puts ">>> # Created 3 sensors with IDs: #{sensors.map { |s| s.get_metadata(:sensor_id) }.join(', ')}"
    
    average_calculator = PatlangObject.create_number(0.0)
    @user_objects << average_calculator
    
    puts ">>> average_calculator = PatlangObject.create_number(0.0)"
    puts ""
    
    # Set up reactive averaging
    sensors.each do |sensor|
      sensor.on_event(:value_changed) do |event|
        sensor_id = sensor.get_metadata(:sensor_id)
        puts "    📡 #{sensor_id} changed to #{event[:data][:new_value]}°C"
        
        # Recalculate average
        total = sensors.map(&:value).sum
        average = total / sensors.length
        average_calculator.value = average
        puts "    📊 New average: #{average.round(2)}°C"
      end
    end
    
    puts "Set up reactive averaging - when ANY sensor changes, average updates automatically."
    puts ""
    
    puts "Testing with some sensor changes:"
    puts ""
    
    # Test the reactive averaging
    sensors[0].value = 30.0
    sensors[1].value = 15.0
    sensors[2].value = 25.0
    
    puts ""
    lesson_complete(3)
  end
  
  # ==========================================================================
  # LESSON 4: MESSAGE PASSING BETWEEN OBJECTS
  # ==========================================================================
  
  def lesson_4_message_passing
    lesson_header(4, "Message Passing Between Objects")
    
    puts "📖 LESSON OVERVIEW:"
    puts "Learn how objects can communicate through messages, enabling"
    puts "asynchronous communication and complex interaction patterns."
    puts ""
    
    step_pause("Ready to create communicating objects?")
    
    puts "🔹 STEP 1: Basic Message Sending"
    puts "Let's create two objects that can send messages to each other:"
    puts ""
    
    clear_event_log
    
    puts ">>> alice = PatlangObject.create_string('Alice ready')"
    alice = PatlangObject.create_string("Alice ready")
    @user_objects << alice
    
    puts ">>> bob = PatlangObject.create_string('Bob ready')"
    bob = PatlangObject.create_string("Bob ready")
    @user_objects << bob
    
    puts ""
    puts ">>> # Alice sends a greeting to Bob"
    puts ">>> alice.send_message(bob, 'greeting', { text: 'Hello Bob!' })"
    alice.send_message(bob, "greeting", { text: "Hello Bob!" })
    
    puts ""
    puts "✨ Notice the automatic message events:"
    puts "   • 'message_sent' event fired on Alice"
    puts "   • 'message_received' event fired on Bob"
    puts ""
    
    step_pause("Ready to set up message handlers?")
    
    puts "🔹 STEP 2: Message Handlers"
    puts "Let's set up handlers so objects can respond to messages:"
    puts ""
    
    puts ">>> # Bob handles greeting messages"
    puts ">>> bob.on_event(:message_received) do |event|"
    puts "      message = event[:data]"
    puts "      if message[:type] == 'greeting'"
    puts "        text = message[:payload][:text]"
    puts "        puts '👋 Bob received greeting: #{text}'"
    puts "        # Bob responds"
    puts "        sender = PatlangObject.find_object(message[:from])"
    puts "        bob.send_message(sender, 'response', { text: 'Hello Alice!' })"
    puts "      end"
    puts "    end"
    
    bob.on_event(:message_received) do |event|
      message = event[:data]
      if message[:type] == "greeting"
        text = message[:payload][:text]
        puts "    👋 Bob received greeting: #{text}"
        # Bob responds
        sender = PatlangObject.find_object(message[:from])
        if sender
          bob.send_message(sender, "response", { text: "Hello Alice!" })
        end
      end
    end
    
    puts ""
    puts ">>> # Alice handles response messages"
    puts ">>> alice.on_event(:message_received) do |event|"
    puts "      message = event[:data]"
    puts "      if message[:type] == 'response'"
    puts "        text = message[:payload][:text]"
    puts "        puts '😊 Alice received response: #{text}'"
    puts "      end"
    puts "    end"
    
    alice.on_event(:message_received) do |event|
      message = event[:data]
      if message[:type] == "response"
        text = message[:payload][:text]
        puts "    😊 Alice received response: #{text}"
      end
    end
    
    puts ""
    puts "Now let's trigger the conversation:"
    puts ""
    
    puts ">>> alice.send_message(bob, 'greeting', { text: 'Hello Bob, how are you?' })"
    alice.send_message(bob, "greeting", { text: "Hello Bob, how are you?" })
    
    puts ""
    step_pause("Ready to build a more complex message system?")
    
    puts "🔹 STEP 3: Request-Response Pattern"
    puts "Let's build a calculator service that responds to calculation requests:"
    puts ""
    
    puts ">>> calculator_service = PatlangObject.create_string('Calculator Service')"
    calculator_service = PatlangObject.create_string("Calculator Service")
    @user_objects << calculator_service
    
    puts ">>> client = PatlangObject.create_string('Calculator Client')"
    client = PatlangObject.create_string("Calculator Client")
    @user_objects << client
    
    puts ""
    puts ">>> # Calculator service handles calculation requests"
    puts ">>> calculator_service.on_event(:message_received) do |event|"
    puts "      message = event[:data]"
    puts "      if message[:type] == 'calculate'"
    puts "        operation = message[:payload][:operation]"
    puts "        a = message[:payload][:a]"
    puts "        b = message[:payload][:b]"
    puts "        result = case operation"
    puts "                 when 'add' then a + b"
    puts "                 when 'multiply' then a * b"
    puts "                 when 'divide' then b != 0 ? a / b : 'Error: Division by zero'"
    puts "                 else 'Error: Unknown operation'"
    puts "                 end"
    puts "        puts '🧮 Calculator: #{a} #{operation} #{b} = #{result}'"
    puts "        sender = PatlangObject.find_object(message[:from])"
    puts "        calculator_service.send_message(sender, 'result', { result: result })"
    puts "      end"
    puts "    end"
    
    calculator_service.on_event(:message_received) do |event|
      message = event[:data]
      if message[:type] == "calculate"
        operation = message[:payload][:operation]
        a = message[:payload][:a]
        b = message[:payload][:b]
        
        result = case operation
                 when "add" then a + b
                 when "multiply" then a * b
                 when "divide" then b != 0 ? a.to_f / b : "Error: Division by zero"
                 else "Error: Unknown operation"
                 end
        
        puts "    🧮 Calculator: #{a} #{operation} #{b} = #{result}"
        
        sender = PatlangObject.find_object(message[:from])
        if sender
          calculator_service.send_message(sender, "result", { result: result })
        end
      end
    end
    
    puts ""
    puts ">>> # Client handles calculation results"
    puts ">>> client.on_event(:message_received) do |event|"
    puts "      message = event[:data]"
    puts "      if message[:type] == 'result'"
    puts "        result = message[:payload][:result]"
    puts "        puts '📱 Client received result: #{result}'"
    puts "      end"
    puts "    end"
    
    client.on_event(:message_received) do |event|
      message = event[:data]
      if message[:type] == "result"
        result = message[:payload][:result]
        puts "    📱 Client received result: #{result}"
      end
    end
    
    puts ""
    puts "Let's test the calculator service:"
    puts ""
    
    calculations = [
      { operation: "add", a: 10, b: 5 },
      { operation: "multiply", a: 7, b: 8 },
      { operation: "divide", a: 20, b: 4 },
      { operation: "divide", a: 10, b: 0 }  # Error case
    ]
    
    calculations.each do |calc|
      puts ">>> client.send_message(calculator_service, 'calculate', #{calc})"
      client.send_message(calculator_service, "calculate", calc)
      puts ""
    end
    
    step_pause("Ready to learn about broadcast messaging?")
    
    puts "🔹 STEP 4: Broadcast Messaging"
    puts "Let's create a notification system that broadcasts to multiple subscribers:"
    puts ""
    
    puts ">>> notification_center = PatlangObject.create_string('Notification Center')"
    notification_center = PatlangObject.create_string("Notification Center")
    @user_objects << notification_center
    
    # Create multiple subscribers
    subscribers = []
    ["Email Service", "SMS Service", "Push Notification"].each_with_index do |name, index|
      subscriber = PatlangObject.create_string(name)
      subscriber.set_metadata(:subscriber_id, index + 1)
      subscribers << subscriber
      @user_objects << subscriber
      
      # Each subscriber handles notifications
      subscriber.on_event(:message_received) do |event|
        message = event[:data]
        if message[:type] == "notification"
          service_name = subscriber.value
          notification_text = message[:payload][:text]
          puts "    📬 #{service_name}: '#{notification_text}'"
        end
      end
    end
    
    puts ">>> # Created subscribers: #{subscribers.map(&:value).join(', ')}"
    puts ""
    
    puts ">>> # Notification center broadcasts to all subscribers"
    puts ">>> def broadcast_notification(text)"
    puts "      subscribers.each do |subscriber|"
    puts "        notification_center.send_message(subscriber, 'notification', { text: text })"
    puts "      end"
    puts "    end"
    
    def broadcast_notification(text, notification_center, subscribers)
      puts "    📢 Broadcasting: '#{text}'"
      subscribers.each do |subscriber|
        notification_center.send_message(subscriber, "notification", { text: text })
      end
    end
    
    puts ""
    puts "Let's test broadcasting:"
    puts ""
    
    notifications = [
      "System maintenance in 30 minutes",
      "New feature released: Object Events!",
      "Security update available"
    ]
    
    notifications.each do |notification|
      puts ">>> Broadcasting: '#{notification}'"
      broadcast_notification(notification, notification_center, subscribers)
      puts ""
    end
    
    lesson_complete(4)
  end
  
  # ==========================================================================
  # LESSON 5: REAL-WORLD BANKING EXAMPLE
  # ==========================================================================
  
  def lesson_5_banking_example
    lesson_header(5, "Real-World Banking System")
    
    puts "📖 LESSON OVERVIEW:"
    puts "Apply everything you've learned to build a complete banking system"
    puts "with accounts, transactions, fraud detection, and audit logging."
    puts ""
    
    step_pause("Ready to build a banking system?")
    
    puts "🔹 STEP 1: Creating Bank Accounts"
    puts "Let's create bank accounts with metadata and event tracking:"
    puts ""
    
    clear_event_log
    
    puts ">>> checking_account = PatlangObject.create_number(1000.0)"
    checking_account = PatlangObject.create_number(1000.0)
    checking_account.set_metadata(:account_type, "checking")
    checking_account.set_metadata(:account_number, "CHK-12345")
    checking_account.set_metadata(:owner, "John Doe")
    @user_objects << checking_account
    
    puts ">>> savings_account = PatlangObject.create_number(5000.0)"
    savings_account = PatlangObject.create_number(5000.0)
    savings_account.set_metadata(:account_type, "savings")
    savings_account.set_metadata(:account_number, "SAV-12345")
    savings_account.set_metadata(:owner, "John Doe")
    @user_objects << savings_account
    
    puts ""
    puts "Account details:"
    puts "  Checking: $#{checking_account.value} (#{checking_account.get_metadata(:account_number)})"
    puts "  Savings: $#{savings_account.value} (#{savings_account.get_metadata(:account_number)})"
    puts ""
    
    step_pause("Ready to create banking services?")
    
    puts "🔹 STEP 2: Banking Services"
    puts "Let's create audit logging and fraud detection services:"
    puts ""
    
    puts ">>> audit_logger = PatlangObject.create_string('Audit Service Active')"
    audit_logger = PatlangObject.create_string("Audit Service Active")
    @user_objects << audit_logger
    
    puts ">>> fraud_detector = PatlangObject.create_string('Fraud Detection Active')"
    fraud_detector = PatlangObject.create_string("Fraud Detection Active")
    @user_objects << fraud_detector
    
    puts ">>> notification_service = PatlangObject.create_string('Notification Service Active')"
    notification_service = PatlangObject.create_string("Notification Service Active")
    @user_objects << notification_service
    
    puts ""
    step_pause("Ready to set up transaction monitoring?")
    
    puts "🔹 STEP 3: Transaction Event Handling"
    puts "Set up automatic monitoring for all account transactions:"
    puts ""
    
    # Set up transaction monitoring for all accounts
    [checking_account, savings_account].each do |account|
      account.on_event(:value_changed) do |event|
        old_balance = event[:data][:old_value]
        new_balance = event[:data][:new_value]
        transaction_amount = new_balance - old_balance
        account_number = account.get_metadata(:account_number)
        timestamp = event[:data][:timestamp]
        
        transaction_data = {
          account_number: account_number,
          old_balance: old_balance,
          new_balance: new_balance,
          amount: transaction_amount,
          timestamp: timestamp
        }
        
        # Send to audit logger
        audit_logger.send_message(audit_logger, "log_transaction", transaction_data)
        
        # Check for suspicious activity
        if transaction_amount.abs > 500.0
          fraud_detector.send_message(fraud_detector, "check_transaction", transaction_data)
        end
        
        # Send notification
        notification_service.send_message(notification_service, "send_notification", transaction_data)
      end
    end
    
    puts ">>> # Set up transaction monitoring for both accounts"
    puts ">>> # Each transaction will trigger audit, fraud check, and notification"
    puts ""
    
    step_pause("Ready to implement service handlers?")
    
    puts "🔹 STEP 4: Service Implementation"
    puts "Implement the business logic for each banking service:"
    puts ""
    
    # Audit logger implementation
    audit_logger.on_event(:message_received) do |event|
      message = event[:data]
      if message[:type] == "log_transaction"
        data = message[:payload]
        amount_str = data[:amount] >= 0 ? "+$#{data[:amount].round(2)}" : "-$#{data[:amount].abs.round(2)}"
        puts "    📊 AUDIT: #{data[:account_number]} #{amount_str} → Balance: $#{data[:new_balance].round(2)}"
      end
    end
    
    # Fraud detector implementation  
    fraud_detector.on_event(:message_received) do |event|
      message = event[:data]
      if message[:type] == "check_transaction"
        data = message[:payload]
        amount = data[:amount].abs
        
        if amount > 1000.0
          puts "    🚨 FRAUD ALERT: Large transaction $#{amount.round(2)} on #{data[:account_number]}"
        elsif amount > 500.0
          puts "    ⚠️  FRAUD WATCH: Monitoring transaction $#{amount.round(2)} on #{data[:account_number]}"
        end
      end
    end
    
    # Notification service implementation
    notification_service.on_event(:message_received) do |event|
      message = event[:data]
      if message[:type] == "send_notification"
        data = message[:payload]
        if data[:amount] > 0
          puts "    📱 NOTIFICATION: Deposit of $#{data[:amount].round(2)} - New balance: $#{data[:new_balance].round(2)}"
        else
          puts "    📱 NOTIFICATION: Withdrawal of $#{data[:amount].abs.round(2)} - New balance: $#{data[:new_balance].round(2)}"
        end
      end
    end
    
    puts ">>> # Implemented all banking services with message handlers"
    puts ""
    
    step_pause("Ready to simulate banking transactions?")
    
    puts "🔹 STEP 5: Banking Transactions"
    puts "Let's simulate various banking transactions and see the system in action:"
    puts ""
    
    transactions = [
      { account: checking_account, amount: -50.0, description: "ATM Withdrawal" },
      { account: checking_account, amount: 2500.0, description: "Salary Deposit" },
      { account: savings_account, amount: -300.0, description: "Transfer to Checking" },
      { account: checking_account, amount: 300.0, description: "Transfer from Savings" },
      { account: checking_account, amount: -1200.0, description: "Large Purchase (triggers fraud alert)" },
      { account: savings_account, amount: 750.0, description: "Investment Return" }
    ]
    
    transactions.each_with_index do |transaction, index|
      puts "#{index + 1}. #{transaction[:description]}"
      puts "   Amount: #{transaction[:amount] >= 0 ? '+' : ''}$#{transaction[:amount]}"
      
      # Perform transaction
      current_balance = transaction[:account].value
      transaction[:account].value = current_balance + transaction[:amount]
      
      puts ""
      sleep(0.5)
    end
    
    puts "🔹 FINAL BALANCES:"
    puts "  Checking: $#{checking_account.value.round(2)}"
    puts "  Savings: $#{savings_account.value.round(2)}"
    puts "  Total: $#{(checking_account.value + savings_account.value).round(2)}"
    puts ""
    
    puts "✨ BANKING SYSTEM FEATURES DEMONSTRATED:"
    puts "  ✅ Automatic transaction auditing"
    puts "  ✅ Real-time fraud detection"
    puts "  ✅ Customer notifications"
    puts "  ✅ Event-driven architecture"
    puts "  ✅ Seamless service integration"
    puts ""
    
    lesson_complete(5)
  end
  
  # ==========================================================================
  # LESSON 6: ADVANCED PATTERNS & PERFORMANCE
  # ==========================================================================
  
  def lesson_6_advanced_patterns
    lesson_header(6, "Advanced Patterns & Performance")
    
    puts "📖 LESSON OVERVIEW:"
    puts "Explore advanced event patterns, performance characteristics,"
    puts "and sophisticated object interaction patterns."
    puts ""
    
    step_pause("Ready for advanced patterns?")
    
    puts "🔹 STEP 1: Event History & Pattern Detection"
    puts "Learn to analyze event patterns and history:"
    puts ""
    
    clear_event_log
    
    puts ">>> state_machine = PatlangObject.create_string('idle')"
    state_machine = PatlangObject.create_string("idle")
    @user_objects << state_machine
    
    # Track state transition history
    transition_history = []
    
    state_machine.on_event(:value_changed) do |event|
      transition = {
        from: event[:data][:old_value],
        to: event[:data][:new_value],
        timestamp: event[:data][:timestamp]
      }
      
      transition_history << transition
      puts "    🔄 State: #{transition[:from]} → #{transition[:to]}"
      
      # Detect rapid state changes
      if transition_history.length >= 3
        recent = transition_history.last(3)
        time_span = recent.last[:timestamp] - recent.first[:timestamp]
        
        if time_span < 1.0
          puts "    🚨 PATTERN: Rapid state changes detected! (#{recent.length} changes in #{time_span.round(3)}s)"
        end
      end
      
      # Detect cycles
      if transition_history.length >= 4
        states = transition_history.last(4).map { |t| t[:to] }
        if states[0] == states[2] && states[1] == states[3]
          puts "    🔁 PATTERN: State oscillation detected! (#{states[0]} ↔ #{states[1]})"
        end
      end
    end
    
    puts ""
    puts "Let's trigger some state transitions to see pattern detection:"
    puts ""
    
    # Create rapid state changes
    states = ["active", "processing", "active", "processing", "error", "recovery", "active"]
    states.each do |state|
      state_machine.value = state
      sleep(0.1)
    end
    
    puts ""
    step_pause("Ready for performance testing?")
    
    puts "🔹 STEP 2: Performance Testing"
    puts "Test the system with high-volume operations:"
    puts ""
    
    puts "Creating 1000 objects for performance testing..."
    start_time = Time.now
    
    performance_objects = []
    1000.times do |i|
      obj = PatlangObject.create_number(i)
      performance_objects << obj
    end
    
    creation_time = Time.now - start_time
    puts "    ⚡ Created 1000 objects in #{(creation_time * 1000).round(2)}ms"
    
    # Test event processing performance
    puts ""
    puts "Testing high-volume event processing..."
    
    event_counter = 0
    performance_objects.first(100).each do |obj|
      obj.on_event(:value_changed) { event_counter += 1 }
    end
    
    start_time = Time.now
    performance_objects.first(100).each { |obj| obj.value = obj.value + 1 }
    processing_time = Time.now - start_time
    
    puts "    ⚡ Processed #{event_counter} events in #{(processing_time * 1000).round(2)}ms"
    puts "    📊 Rate: #{(event_counter / processing_time).round(0)} events/second"
    
    # Cleanup performance objects
    performance_objects.each(&:destroy)
    
    puts ""
    step_pause("Ready for advanced reactive patterns?")
    
    puts "🔹 STEP 3: Advanced Reactive Patterns"
    puts "Explore complex reactive programming patterns:"
    puts ""
    
    # Create a reactive spreadsheet-like system
    puts ">>> # Creating a reactive calculation system (like a spreadsheet)"
    
    cell_a1 = PatlangObject.create_number(10)
    cell_a1.set_metadata(:cell_id, "A1")
    @user_objects << cell_a1
    
    cell_a2 = PatlangObject.create_number(20)
    cell_a2.set_metadata(:cell_id, "A2")
    @user_objects << cell_a2
    
    cell_a3 = PatlangObject.create_number(0)  # Will be A1 + A2
    cell_a3.set_metadata(:cell_id, "A3")
    cell_a3.set_metadata(:formula, "=A1+A2")
    @user_objects << cell_a3
    
    cell_a4 = PatlangObject.create_number(0)  # Will be A3 * 2
    cell_a4.set_metadata(:cell_id, "A4")
    cell_a4.set_metadata(:formula, "=A3*2")
    @user_objects << cell_a4
    
    # Set up reactive formulas
    [cell_a1, cell_a2].each do |cell|
      cell.on_event(:value_changed) do |event|
        # A3 = A1 + A2
        new_sum = cell_a1.value + cell_a2.value
        cell_a3.value = new_sum
        puts "    📊 #{cell_a3.get_metadata(:cell_id)}: #{cell_a3.get_metadata(:formula)} = #{new_sum}"
      end
    end
    
    cell_a3.on_event(:value_changed) do |event|
      # A4 = A3 * 2
      new_product = cell_a3.value * 2
      cell_a4.value = new_product
      puts "    📊 #{cell_a4.get_metadata(:cell_id)}: #{cell_a4.get_metadata(:formula)} = #{new_product}"
    end
    
    puts ""
    puts "Testing reactive calculations:"
    puts "  A1=#{cell_a1.value}, A2=#{cell_a2.value}, A3=#{cell_a3.value}, A4=#{cell_a4.value}"
    puts ""
    
    puts ">>> cell_a1.value = 15"
    cell_a1.value = 15
    puts "  Result: A1=#{cell_a1.value}, A2=#{cell_a2.value}, A3=#{cell_a3.value}, A4=#{cell_a4.value}"
    puts ""
    
    puts ">>> cell_a2.value = 25"
    cell_a2.value = 25
    puts "  Result: A1=#{cell_a1.value}, A2=#{cell_a2.value}, A3=#{cell_a3.value}, A4=#{cell_a4.value}"
    puts ""
    
    step_pause("Ready to explore object lifecycle management?")
    
    puts "🔹 STEP 4: Object Lifecycle Management"
    puts "Learn about object destruction and cleanup patterns:"
    puts ""
    
    puts "Current object count: #{PatlangObject.object_count}"
    puts ""
    
    # Create temporary objects
    temp_objects = []
    5.times do |i|
      obj = PatlangObject.create_string("Temporary #{i}")
      obj.on_event(:object_destroyed) do |event|
        puts "    💀 Object #{event[:data][:object_id]} destroyed (was: #{event[:data][:final_value]})"
      end
      temp_objects << obj
    end
    
    puts "Created 5 temporary objects. Object count: #{PatlangObject.object_count}"
    puts ""
    
    puts "Destroying temporary objects..."
    temp_objects.each(&:destroy)
    
    puts "After cleanup. Object count: #{PatlangObject.object_count}"
    puts ""
    
    puts "✨ ADVANCED PATTERNS DEMONSTRATED:"
    puts "  ✅ Event history and pattern detection"
    puts "  ✅ High-performance event processing"
    puts "  ✅ Complex reactive calculations"
    puts "  ✅ Object lifecycle management"
    puts "  ✅ Memory management and cleanup"
    puts ""
    
    lesson_complete(6)
  end
  
  # ==========================================================================
  # UTILITY METHODS
  # ==========================================================================
  
  def lesson_header(number, title)
    puts "\n" + "=" * 65
    puts "📚 LESSON #{number}: #{title.upcase}"
    puts "=" * 65
    puts ""
  end
  
  def lesson_complete(number)
    @completed_lessons << number
    puts "\n✅ LESSON #{number} COMPLETE!"
    puts ""
    puts "🎓 You've learned:"
    case number
    when 1
      puts "  • How objects are created with automatic events"
      puts "  • Object properties and metadata"
      puts "  • Automatic lifecycle event generation"
    when 2
      puts "  • Registering custom event handlers"
      puts "  • Multiple handlers for the same event"
      puts "  • Metadata change event handling"
    when 3
      puts "  • Reactive programming without frameworks"
      puts "  • Automatic cascading reactions"
      puts "  • Reactive collections and aggregation"
    when 4
      puts "  • Object-to-object message passing"
      puts "  • Request-response patterns"
      puts "  • Broadcast messaging systems"
    when 5
      puts "  • Real-world system architecture"
      puts "  • Event-driven business logic"
      puts "  • Integrated service communication"
    when 6
      puts "  • Advanced event pattern detection"
      puts "  • High-performance event processing"
      puts "  • Complex reactive calculations"
      puts "  • Object lifecycle management"
    end
    
    puts ""
    puts "Progress: #{@completed_lessons.length}/6 lessons completed"
    
    if @completed_lessons.length == 6
      puts ""
      puts "🎊 CONGRATULATIONS! You've completed all lessons!"
      puts "You now understand Patlang's revolutionary object-oriented event system."
    end
    
    puts ""
    step_pause("Press Enter to return to menu...")
  end
  
  def step_pause(message = "Press Enter to continue...")
    print "#{message} "
    gets
  end
  
  def clear_event_log
    @event_log.clear
  end
  
  def review_event_log
    puts "\n📋 EVENT LOG REVIEW"
    puts "-" * 30
    
    if @event_log.empty?
      puts "No events recorded yet."
    else
      puts "Recent events (last 20):"
      puts ""
      
      @event_log.last(20).each_with_index do |event, index|
        timestamp = event[:timestamp].strftime("%H:%M:%S.%L")
        puts "#{index + 1}. [#{timestamp}] #{event[:type]}"
        
        case event[:type]
        when :object_created
          puts "   Object #{event[:data][:object_id]} created (#{event[:data][:type]}): #{event[:data][:value]}"
        when :value_changed
          puts "   Object #{event[:data][:object_id]}: #{event[:data][:old_value]} → #{event[:data][:new_value]}"
        when :message_sent
          puts "   Message: #{event[:data][:from]} → #{event[:data][:to]} (#{event[:data][:type]})"
        when :message_received
          puts "   Received: #{event[:data][:from]} → #{event[:data][:to]} (#{event[:data][:type]})"
        when :metadata_changed
          puts "   Metadata #{event[:data][:object_id]}: #{event[:data][:key]} = #{event[:data][:new_value]}"
        when :object_destroyed
          puts "   Object #{event[:data][:object_id]} destroyed"
        end
        puts ""
      end
      
      puts "Total events logged: #{@event_log.length}"
    end
    
    puts ""
    step_pause("Press Enter to return to menu...")
  end
  
  def cleanup_objects
    puts "\n🧹 CLEANING UP OBJECTS"
    puts "-" * 30
    
    initial_count = PatlangObject.object_count
    puts "Objects before cleanup: #{initial_count}"
    
    @user_objects.each(&:destroy)
    @user_objects.clear
    
    final_count = PatlangObject.object_count
    puts "Objects after cleanup: #{final_count}"
    puts "Cleaned up: #{initial_count - final_count} objects"
    
    puts ""
    step_pause("Press Enter to return to menu...")
  end
end

# =============================================================================
# MAIN EXECUTION
# =============================================================================

if __FILE__ == $0
  tutorial = OOEventTutorial.new
  tutorial.start_tutorial
end