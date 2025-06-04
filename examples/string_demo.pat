# =============================================================================
# 🎯 Roadmap Feature - Planned for v0.7.0+ based on object model foundation
# =============================================================================
#
# ⚠️  IMPLEMENTATION STATUS: String operations not yet integrated
#     This example demonstrates the planned comprehensive string capabilities
#     that will be built on top of our revolutionary v0.6.0 object model foundation.
#
# 🎯 To see working object model capabilities right now:
#     ruby examples/oo_event_system_demo_fixed.rb
#     ruby examples/network_transparent_demo_fixed.rb
#
# This file showcases the target architecture that will extend our
# 'everything is objects' foundation with rich string manipulation syntax.
#
# =============================================================================

greeting = "Hello"
name = "World"
punctuation = "!"

message = greeting + ", " + name + punctuation
"Basic concatenation: " + message

length = message.length
"Message length: " + length

first_char = message[1]
last_char = message[-1]
"First character: " + first_char
"Last character: " + last_char

text = "  Hello World Programming  "

upper_text = text.uppercase()
lower_text = text.lowercase()
"Uppercase: '" + upper_text + "'"
"Lowercase: '" + lower_text + "'"

trimmed = text.trim()
"Original: '" + text + "'"
"Trimmed: '" + trimmed + "'"

part = trimmed.substring(6, 5)
"Substring (6,5): '" + part + "'"

if trimmed.starts_with("Hello") then
  "Text starts with 'Hello'"
else
  "Text does not start with 'Hello'"
end

if trimmed.ends_with("Programming") then
  "Text ends with 'Programming'"
else
  "Text does not end with 'Programming'"
end

filename = "document.txt"
if filename.ends_with(".txt") then
  base_name = filename.substring(1, filename.length - 4)
  "Processing text file: " + base_name.uppercase()
else
  "Unknown file type: " + filename
end

data = "abc123"
i = 1
result = ""
while i <= data.length do
  char = data[i]
  if char >= "a" then
    if char <= "z" then
      result = result + char.uppercase()
    else
      result = result + char
    end
  else
    result = result + char
  end
  i = i + 1
end
"Loop processing result: " + result

user_input = "  ADMIN USER  "
processed = user_input.trim().lowercase()
if processed == "admin user" then
  "Access granted for: " + processed.uppercase()
else
  "Access denied for: " + processed
end

demo_text = "  programming is fun!  "
final_result = demo_text.trim().uppercase().substring(1, 11)
"Chained operations result: '" + final_result + "'"

word1 = "apple"
word2 = "banana"
if word1 < word2 then
  "Alphabetical order: " + word1 + " comes before " + word2
else
  "Alphabetical order: " + word2 + " comes before " + word1
end

email = "user@example.com"
at_position = 0
i = 1
while i <= email.length do
  if email[i] == "@" then
    at_position = i
  end
  i = i + 1
end

if at_position > 0 then
  username = email.substring(1, at_position - 1)
  domain_part = email.substring(at_position + 1, email.length - at_position)
  "Email analysis:"
  "  Username: " + username.uppercase()
  "  Domain: " + domain_part.lowercase()
else
  "Invalid email format"
end

base = "Hello"
count = 3
separator = " | "
combined = base + separator + count + separator + base.uppercase()
"Complex expression: " + combined

clean_data = "  DATA123  ".trim().lowercase()
starts_ok = clean_data.starts_with("data")
ends_ok = clean_data.ends_with("123")
if starts_ok then
  if ends_ok then
    "Valid data format: " + clean_data
  else
    "Invalid data format: " + clean_data
  end
else
  "Invalid data format: " + clean_data
end

final_msg = "Patlang v0.4.0 String Operations Complete!"
"String Demo Result: " + final_msg