# Control Flow Demo - showcasing if/else and while loops

# Simple conditional
x = 10
if x > 5 then
  result = 100
else
  result = 50
end

# While loop with accumulator
counter = 1
sum = 0
while counter <= 5 do
  sum = sum + counter
  counter = counter + 1
end

# Nested control flow
i = 0
factorial = 1
while i < 4 do
  i = i + 1
  if i > 1 then
    factorial = factorial * i
  end
end