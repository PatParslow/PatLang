# Complex Function Examples - Advanced function parsing demonstrations
# These examples showcase PaTLang's natural language function syntax

# Simple function definition
make a function called greet takes name returns "Hello, " + name end

# Function with multiple parameters
make a function called add takes x, y returns x + y end

# Function with complex body
make a function called factorial takes n
    if n <= 1 then
        return 1
    else
        return n * factorial(n - 1)
    end
end

# Function without parameters
make a function called get_current_time returns current_timestamp() end

# Function with conditional logic
make a function called max takes a, b
    if a > b then
        return a
    else
        return b
    end
end

# Function with reasoning constructs
make a function called is_positive takes number
    fact number_value(number)
    rule positive(N) :- number_value(N), N > 0
    return positive(number)
end

# Nested function definitions
make a function called create_calculator
    make a function called add takes x, y returns x + y end
    make a function called multiply takes x, y returns x * y end
    return {add: add, multiply: multiply}
end

# Function with type constraints
make a function called safe_divide takes numerator, denominator
    constrain numerator :: Number
    constrain denominator :: Number where denominator != 0
    return numerator / denominator
end

# Function with goal-oriented logic
make a function called optimize_route takes start, destination
    goal find_shortest_path(start, destination) {
        precondition: valid_location(start) and valid_location(destination),
        postcondition: path.length > 0 and path.distance == minimal_distance,
        strategy: dijkstra_algorithm
    }
    return find_shortest_path(start, destination)
end