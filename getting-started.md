# Patlang Getting Started Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Installation and Setup](#installation-and-setup)
3. [Your First Patlang Program](#your-first-patlang-program)
4. [Basic Concepts Tutorial](#basic-concepts-tutorial)
5. [Multi-Paradigm Programming Tutorial](#multi-paradigm-programming-tutorial)
6. [Real-World Examples Walkthrough](#real-world-examples-walkthrough)
7. [Migration Guide](#migration-guide)
8. [Common Patterns and Idioms](#common-patterns-and-idioms)
9. [Troubleshooting and FAQ](#troubleshooting-and-faq)
10. [Next Steps](#next-steps)

---

## Introduction

Welcome to Patlang! This guide will help you learn Patlang from the ground up, whether you're new to programming or coming from another language. Patlang's unique multi-paradigm approach allows you to use object-oriented programming, functional programming, goal-oriented programming, event-driven programming, and logic programming all in the same code.

### What Makes Patlang Special?

- **Natural Language Syntax**: Code reads like English
- **Multi-Paradigm Unity**: All programming paradigms work together seamlessly
- **Interactive Development**: Built-in REPL for rapid experimentation
- **Type Safety**: Automatic type inference with optional annotations
- **Goal-Oriented Programming**: Declarative dependency resolution

### Learning Path

This guide follows a progressive learning approach:
1. **Hello World** → Basic syntax and concepts
2. **Building Blocks** → Variables, functions, and control flow
3. **Object-Oriented** → Classes and objects
4. **Functional** → Higher-order functions and composition
5. **Goal-Oriented** → Declarative programming with dependencies
6. **Events** → Reactive programming
7. **Logic** → Rule-based programming
8. **Integration** → Combining paradigms naturally

---

## Installation and Setup

> **Note**: Patlang is currently in development. The final installation process will be available when the interpreter is complete.

### Future Installation (When Available)

```bash
# Download and install Patlang
curl -sSL https://get.patlang.org | bash

# Verify installation
patlang --version

# Start interactive REPL
patlang
```

### Current Development Setup

For now, you can follow along with the examples in this guide to understand Patlang's concepts and syntax. The implementation is being built in Ruby following the architecture outlined in the language specification.

### Development Environment

When available, Patlang will support:
- **Command Line Interface**: `patlang script.pat`
- **Interactive REPL**: Real-time code evaluation
- **IDE Integration**: Syntax highlighting and debugging support
- **VS Code Extension**: Full language support

---

## Your First Patlang Program

Let's start with the classic "Hello, World!" program:

### Hello World

```patlang
# Your first Patlang program
print "Hello, World!"
```

This simple program demonstrates Patlang's natural syntax. The `print` function outputs text to the console.

### Interactive Hello World

Let's make it interactive:

```patlang
# Interactive hello world
print "What's your name?"
name is read_line()
print "Hello, " + name + "!"
```

### Explanation

- `name is read_line()` reads user input and assigns it to the variable `name`
- String concatenation uses the `+` operator
- Variables are created automatically when assigned

### Hello World with Types

```patlang
# Hello world with explicit types
make a text called greeting { greeting is "Hello" }
make a text called name { name is read_line() }
make a text called message { message is greeting + ", " + name + "!" }
print message
```

This shows Patlang's natural declaration syntax:
- `make a text called greeting` creates a string variable
- Block syntax `{ ... }` defines the variable's value
- Type annotations are optional but can improve clarity

---

## Basic Concepts Tutorial

### Variables and Types

#### Simple Variables

```patlang
# Basic variable creation
age is 25
name is "Alice"
active is true
score is 98.5

# Print variables
print "Name: " + name
print "Age: " + age
print "Active: " + active
print "Score: " + score
```

#### Explicit Type Declarations

```patlang
# Explicit type declarations with make
make a number called temperature { temperature is 20.5 }
make a text called city { city is "London" }
make a boolean called is_sunny { is_sunny is false }

# Variables can change
temperature becomes 22.0
city becomes "Paris"
is_sunny becomes true

print "It's " + temperature + "°C in " + city
```

#### Type Inference

```patlang
# Patlang automatically infers types
count is 0          # integer
rate is 0.05        # float  
title is "Book"     # text
ready is false      # boolean

# Type inference works with expressions
total is count * rate
full_title is "The " + title
```

### Collections

#### Arrays (Lists)

```patlang
# Creating arrays (1-indexed like mathematical notation)
numbers is [1, 2, 3, 4, 5]
names is ["Alice", "Bob", "Charlie"]
mixed is [1, "hello", true, 3.14]

# Accessing elements
first_number is numbers[1]      # Gets 1 (first element)
last_number is numbers[-1]      # Gets 5 (last element)
second_name is names[2]         # Gets "Bob"

# Array operations
length is numbers.length        # Gets 5
numbers.append(6)              # Adds 6 to the end
numbers.prepend(0)             # Adds 0 to the beginning

print "Numbers: " + numbers
print "First: " + first_number + ", Last: " + last_number
```

#### Objects (Dictionaries)

```patlang
# Creating objects
person is {
  name: "Alice",
  age: 30,
  city: "London",
  hobbies: ["reading", "coding", "hiking"]
}

# Accessing properties
print person.name              # Prints "Alice"
print person["age"]            # Prints 30
print person.hobbies[1]        # Prints "reading"

# Adding and modifying properties
person.job = "Developer"
person.age = 31
person.hobbies.append("photography")
```

### Functions

#### Basic Functions

```patlang
# Simple function
make a function called greet {
  greet takes:
    name - text
  greet returns:
    "Hello, " + name + "!"
}

# Call the function
message is greet("Alice")
print message                  # Prints "Hello, Alice!"
```

#### Functions with Multiple Parameters

```patlang
# Function with multiple parameters
make a function called calculate_area {
  calculate_area takes:
    width - number
    height - number
  calculate_area returns:
    width * height
}

# Function with default parameters
make a function called greet_with_title {
  greet_with_title takes:
    name - text
    title - text = "Friend"
  greet_with_title returns:
    "Hello, " + title + " " + name + "!"
}

# Using the functions
area is calculate_area(10, 5)
greeting1 is greet_with_title("Alice")
greeting2 is greet_with_title("Bob", "Dr.")

print "Area: " + area          # Prints "Area: 50"
print greeting1                # Prints "Hello, Friend Alice!"
print greeting2                # Prints "Hello, Dr. Bob!"
```

#### Functions with Complex Logic

```patlang
# Function with conditional logic
make a function called describe_temperature {
  describe_temperature takes:
    temp - number
  describe_temperature returns:
    if temp < 0 then
      "Freezing cold!"
    elsif temp < 10 then
      "Very cold"
    elsif temp < 20 then
      "Cool"
    elsif temp < 30 then
      "Warm"
    else
      "Hot!"
    end
}

temperature is 22
description is describe_temperature(temperature)
print "It's " + temperature + "°C - " + description
```

### Control Flow

#### Conditional Statements

```patlang
# Basic if statement
age is 18

if age >= 18 then
  print "You're an adult"
else
  print "You're a minor"
end

# Multiple conditions
score is 85

if score >= 90 then
  grade is "A"
elsif score >= 80 then
  grade is "B"
elsif score >= 70 then
  grade is "C"
elsif score >= 60 then
  grade is "D"
else
  grade is "F"
end

print "Your grade is: " + grade
```

#### Loops

```patlang
# While loop
count is 1
while count <= 5 do
  print "Count: " + count
  count becomes count + 1
end

# For loop with range
for number in [1, 2, 3, 4, 5] do
  print "Number: " + number
end

# For loop with collection
names is ["Alice", "Bob", "Charlie"]
for each name in names:
  print "Hello, " + name
end

# For loop with index
for index in range(1, 5) do
  print "Index " + index + " squared is " + (index * index)
end
```

---

## Multi-Paradigm Programming Tutorial

Now let's explore Patlang's unique multi-paradigm capabilities. Each programming paradigm excels at different types of problems, and Patlang lets you use them together naturally.

### Object-Oriented Programming

#### Creating Classes

```patlang
# Define a class (called a template in Patlang)
make a template called Person {
  Person has:
    name - text
    age - number
    email - email = ""
    
  # Class invariants (always true)
  Person maintains:
    age >= 0
    name is not empty
    
  # Method definition
  greet takes:
    other - Person
  greet returns:
    "Hello " + other.name + ", I'm " + name
    
  get_info returns:
    "#{name} is #{age} years old"
    
  have_birthday returns: {
    age becomes age + 1
    print name + " is now " + age + " years old!"
  }
}

# Create objects
alice is Person.new("Alice", 30, "alice@example.com")
bob is Person.new("Bob", 25)

# Use methods
print alice.greet(bob)         # "Hello Bob, I'm Alice"
print alice.get_info()         # "Alice is 30 years old"
alice.have_birthday()          # "Alice is now 31 years old!"
```

#### Inheritance

```patlang
# Inheritance example
make a template called Student {
  Student inherits from Person
  Student has:
    student_id - text
    major - text
    gpa - number = 0.0
    
  Student maintains:
    gpa >= 0.0 and gpa <= 4.0
    student_id is not empty
    
  study takes:
    subject - text
    hours - number
  study returns: {
    print name + " studied " + subject + " for " + hours + " hours"
    # Studying improves GPA slightly
    gpa becomes min(4.0, gpa + (hours * 0.01))
  }
  
  get_info returns:
    Person.get_info() + ", Student ID: " + student_id + ", GPA: " + gpa
}

# Create a student
charlie is Student.new("Charlie", 20, "charlie@university.edu", "STU123", "Computer Science", 3.5)

print charlie.get_info()
charlie.study("Math", 3)
charlie.study("Programming", 5)
print charlie.get_info()
```

### Functional Programming

#### Higher-Order Functions

```patlang
# Define utility functions
make a function called square {
  square takes: x - number
  square returns: x * x
}

make a function called is_even {
  is_even takes: x - number
  is_even returns: x % 2 == 0
}

# Using higher-order functions
numbers is [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

# Map: transform each element
squared_numbers is map(numbers, square)
print "Squared: " + squared_numbers    # [1, 4, 9, 16, 25, 36, 49, 64, 81, 100]

# Filter: select elements that match a condition
even_numbers is filter(numbers, is_even)
print "Even numbers: " + even_numbers  # [2, 4, 6, 8, 10]

# Reduce: combine all elements into a single value
sum is reduce(numbers, |acc, x| acc + x, 0)
print "Sum: " + sum                    # 55
```

#### Function Composition and Pipelines

```patlang
# Function composition with pipe operator
result is [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  |> filter(|x| x % 2 == 0)           # Get even numbers: [2, 4, 6, 8, 10]
  |> map(|x| x * x)                   # Square them: [4, 16, 36, 64, 100]
  |> reduce(|acc, x| acc + x, 0)      # Sum them: 220

print "Result: " + result

# Anonymous functions (lambdas)
double is |x| x * 2
add is |a, b| a + b
compose is |f, g| |x| f(g(x))

# Function composition
double_then_square is compose(square, double)
print double_then_square(3)            # 36 (3 * 2 = 6, 6 * 6 = 36)
```

#### Currying and Partial Application

```patlang
# Curried function
make a function called add {
  add takes: a - number
  add returns: |b| a + b
}

# Partial application
add_5 is add(5)
result1 is add_5(3)                    # 8
result2 is add_5(10)                   # 15

print "5 + 3 = " + result1
print "5 + 10 = " + result2

# More complex currying
make a function called multiply_then_add {
  multiply_then_add takes: multiplier - number
  multiply_then_add returns: {
    |adder| |value| (value * multiplier) + adder
  }
}

double_then_add_one is multiply_then_add(2)(1)
result is double_then_add_one(5)       # (5 * 2) + 1 = 11
print "Result: " + result
```

### Goal-Oriented Programming

Goal-oriented programming lets you declare what you want to achieve, and Patlang figures out how to do it by managing dependencies automatically.

#### Basic Goals

```patlang
# Define a goal
make a goal called make_coffee {
  make_coffee requires:
    water - text
    coffee_beans - text
    clean_cup - text
    
  make_coffee is achieved when:
    water is "hot"
    coffee_beans is "ground"
    clean_cup is "available"
    
  make_coffee runs: {
    print "Brewing coffee with " + coffee_beans + " and " + water + " water"
    print "Serving in " + clean_cup + " cup"
    "delicious coffee"
  }
}

# Sub-goals for dependencies
make a goal called heat_water {
  heat_water is achieved when:
    water_temperature > 80
  heat_water runs: {
    print "Heating water..."
    water_temperature becomes 95
    "hot"
  }
}

make a goal called grind_beans {
  grind_beans requires:
    bean_type - text = "arabica"
  grind_beans is achieved when:
    bean_type is not empty
  grind_beans runs: {
    print "Grinding " + bean_type + " beans..."
    "ground"
  }
}

make a goal called get_clean_cup {
  get_clean_cup runs: {
    print "Getting a clean cup..."
    "available"
  }
}

# Activate the main goal - Patlang will resolve dependencies automatically
water_temperature is 20
coffee is activate make_coffee
print "Enjoy your " + coffee + "!"
```

#### Complex Goal Dependencies

```patlang
# Email sending system with complex dependencies
make a goal called send_newsletter {
  send_newsletter requires:
    subscriber_list - list
    email_content - text
    email_template - text
    smtp_config - text
    
  send_newsletter is achieved when:
    subscriber_list.length > 0
    email_content is not empty
    email_template is "loaded"
    smtp_config is "configured"
    
  send_newsletter runs: {
    formatted_emails is format_emails(email_content, email_template, subscriber_list)
    send_emails(formatted_emails, smtp_config)
    "Newsletter sent to " + subscriber_list.length + " subscribers"
  }
}

# Sub-goals with their own dependencies
make a goal called load_subscribers {
  load_subscribers requires:
    database_connection - text
    
  load_subscribers is achieved when:
    database_connection is "connected"
    
  load_subscribers runs: {
    # Simulated database query
    ["alice@example.com", "bob@example.com", "charlie@example.com"]
  }
}

make a goal called create_content {
  create_content requires:
    news_items - list
    editorial_review - text
    
  create_content is achieved when:
    news_items.length > 0
    editorial_review is "approved"
    
  create_content runs: {
    # Combine news items into content
    news_items.join("\n\n")
  }
}

# The system automatically resolves all dependencies
result is activate send_newsletter
print result
```

### Event-Driven Programming

Event-driven programming lets your code react to things that happen, making it perfect for user interfaces, real-time systems, and reactive applications.

#### Basic Event Handling

```patlang
# Define event handlers
when user: login is activated {
  print "User " + user.name + " logged in at " + current_time()
  user.last_login = current_time()
  emit user_activity with ["login", user.id]
}

when user: logout is activated {
  print "User " + user.name + " logged out"
  emit user_activity with ["logout", user.id]
}

when user_activity is activated {
  activity_type is event_data[0]
  user_id is event_data[1]
  print "Logging activity: " + activity_type + " for user " + user_id
}

# Simulate events
alice is { name: "Alice", id: 123 }
emit user: login with alice
# Later...
emit user: logout with alice
```

#### Event Chains and Processing

```patlang
# File processing pipeline with events
when file: uploaded is activated {
  file_path is event_data.path
  file_size is event_data.size
  
  print "File uploaded: " + file_path + " (" + file_size + " bytes)"
  
  # Trigger validation
  emit file: validate with file_path
}

when file: validate is activated {
  file_path is event_data
  
  # Simulated validation
  if file_path.ends_with(".txt") then
    print "File validation passed: " + file_path
    emit file: process with file_path
  else
    print "File validation failed: " + file_path
    emit file: error with ["Invalid file type", file_path]
  end
}

when file: process is activated {
  file_path is event_data
  
  print "Processing file: " + file_path
  
  # Simulated processing
  processed_content is "Processed content from " + file_path
  
  emit file: completed with [file_path, processed_content]
}

when file: completed is activated {
  file_path is event_data[0]
  content is event_data[1]
  
  print "File processing completed: " + file_path
  print "Result: " + content
}

when file: error is activated {
  error_message is event_data[0]
  file_path is event_data[1]
  
  print "Error processing " + file_path + ": " + error_message
}

# Simulate file upload
emit file: uploaded with { path: "document.txt", size: 1024 }
emit file: uploaded with { path: "image.jpg", size: 2048 }
```

### Logic Programming

Logic programming lets you define facts and rules, then query them to solve complex problems automatically.

#### Facts and Basic Queries

```patlang
# Define facts about family relationships
Janet is John's parent.
John is Mary's parent.
Mary is Susan's parent.
Tom is Mary's parent.

# Alternative predicate syntax
parent(janet, john).
parent(john, mary).
parent(mary, susan).
parent(tom, mary).

# Define rules
relationship X is grandparent of Y requires:
  X is parent of Z and Z is parent of Y.

relationship X is sibling of Y requires:
  Z is parent of X and Z is parent of Y and X is not Y.

# Make queries
query find_all_grandparents
  find_all_grandparents returns:
    X is grandparent of Y.
end

query are_siblings(A, B)
  are_siblings(A, B) returns:
    A is sibling of B.
end

# Use queries in regular code
grandparents is find_all_grandparents()
print "Grandparent relationships:"
for each relationship in grandparents:
  print relationship[0] + " is grandparent of " + relationship[1]
end

if are_siblings("john", "tom") then
  print "John and Tom are siblings"
else
  print "John and Tom are not siblings"
end
```

#### Business Rules with Logic Programming

```patlang
# Business rules for loan approval
make a template called LoanApplication {
  LoanApplication has:
    applicant_name - text
    annual_income - number
    credit_score - number
    requested_amount - number
    employment_years - number
}

# Define business rules using logic programming
relationship application is approved requires:
  application.credit_score >= 650 and
  application.employment_years >= 2 and
  debt_to_income_ratio(application) <= 0.36 and
  loan_to_income_ratio(application) <= 5.0.

relationship application is high_risk requires:
  application.credit_score < 700 or
  application.employment_years < 3 or
  debt_to_income_ratio(application) > 0.30.

# Helper functions for calculations
make a function called debt_to_income_ratio {
  debt_to_income_ratio takes: app - LoanApplication
  debt_to_income_ratio returns:
    # Simplified calculation
    (app.requested_amount * 0.05) / (app.annual_income / 12)
}

make a function called loan_to_income_ratio {
  loan_to_income_ratio takes: app - LoanApplication
  loan_to_income_ratio returns:
    app.requested_amount / app.annual_income
}

# Use logic programming in business logic
make a function called evaluate_loan {
  evaluate_loan takes: application - LoanApplication
  evaluate_loan returns: {
    # Query the rules
    query approved(application) returns:
      application is approved.
    end
    
    query high_risk(application) returns:
      application is high_risk.
    end
    
    if approved(application) then
      if high_risk(application) then
        "Approved with conditions"
      else
        "Approved"
      end
    else
      "Denied"
    end
  }
}

# Test the loan evaluation
app1 is LoanApplication.new("Alice", 75000, 720, 200000, 5)
app2 is LoanApplication.new("Bob", 45000, 580, 300000, 1)

print "Alice's application: " + evaluate_loan(app1)
print "Bob's application: " + evaluate_loan(app2)
```

---

## Real-World Examples Walkthrough

Let's build a complete real-world application that demonstrates how all paradigms work together in Patlang.

### Web API Server

We'll build a simple web API server for a task management system:

```patlang
# Task management web API demonstrating multi-paradigm integration

# OOP: Domain models
make a template called Task {
  Task has:
    id - text
    title - text
    description - text
    status - text = "pending"
    priority - text = "medium"
    created_at - time
    updated_at - time
    
  Task maintains:
    title is not empty
    status in ["pending", "in_progress", "completed"]
    priority in ["low", "medium", "high"]
    
  mark_completed returns: {
    status becomes "completed"
    updated_at becomes current_time()
    
    # Event-driven: Notify when task completed
    emit task: completed with self
  }
  
  update_priority takes: new_priority - text
  update_priority returns: {
    if new_priority in ["low", "medium", "high"] then
      priority becomes new_priority
      updated_at becomes current_time()
      emit task: priority_changed with [self, priority]
    else
      throw ValidationError("Invalid priority: " + new_priority)
    end
  }
}

# OOP: Repository pattern for data storage
make a template called TaskRepository {
  TaskRepository has:
    tasks - list of Task = []
    next_id - number = 1
    
  create_task takes:
    title - text
    description - text = ""
    priority - text = "medium"
  create_task returns: {
    task is Task.new(
      id: "task_" + next_id,
      title: title,
      description: description,
      priority: priority,
      created_at: current_time(),
      updated_at: current_time()
    )
    
    tasks.append(task)
    next_id becomes next_id + 1
    
    # Event-driven: Notify when task created
    emit task: created with task
    
    task
  }
  
  find_by_id takes: id - text
  find_by_id returns: {
    # Functional: Use find to locate task
    tasks.find(|task| task.id == id)
  }
  
  find_by_status takes: status - text
  find_by_status returns: {
    # Functional: Filter tasks by status
    tasks.filter(|task| task.status == status)
  }
  
  get_high_priority_tasks returns: {
    # Logic programming: Complex query
    query high_priority_task(task) returns:
      task.priority == "high" and
      task.status != "completed"
    end
    
    tasks.filter(|task| high_priority_task(task))
  }
}

# Goal-oriented: API endpoint processing
make a goal called process_api_request {
  process_api_request requires:
    request - HTTPRequest
    repository - TaskRepository
    
  process_api_request is achieved when:
    request is valid and
    route is matched and
    response is generated
    
  process_api_request runs: {
    # Functional: Route matching
    route_handler is match_route(request.path, request.method)
    
    if route_handler then
      response is route_handler(request, repository)
      send_response(response)
    else
      send_error_response(404, "Route not found")
    end
  }
}

# Functional: Route matching and handling
make a function called match_route {
  match_route takes:
    path - text
    method - text
  match_route returns: {
    routes is {
      "GET /tasks": handle_get_tasks,
      "POST /tasks": handle_create_task,
      "GET /tasks/:id": handle_get_task,
      "PUT /tasks/:id": handle_update_task,
      "DELETE /tasks/:id": handle_delete_task
    }
    
    route_key is method + " " + normalize_path(path)
    routes[route_key]
  }
}

# API handlers using functional programming
make a function called handle_get_tasks {
  handle_get_tasks takes:
    request - HTTPRequest
    repository - TaskRepository
  handle_get_tasks returns: {
    # Functional: Filter and transform tasks
    status_filter is request.query_params["status"]
    
    tasks is if status_filter then
      repository.find_by_status(status_filter)
    else
      repository.tasks
    end
    
    # Functional: Transform to API format
    api_tasks is tasks.map(|task| {
      id: task.id,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      created_at: task.created_at.to_iso_string(),
      updated_at: task.updated_at.to_iso_string()
    })
    
    HTTPResponse.json(200, api_tasks)
  }
}

make a function called handle_create_task {
  handle_create_task takes:
    request - HTTPRequest
    repository - TaskRepository
  handle_create_task returns: {
    try
      # Functional: Parse and validate request data
      task_data is JSON.parse(request.body)
        |> validate_required_fields(["title"])
        |> validate_optional_fields(["description", "priority"])
        |> sanitize_input
      
      # Goal-oriented: Create task with dependencies
      make a goal called create_new_task {
        create_new_task requires:
          validated_data - object
          task_repository - TaskRepository
          
        create_new_task is achieved when:
          validated_data is valid and
          task_repository is available
          
        create_new_task runs: {
          new_task is repository.create_task(
            task_data.title,
            task_data.description or "",
            task_data.priority or "medium"
          )
          
          HTTPResponse.json(201, {
            id: new_task.id,
            title: new_task.title,
            status: new_task.status,
            message: "Task created successfully"
          })
        }
      }
      
      activate create_new_task with [task_data, repository]
      
    catch ValidationError as error
      HTTPResponse.json(400, { error: error.message })
    catch Error as error
      HTTPResponse.json(500, { error: "Internal server error" })
    end
  }
}

# Event handlers for cross-cutting concerns
when task: created is activated {
  task is event_data
  print "New task created: " + task.title + " (ID: " + task.id + ")"
  
  # Logic programming: Auto-assign high priority tasks
  query should_auto_assign(task) returns:
    task.priority == "high" and
    task.title.contains("urgent")
  end
  
  if should_auto_assign(task) then
    print "Auto-assigning urgent high-priority task: " + task.id
    emit task: auto_assigned with task
  end
}

when task: completed is activated {
  task is event_data
  print "Task completed: " + task.title
  
  # Goal-oriented: Trigger completion workflow
  activate send_completion_notification with task
  activate update_project_progress with task
}

when task: priority_changed is activated {
  task is event_data[0]
  new_priority is event_data[1]
  
  print "Task " + task.id + " priority changed to " + new_priority
  
  # Logic programming: Check if reassignment needed
  query needs_reassignment(task) returns:
    task.priority == "high" and
    task.status == "pending"
  end
  
  if needs_reassignment(task) then
    emit task: needs_assignment with task
  end
}

# Main server setup combining all paradigms
make a function called start_task_server {
  start_task_server takes:
    port - number = 3000
    
  start_task_server returns: {
    repository is TaskRepository.new()
    
    # Event-driven: Set up request handling
    when server: request_received is activated {
      request is event_data
      
      print "Processing " + request.method + " " + request.path
      
      # Goal-oriented: Process each request
      activate process_api_request with [request, repository]
    }
    
    print "Starting task management API server on port " + port
    print "Available endpoints:"
    print "  GET /tasks - List all tasks"
    print "  POST /tasks - Create a new task"
    print "  GET /tasks/:id - Get a specific task"
    print "  PUT /tasks/:id - Update a task"
    print "  DELETE /tasks/:id - Delete a task"
    
    # Start the server (implementation depends on runtime)
    start_http_server(port)
  }
}

# Start the server
start_task_server(3000)
```

This example demonstrates:

1. **OOP**: Domain models (Task) and repository pattern
2. **Functional**: Data transformation pipelines and route handling
3. **Goal-oriented**: Request processing with dependency resolution
4. **Event-driven**: Task lifecycle events and notifications
5. **Logic programming**: Business rules for task assignment and prioritization
6. **Integration**: All paradigms working together naturally

---

## Migration Guide

### Coming from Ruby

If you're familiar with Ruby, you'll find Patlang's object-oriented features familiar, but with additional paradigm support:

#### Ruby vs Patlang: Classes

**Ruby:**
```ruby
class Person
  attr_accessor :name, :age
  
  def initialize(name, age)
    @name = name
    @age = age
  end
  
  def greet(other)
    "Hello #{other.name}, I'm #{@name}"
  end
end

person = Person.new("Alice", 30)
```

**Patlang:**
```patlang
make a template called Person {
  Person has:
    name - text
    age - number
    
  Person maintains:
    age >= 0
    name is not empty
    
  greet takes:
    other - Person
  greet returns:
    "Hello #{other.name}, I'm #{name}"
}

person is Person.new("Alice", 30)
```

**Key Differences:**
- `template` instead of `class`
- `has:` section for properties
- `maintains:` for invariants (design by contract)
- No explicit constructor (auto-generated)
- Type annotations with `-` syntax

### Coming from Python

Python developers will appreciate Patlang's clean syntax and duck typing, enhanced with static type checking:

#### Python vs Patlang: Functions

**Python:**
```python
def process_data(items, transform_func, filter_func):
    filtered = filter(filter_func, items)
    transformed = map(transform_func, filtered)
    return list(transformed)

result = process_data(
    [1, 2, 3, 4, 5],
    lambda x: x * 2,
    lambda x: x % 2 == 0
)
```

**Patlang:**
```patlang
make a function called process_data {
  process_data takes:
    items - list
    transform_func - (any -> any)
    filter_func - (any -> boolean)
  process_data returns: {
    items
      |> filter(filter_func)
      |> map(transform_func)
  }
}

result is process_data(
  [1, 2, 3, 4, 5],
  |x| x * 2,
  |x| x % 2 == 0
)
```

**Key Differences:**
- Explicit type annotations encouraged
- Pipe operator `|>` for function composition
- `|x| expression` syntax for lambdas
- Built-in functional programming constructs

### Coming from Haskell

Haskell developers will find familiar functional programming concepts with added OOP and goal-oriented features:

#### Haskell vs Patlang: Type System

**Haskell:**
```haskell
data Person = Person { name :: String, age :: Int }

greet :: Person -> Person -> String
greet p1 p2 = "Hello " ++ name p2 ++ ", I'm " ++ name p1

processList :: [a] -> (a -> b) -> (b -> Bool) -> [b]
processList xs f p = filter p (map f xs)
```

**Patlang:**
```patlang
make a template called Person {
  Person has:
    name - text
    age - number
}

make a function called greet {
  greet takes:
    p1 - Person
    p2 - Person
  greet returns:
    "Hello " + p2.name + ", I'm " + p1.name
}

make a function called process_list {
  process_list takes:
    xs - list of T
    f - (T -> U)
    p - (U -> boolean)
  process_list returns: list of U
  process_list returns: {
    xs |> map(f) |> filter(p)
  }
}
```

**Key Differences:**
- Object-oriented syntax alongside functional features
- More verbose but readable syntax
- Built-in goal-oriented and event-driven programming
- Type inference with optional annotations

### Coming from JavaScript

JavaScript developers will find Patlang's event-driven programming familiar, with additional structure and type safety:

#### JavaScript vs Patlang: Events

**JavaScript:**
```javascript
class EventEmitter {
  constructor() {
    this.events = {};
  }
  
  on(event, handler) {
    if (!this.events[event]) this.events[event] = [];
    this.events[event].push(handler);
  }
  
  emit(event, data) {
    if (this.events[event]) {
      this.events[event].forEach(handler => handler(data));
    }
  }
}

const emitter = new EventEmitter();
emitter.on('user:login', (user) => {
  console.log(`User ${user.name} logged in`);
});
emitter.emit('user:login', { name: 'Alice' });
```

**Patlang:**
```patlang
# Events are built into the language
when user: login is activated {
  print "User " + user.name + " logged in"
}

# Emit events directly
user is { name: "Alice" }
emit user: login with user
```

**Key Differences:**
- Events are first-class language features
- No need for event emitter classes
- Cleaner syntax for event handling
- Type safety for event data

---

## Common Patterns and Idioms

### Pipeline Pattern

Use the pipe operator for data transformation:

```patlang
# Data processing pipeline
result is raw_data
  |> validate_input
  |> transform_format
  |> filter_valid_records
  |> enrich_with_metadata
  |> save_to_database

# Error handling in pipelines
result is try
  data |> risky_operation |> another_risky_operation
catch Error as e
  default_value
end
```

### Builder Pattern with Fluent Interface

```patlang
make a template called QueryBuilder {
  QueryBuilder has:
    table_name - text = ""
    where_clauses - list = []
    order_clauses - list = []
    limit_value - number = 0
    
  from takes: table - text
  from returns: {
    table_name becomes table
    self
  }
  
  where takes: condition - text
  where returns: {
    where_clauses.append(condition)
    self
  }
  
  order_by takes: column - text
  order_by returns: {
    order_clauses.append(column)
    self
  }
  
  limit takes: count - number
  limit returns: {
    limit_value becomes count
    self
  }
  
  build returns: {
    query is "SELECT * FROM " + table_name
    
    if where_clauses.length > 0 then
      query = query + " WHERE " + where_clauses.join(" AND ")
    end
    
    if order_clauses.length > 0 then
      query = query + " ORDER BY " + order_clauses.join(", ")
    end
    
    if limit_value > 0 then
      query = query + " LIMIT " + limit_value
    end
    
    query
  }
}

# Usage
query is QueryBuilder.new()
  .from("users")
  .where("age > 18")
  .where("active = true")
  .order_by("name")
  .limit(10)
  .build()
```

### Observer Pattern with Events

```patlang
# Traditional observer pattern made simple with events
make a template called UserService {
  create_user takes: user_data - object
  create_user returns: {
    user is User.new(user_data)
    
    # Multiple observers can listen to this event
    emit user: created with user
    
    user
  }
}

# Multiple observers
when user: created is activated {
  # Email service observer
  send_welcome_email(user)
}

when user: created is activated {
  # Analytics service observer
  track_user_registration(user)
}

when user: created is activated {
  # Audit service observer
  log_user_creation(user)
}
```

### Command Pattern with Goals

```patlang
# Commands as goals with undo capability
make a goal called transfer_money {
  transfer_money requires:
    from_account - BankAccount
    to_account - BankAccount
    amount - number
    
  transfer_money is achieved when:
    from_account.balance >= amount and
    to_account is active and
    amount > 0
    
  transfer_money runs: {
    # Store state for undo
    original_from_balance is from_account.balance
    original_to_balance is to_account.balance
    
    # Execute transfer
    from_account.balance becomes from_account.balance - amount
    to_account.balance becomes to_account.balance + amount
    
    # Return undo function
    {
      from_account.balance becomes original_from_balance
      to_account.balance becomes original_to_balance
    }
  }
}

# Execute with automatic undo capability
undo_function is activate transfer_money with [account1, account2, 100]

# Later, if needed
if should_rollback then
  undo_function()
end
```

### Repository Pattern with Logic Programming

```patlang
make a template called UserRepository {
  UserRepository has:
    users - list of User = []
    
  find_by_criteria takes: criteria - object
  find_by_criteria returns: {
    # Use logic programming for complex queries
    query matches_criteria(user, criteria) returns:
      (criteria.name is nil or user.name.contains(criteria.name)) and
      (criteria.min_age is nil or user.age >= criteria.min_age) and
      (criteria.max_age is nil or user.age <= criteria.max_age) and
      (criteria.department is nil or user.department == criteria.department) and
      (criteria.active is nil or user.active == criteria.active)
    end
    
    users.filter(|user| matches_criteria(user, criteria))
  }
}

# Usage
criteria is {
  name: "John",
  min_age: 25,
  department: "Engineering",
  active: true
}

matching_users is repository.find_by_criteria(criteria)
```

---

## Troubleshooting and FAQ

### Common Errors and Solutions

#### Type Mismatch Errors

**Error:**
```
TypeMismatchError: Expected number, got text in function 'calculate_total'
```

**Solution:**
```patlang
# Wrong:
result is calculate_total("100")

# Right:
result is calculate_total(to_number("100"))

# Or with explicit type conversion:
amount is "100"
numeric_amount is amount.to_number()
result is calculate_total(numeric_amount)
```

#### Goal Dependency Errors

**Error:**
```
GoalError: Cannot achieve goal 'send_email' - requirement 'email_body' not satisfied
```

**Solution:**
```patlang
# Make sure all goal requirements are defined or can be achieved
make a goal called email_body {
  email_body requires:
    user_input - text
    template - text
    
  email_body is achieved when:
    user_input is not empty and
    template is loaded
    
  email_body runs: {
    format_email(user_input, template)
  }
}

# Then the parent goal can succeed
activate send_email with [recipient, subject]
```

#### Event Handler Not Triggered

**Problem:** Event handlers not executing when events are emitted.

**Solution:**
```patlang
# Make sure event handlers are defined before events are emitted
when user: login is activated {
  print "User logged in: " + user.name
}

# Event emission comes after handler definition
emit user: login with current_user
```

#### Logic Programming Query Failures

**Problem:** Logic queries not returning expected results.

**Solution:**
```patlang
# Make sure facts are defined before queries
parent(john, mary).
parent(mary, susan).

# Then define rules
relationship X is grandparent of Y requires:
  X is parent of Z and Z is parent of Y.

# Then query
query find_grandparents returns:
  X is grandparent of Y.
end
```

### Performance Tips

#### Functional Programming Performance

```patlang
# Instead of multiple passes through data:
result is data
  |> map(transform1)
  |> map(transform2)
  |> filter(condition1)
  |> filter(condition2)

# Combine operations:
result is data
  |> map(|item| transform2(transform1(item)))
  |> filter(|item| condition1(item) and condition2(item))
```

#### Goal Optimization

```patlang
# Cache expensive goal results
make a goal called expensive_calculation {
  expensive_calculation requires:
    input_data - list
    
  expensive_calculation is achieved when:
    input_data is not empty
    
  expensive_calculation runs: {
    # Cache result to avoid recalculation
    cache_key is "calc_" + hash(input_data)
    cached_result is cache.get(cache_key)
    
    if cached_result then
      cached_result
    else
      result is perform_expensive_calculation(input_data)
      cache.set(cache_key, result)
      result
    end
  }
}
```

### Debugging Tips

#### Print Debugging

```patlang
# Use print statements in pipelines
result is data
  |> (|x| { print "After validation: " + x; x })
  |> validate_data
  |> (|x| { print "After transformation: " + x; x })
  |> transform_data
```

#### Goal Debugging

```patlang
make a goal called debug_goal {
  debug_goal requires:
    data - any
    
  debug_goal is achieved when:
    data is not nil
    
  debug_goal runs: {
    print "Goal activated with data: " + data
    print "Processing step 1..."
    step1_result is process_step1(data)
    print "Step 1 result: " + step1_result
    print "Processing step 2..."
    final_result is process_step2(step1_result)
    print "Final result: " + final_result
    final_result
  }
}
```

### Frequently Asked Questions

**Q: When should I use goals vs functions?**

A: Use goals when you have complex dependencies that need to be resolved automatically, or when you want declarative programming. Use functions for straightforward data transformation and computation.

**Q: How do I choose between OOP and functional approaches?**

A: Use OOP for modeling domain entities with state and behavior. Use functional programming for data transformation and computation. Patlang lets you mix both naturally.

**Q: Can I use all paradigms in the same function?**

A: Yes! Patlang is designed for seamless paradigm integration. You can use OOP objects, functional transformations, goal activation, event emission, and logic queries all in the same function.

**Q: How does error handling work across paradigms?**

A: Patlang's try/catch works across all paradigms. Goals can fail and trigger catch blocks, events can carry error information, and logic queries can be wrapped in error handling.

**Q: Is Patlang suitable for large applications?**

A: Yes, Patlang's multi-paradigm approach and strong type system make it excellent for large applications. The ability to use the right paradigm for each problem leads to more maintainable code.

---

## Next Steps

Congratulations! You've learned the fundamentals of Patlang's multi-paradigm programming. Here's how to continue your journey:

### Immediate Next Steps

1. **Practice Examples**: Work through the examples in this guide
2. **Experiment with Paradigms**: Try combining different paradigms in small projects
3. **Read the Language Reference**: Dive deeper into specific features
4. **Study Real-World Examples**: Examine the comprehensive examples for complex applications

### Building Real Applications

1. **Start Small**: Build simple applications using one or two paradigms
2. **Add Complexity**: Gradually introduce more paradigms as needed
3. **Focus on Integration**: Learn how paradigms work together naturally
4. **Test Driven Development**: Use Patlang's testing features to ensure code quality

### Advanced Topics to Explore

1. **Performance Optimization**: Learn about type system optimization and memory management
2. **Language Extensions**: Explore how to extend Patlang's capabilities
3. **Concurrent Programming**: Dive into advanced event-driven and parallel programming
4. **Domain-Specific Languages**: Use Patlang's flexibility to create DSLs

### Community and Resources

- **Language Reference**: Complete technical documentation
- **GitHub Repository**: Source code and issue tracking
- **Community Forum**: Discussion and help from other developers
- **Examples Repository**: Real-world applications and patterns

### Contributing to Patlang

Patlang is an open-source project in active development. Ways to contribute:

1. **Try the Language**: Use Patlang for your projects and provide feedback
2. **Report Issues**: Help improve the language by reporting bugs
3. **Contribute Examples**: Share interesting applications and patterns
4. **Improve Documentation**: Help make Patlang easier to learn
5. **Core Development**: Contribute to the interpreter and compiler

Welcome to the Patlang community! The multi-paradigm approach opens up new possibilities for expressing complex problems clearly and maintainably. Happy coding!

---

*This guide is part of the official Patlang documentation. For updates and more resources, visit the project repository.*