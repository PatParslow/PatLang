# Patlang Concrete Syntax and Formal EBNF Grammar Specification

## Table of Contents
1. [Overview](#overview)
2. [Formal EBNF Grammar](#formal-ebnf-grammar)
3. [Concrete Syntax Examples](#concrete-syntax-examples)
4. [Operator Precedence Table](#operator-precedence-table)
5. [Syntax Guidelines](#syntax-guidelines)

## Overview

Patlang is a multi-paradigm programming language with natural language-inspired syntax. This specification defines the complete concrete syntax and formal grammar supporting object-oriented programming, functional programming, goal-oriented programming, event-based programming, logic programming, and contract programming.

### Design Principles
- **Near-English readability**: Minimize punctuation, use natural language constructs
- **Declarative approach**: Focus on *what* rather than *how*
- **Flexible block styles**: Support both `{}` and `begin...end` syntax
- **Multi-paradigm support**: Seamless integration of different programming paradigms

## Formal EBNF Grammar

### Lexical Tokens

```ebnf
(* Basic Tokens *)
IDENTIFIER      = letter, { letter | digit | "_" } ;
INTEGER         = digit, { digit } ;
FLOAT           = digit, { digit }, ".", digit, { digit } ;
STRING          = '"', { character - '"' }, '"' ;
CHARACTER       = "'", character, "'" ;
BOOLEAN         = "true" | "false" ;
NIL             = "nil" ;

(* Comments *)
COMMENT         = "#", { character - newline }, newline ;
BLOCK_COMMENT   = "/*", { character }, "*/" ;

(* Whitespace *)
WHITESPACE      = " " | "\t" | "\n" | "\r" ;

(* Operators *)
ASSIGNMENT      = "=" | "is" | "becomes" ;
COMPARISON      = "==" | "!=" | "<" | ">" | "<=" | ">=" | "is not" ;
ARITHMETIC      = "+" | "-" | "*" | "/" | "%" | "**" ;
LOGICAL         = "and" | "or" | "not" ;
BITWISE         = "&" | "|" | "^" | "<<" | ">>" | "~" ;

(* Keywords *)
KEYWORDS        = "make" | "a" | "an" | "called" | "when" | "if" | "else" | "then" 
                | "end" | "begin" | "for" | "while" | "do" | "break" | "continue"
                | "function" | "template" | "goal" | "list" | "class" | "module"
                | "requires" | "ensures" | "maintains" | "returns" | "takes"
                | "has" | "runs" | "achieved" | "activated" | "relationship"
                | "query" | "try" | "catch" | "finally" | "throw" | "import"
                | "export" | "where" | "satisfies" | "contains" | "in" ;

(* Delimiters *)
LPAREN          = "(" ;
RPAREN          = ")" ;
LBRACE          = "{" ;
RBRACE          = "}" ;
LBRACKET        = "[" ;
RBRACKET        = "]" ;
COMMA           = "," ;
DOT             = "." ;
COLON           = ":" ;
SEMICOLON       = ";" ;
PIPE            = "|" ;
ARROW           = "->" ;
```

### Program Structure

```ebnf
program             = { statement } ;

statement           = declaration 
                    | assignment
                    | expression_statement
                    | control_flow_statement
                    | event_handler
                    | logic_statement
                    | import_statement ;

declaration         = make_declaration
                    | relationship_declaration
                    | query_declaration ;

make_declaration    = "make", article, declaration_type, "called", IDENTIFIER, block ;

article             = "a" | "an" ;

declaration_type    = "template" | "function" | "goal" | "list" | "class" | "module" ;

block               = brace_block | begin_end_block ;

brace_block         = "{", { statement }, "}" ;

begin_end_block     = "begin", { statement }, "end" ;
```

### Type System Syntax

```ebnf
type_annotation     = "-", type_expression ;

type_expression     = basic_type
                    | list_type
                    | function_type
                    | generic_type
                    | union_type ;

basic_type          = "text" | "number" | "integer" | "float" | "boolean" 
                    | "date" | "time" | "email" | "id" | "any" ;

list_type           = "list", [ "of", type_expression ] ;

function_type       = type_expression, "->", type_expression ;

generic_type        = IDENTIFIER, "[", type_expression, { ",", type_expression }, "]" ;

union_type          = type_expression, "|", type_expression, { "|", type_expression } ;
```

### Expressions

```ebnf
expression          = logical_or_expression ;

logical_or_expression = logical_and_expression, { "or", logical_and_expression } ;

logical_and_expression = equality_expression, { "and", equality_expression } ;

equality_expression = relational_expression, { equality_operator, relational_expression } ;

equality_operator   = "==" | "!=" | "is" | "is not" ;

relational_expression = additive_expression, { relational_operator, additive_expression } ;

relational_operator = "<" | ">" | "<=" | ">=" ;

additive_expression = multiplicative_expression, { additive_operator, multiplicative_expression } ;

additive_operator   = "+" | "-" ;

multiplicative_expression = power_expression, { multiplicative_operator, power_expression } ;

multiplicative_operator = "*" | "/" | "%" ;

power_expression    = unary_expression, [ "**", power_expression ] ;

unary_expression    = [ unary_operator ], primary_expression ;

unary_operator      = "+" | "-" | "not" | "~" ;

primary_expression  = literal
                    | IDENTIFIER
                    | function_call
                    | array_access
                    | member_access
                    | grouped_expression
                    | block_expression ;

literal             = INTEGER | FLOAT | STRING | CHARACTER | BOOLEAN | NIL
                    | array_literal | object_literal ;

array_literal       = "[", [ expression, { ",", expression } ], "]" ;

object_literal      = "{", [ property, { ",", property } ], "}" ;

property            = IDENTIFIER, ":", expression ;

function_call       = IDENTIFIER, "(", [ argument_list ], ")" ;

argument_list       = expression, { ",", expression } ;

array_access        = expression, "[", expression "]" ;

member_access       = expression, ".", IDENTIFIER ;

grouped_expression  = "(", expression, ")" ;

block_expression    = "|", [ parameter_list ], "|", expression ;

parameter_list      = IDENTIFIER, { ",", IDENTIFIER } ;
```

### Template and Class Definitions

```ebnf
template_body       = template_field_list | template_method_list ;

template_field_list = IDENTIFIER, "has", ":", field_definition, { field_definition } ;

field_definition    = IDENTIFIER, type_annotation, [ default_value ] ;

default_value       = "=", expression ;

template_method_list = method_definition, { method_definition } ;

method_definition   = IDENTIFIER, function_signature, [ contract_clauses ], block ;

function_signature  = [ "takes", ":", parameter_definitions ], 
                      [ "returns", ":", type_expression ] ;

parameter_definitions = parameter_definition, { parameter_definition } ;

parameter_definition = IDENTIFIER, type_annotation ;

contract_clauses    = requires_clause | ensures_clause | maintains_clause ;

requires_clause     = "requires", ":", condition_list ;

ensures_clause      = "ensures", ":", condition_list ;

maintains_clause    = "maintains", ":", condition_list ;

condition_list      = condition, { condition } ;

condition           = expression ;
```

### Goal-Oriented Programming

```ebnf
goal_definition     = "make", "a", "goal", "called", IDENTIFIER, goal_body ;

goal_body           = "{", goal_clauses, "}" | "begin", goal_clauses, "end" ;

goal_clauses        = { goal_clause } ;

goal_clause         = goal_requires
                    | goal_achieved
                    | goal_runs ;

goal_requires       = IDENTIFIER, "requires", ":", dependency_list ;

dependency_list     = dependency, { dependency } ;

dependency          = IDENTIFIER, type_annotation ;

goal_achieved       = IDENTIFIER, "is", "achieved", "when", ":", condition_list ;

goal_runs           = IDENTIFIER, "runs", ":", statement_list ;

statement_list      = statement, { statement } ;
```

### Event-Based Programming

```ebnf
event_handler       = "when", event_specification, block ;

event_specification = object_event | simple_event ;

object_event        = IDENTIFIER, ":", event_name, [ "is", event_action ] ;

simple_event        = event_name, [ "is", event_action ] ;

event_name          = IDENTIFIER ;

event_action        = IDENTIFIER | "activated" | "entered" | "changed" | "completed" ;
```

### Logic Programming

```ebnf
logic_statement     = fact_declaration | rule_declaration | query_declaration ;

fact_declaration    = fact_expression, "." ;

fact_expression     = natural_language_fact | predicate_fact ;

natural_language_fact = IDENTIFIER, "is", IDENTIFIER, "'s", IDENTIFIER ;

predicate_fact      = IDENTIFIER, "(", [ term_list ], ")" ;

term_list           = term, { ",", term } ;

term                = IDENTIFIER | literal ;

rule_declaration    = "relationship", rule_head, "requires", ":", rule_body ;

rule_head           = IDENTIFIER, "is", IDENTIFIER, "of", IDENTIFIER ;

rule_body           = rule_condition, { "and", rule_condition } ;

rule_condition      = fact_expression | negated_condition ;

negated_condition   = IDENTIFIER, "is", "not", IDENTIFIER ;

query_declaration   = "query", IDENTIFIER, [ "(", parameter_list, ")" ], query_body, "end" ;

query_body          = IDENTIFIER, "returns", ":", query_pattern ;

query_pattern       = fact_expression ;
```

### Control Flow

```ebnf
control_flow_statement = if_statement
                       | while_statement
                       | for_statement
                       | try_statement
                       | break_statement
                       | continue_statement
                       | return_statement ;

if_statement        = "if", expression, "then", statement_list,
                      { "elsif", expression, "then", statement_list },
                      [ "else", statement_list ], "end" ;

while_statement     = "while", expression, "do", statement_list, "end" ;

for_statement       = "for", IDENTIFIER, "in", expression, "do", statement_list, "end"
                    | "for", "each", IDENTIFIER, "in", expression, ":", statement_list ;

try_statement       = "try", statement_list,
                      { "catch", IDENTIFIER, statement_list },
                      [ "finally", statement_list ], "end" ;

break_statement     = "break" ;

continue_statement  = "continue" ;

return_statement    = "returns", [ expression ] ;
```

### Assignments and Statements

```ebnf
assignment          = IDENTIFIER, assignment_operator, expression ;

assignment_operator = "=" | "is" | "becomes" ;

expression_statement = expression ;
```

## Concrete Syntax Examples

### Variable Declarations and Assignments

```patlang
# Basic variable declarations
make a number called age { age is 25 }
make a text called name { name is "John Doe" }
make a boolean called is_active { is_active is true }

# Type-inferred declarations
make a variable called count { count is 0 }

# Assignments
age becomes 26
name is "Jane Smith"
is_active = false
```

### Function Definitions

```patlang
# Simple function with begin...end
make a function called square begin
  square takes:
    x - number
  square returns:
    x * x
end

# Function with braces
make a function called add {
  add takes:
    a - number
    b - number
  add returns:
    a + b
}

# Function with contracts
make a function called divide {
  divide takes:
    dividend - number
    divisor - number
  divide requires:
    divisor is not 0
  divide ensures:
    result is number
  divide returns:
    dividend / divisor
}
```

### Class and Template Definitions

```patlang
# Ruby-inspired OOP
make a template called Person {
  Person has:
    name - text
    age - number
    email - email = ""
    
  Person maintains:
    age >= 0
    name is not empty
    
  greet takes:
    other - Person
  greet returns:
    "Hello " + other.name + ", I'm " + name
}

# Inheritance
make a template called Employee {
  Employee inherits from Person
  Employee has:
    employee_id - id
    department - text
    
  get_info returns:
    name + " works in " + department
}
```

### Expressions and Operators

```patlang
# Arithmetic expressions
result is (a + b) * c / d
power is base ** exponent

# Logical expressions  
is_valid is age >= 18 and name is not empty
can_proceed is has_permission or is_admin

# Comparison expressions
is_equal is first_name == last_name
is_different is value1 != value2
is_older is person1.age > person2.age

# String operations
full_name is first_name + " " + last_name
greeting is "Hello, #{name}!"

# Array operations
numbers is [1, 2, 3, 4, 5]
first_item is numbers[1]  # 1-indexed
filtered is numbers where each item > 2
```

### Control Flow

```patlang
# If statements
if age >= 18 then
  print "You are an adult"
elsif age >= 13 then
  print "You are a teenager"
else
  print "You are a child"
end

# While loops
count is 1
while count <= 10 do
  print count
  count becomes count + 1
end

# For loops
for number in [1, 2, 3, 4, 5] do
  print "Number: " + number
end

for each item in shopping_list:
  print "Buy: " + item
```

### Block Syntax and Closures

```patlang
# Lambda expressions
square is |x| x * x
add_numbers is |a, b| a + b

# Higher-order functions
numbers is [1, 2, 3, 4, 5]
doubled is map(numbers, |x| x * 2)
evens is filter(numbers, |x| x % 2 == 0)
sum is reduce(numbers, |acc, x| acc + x, 0)

# Block passing to methods
with_file("data.txt") do |file|
  content is file.read()
  print content
end
```

### Goal-Oriented Programming

```patlang
make a goal called send_email {
  send_email requires:
    recipient - email
    subject - text
    body - text
    
  send_email is achieved when:
    recipient is valid
    subject is not empty
    body is not empty
    
  send_email runs:
    email_service.send(recipient, subject, body)
    log_email_sent(recipient)
}

# Goal dependencies
make a goal called prepare_report {
  prepare_report requires:
    gather_data
    analyze_data
    format_results
    
  prepare_report is achieved when:
    all dependencies are complete
    
  prepare_report runs:
    generate_final_report()
}
```

### Event-Based Programming

```patlang
# Object events
when user: login is activated {
  print "User logged in: " + user.name
  log_user_activity(user, "login")
}

when form: submit is activated {
  if form.is_valid then
    process_form_data(form)
  else
    show_validation_errors(form.errors)
  end
}

# Simple events
when file_uploaded {
  process_file(uploaded_file)
  send_notification("File processed")
}

when database: connection_lost {
  attempt_reconnection()
  log_error("Database connection lost")
}
```

### Logic Programming

```patlang
# Facts using natural language
Janet is John's parent.
John is Mary's parent.
Mary is Susan's parent.

# Facts using predicates
parent(janet, john).
parent(john, mary).
parent(mary, susan).

# Rules
relationship X is grandparent of Y requires:
  X is parent of Z and Z is parent of Y.

relationship X is sibling of Y requires:
  Z is parent of X and Z is parent of Y and X is not Y.

# Queries
query find_grandparents
  find_grandparents returns:
    X is grandparent of Y.
end

query are_siblings(A, B)
  are_siblings(A, B) returns:
    A is sibling of B.
end
```

### Contract Programming

```patlang
make a function called withdraw_money {
  withdraw_money takes:
    account - BankAccount
    amount - number
    
  withdraw_money requires:
    amount > 0
    account.balance >= amount
    account.is_active
    
  withdraw_money ensures:
    account.balance == old(account.balance) - amount
    transaction is logged
    
  withdraw_money returns:
    account.balance becomes account.balance - amount
    log_transaction(account, "withdrawal", amount)
    account.balance
}
```

### Error Handling

```patlang
try
  result is divide(10, 0)
  print "Result: " + result
catch DivisionByZeroError as error
  print "Cannot divide by zero: " + error.message
catch MathError as error
  print "Math error occurred: " + error.message
finally
  print "Calculation attempt completed"
end

# Throwing errors
if balance < 0 then
  throw InsufficientFundsError("Balance cannot be negative")
end
```

### Module System

```patlang
# Importing modules
import Math from "std/math"
import { Calculator, Operations } from "utils/calculator"

# Exporting from a module
export make a function called fibonacci {
  fibonacci takes:
    n - integer
  fibonacci returns:
    if n <= 1 then n else fibonacci(n-1) + fibonacci(n-2) end
}

# Namespace usage
result is Math.sqrt(25)
calculator is Calculator.new()
sum is calculator.add(5, 3)
```

### Array and Object Literals

```patlang
# Arrays (1-indexed)
numbers is [1, 2, 3, 4, 5]
mixed is ["text", 42, true, nil]
nested is [[1, 2], [3, 4], [5, 6]]

# Objects
person is {
  name: "John Doe",
  age: 30,
  address: {
    street: "123 Main St",
    city: "Anytown",
    zip: "12345"
  }
}

# Array operations
first is numbers[1]
last is numbers[-1]
slice is numbers[2..4]  # [2, 3, 4]
```

### String Interpolation

```patlang
name is "Alice"
age is 25

# String interpolation
greeting is "Hello, #{name}! You are #{age} years old."
calculation is "The result of 2 + 3 is #{2 + 3}."

# Multi-line strings
poem is """
  Roses are red,
  Violets are blue,
  Patlang is readable,
  And functional too!
"""
```

## Operator Precedence Table

| Precedence | Operators | Associativity | Description |
|------------|-----------|---------------|-------------|
| 1 (highest) | `()` `[]` `.` | Left | Function calls, array access, member access |
| 2 | `**` | Right | Exponentiation |
| 3 | `+` `-` `not` `~` | Right | Unary plus, minus, logical not, bitwise not |
| 4 | `*` `/` `%` | Left | Multiplication, division, modulo |
| 5 | `+` `-` | Left | Addition, subtraction |
| 6 | `<<` `>>` | Left | Bitwise shift |
| 7 | `&` | Left | Bitwise AND |
| 8 | `^` | Left | Bitwise XOR |
| 9 | `\|` | Left | Bitwise OR |
| 10 | `<` `<=` `>` `>=` | Left | Relational comparison |
| 11 | `==` `!=` `is` `is not` | Left | Equality comparison |
| 12 | `and` | Left | Logical AND |
| 13 | `or` | Left | Logical OR |
| 14 | `=` `is` `becomes` | Right | Assignment |
| 15 (lowest) | `,` | Left | Comma operator |

## Syntax Guidelines

### Block Style Guidelines

**Use `{}` braces when:**
- The block content is short (1-3 lines)
- Defining simple data structures or short functions
- Inline expressions or lambda definitions
- Template field definitions

**Use `begin...end` when:**
- The block content is longer (4+ lines)
- Complex logic or multiple statements
- Nested control structures
- When readability benefits from explicit begin/end markers

```patlang
# Short blocks use braces
make a function called double { double takes: x - number; double returns: x * 2 }

# Longer blocks use begin...end
make a function called complex_calculation begin
  complex_calculation takes:
    data - list
  
  if data.length > 100 then
    result is process_large_dataset(data)
  else
    result is process_small_dataset(data)
  end
  
  complex_calculation returns: result
end
```

### Statement Termination Rules

- **Optional semicolons**: Statements can be terminated with semicolons but it's not required
- **Newlines as terminators**: Line breaks serve as statement terminators in most contexts
- **Explicit continuation**: Use backslash `\` for line continuation when needed

```patlang
# All valid statement termination styles
name is "John"
age is 25;
result is very_long_function_name(parameter1, parameter2, \
                                 parameter3, parameter4)
```

### Naming Conventions

**Variables and Functions**: `snake_case`
```patlang
user_name is "Alice"
calculate_total_cost()
```

**Templates and Classes**: `PascalCase`
```patlang
make a template called UserAccount
make a template called DatabaseConnection
```

**Constants**: `SCREAMING_SNAKE_CASE`
```patlang
MAX_RETRY_ATTEMPTS is 3
DEFAULT_TIMEOUT is 30
```

**Goals and Events**: `snake_case`
```patlang
make a goal called send_notification
when user: login_successful
```

### Reserved Words

The following words are reserved and cannot be used as identifiers:

```
make, a, an, called, when, if, else, then, end, begin, for, while, do, break, 
continue, function, template, goal, list, class, module, requires, ensures, 
maintains, returns, takes, has, runs, achieved, activated, relationship, query, 
try, catch, finally, throw, import, export, where, satisfies, contains, in, 
and, or, not, is, true, false, nil
```

### Type Annotation Guidelines

**Explicit annotations for clarity:**
```patlang
make a function called process_user {
  process_user takes:
    user_id - id
    preferences - UserPreferences
    options - list of text
}
```

**Type inference when obvious:**
```patlang
count is 0              # Inferred as integer
name is "Alice"         # Inferred as text
active is true          # Inferred as boolean
```

**Union types for flexibility:**
```patlang
make a function called handle_response {
  handle_response takes:
    response - text | object | nil
}
```

### Comments and Documentation

```patlang
# Single-line comments use hash
make a function called calculate_tax {
  /*
   * Multi-line comments use C-style syntax
   * Useful for detailed explanations
   */
  calculate_tax takes:
    income - number      # Annual income amount
    rate - number        # Tax rate as decimal (0.0 to 1.0)
}
```

This specification provides a complete foundation for implementing the Patlang programming language with its natural language-inspired syntax, multi-paradigm features, and flexible block styles.