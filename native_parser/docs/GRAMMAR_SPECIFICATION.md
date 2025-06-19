# PaTLang Grammar Specification

## Overview

This document provides the complete grammar specification for the Native PaTLang Parser, defining the formal syntax rules that govern how PaTLang programs are structured and parsed.

## Grammar Notation

The grammar uses Extended Backus-Naur Form (EBNF) notation:
- `|` denotes alternatives
- `*` denotes zero or more repetitions  
- `+` denotes one or more repetitions
- `?` denotes optional elements
- `()` groups elements
- `[]` denotes optional elements (alternative to `?`)

## Core Grammar Rules

### Program Structure

```ebnf
program = statement_list

statement_list = statement+

statement = assignment_statement
          | expression_statement  
          | function_definition
          | conditional_statement
          | while_statement
          | reasoning_statement
          | constraint_statement
```

### Expressions

```ebnf
expression = logical_or

logical_or = logical_and ("or" logical_and)*

logical_and = equality ("and" equality)*

equality = comparison (("==" | "!=") comparison)*

comparison = term (("<" | ">" | "<=" | ">=") term)*

term = factor (("+" | "-") factor)*

factor = unary (("*" | "/" | "%") unary)*

unary = ("not" | "-") unary | primary

primary = NUMBER
        | STRING  
        | TRUE
        | FALSE
        | IDENTIFIER
        | function_call
        | "(" expression ")"
```

### Statements

```ebnf
assignment_statement = IDENTIFIER "=" expression

expression_statement = expression

function_definition = "make" "a" "function" "called" IDENTIFIER 
                     parameter_clause? return_clause? 
                     function_body "end"

parameter_clause = "takes" parameter_list

parameter_list = IDENTIFIER ("," IDENTIFIER)*

return_clause = "returns" expression

function_body = statement_list

function_call = IDENTIFIER "(" argument_list? ")"

argument_list = expression ("," expression)*
```

### Control Flow

```ebnf
conditional_statement = "if" expression "then" statement_list 
                       else_clause? "end"

else_clause = "else" statement_list

while_statement = "while" expression "do" statement_list "end"
```

### Reasoning Constructs

```ebnf
reasoning_statement = fact_statement
                    | rule_statement  
                    | goal_statement
                    | reasoning_mode_statement

fact_statement = "fact" predicate "(" argument_list? ")"

rule_statement = "rule" rule_head ":-" rule_body

goal_statement = "goal" IDENTIFIER goal_body

reasoning_mode_statement = "reasoning" "mode" ("on" | "off")

rule_head = predicate "(" argument_list? ")"

rule_body = condition_list

condition_list = condition ("," condition)*

condition = predicate "(" argument_list? ")"

predicate = IDENTIFIER

goal_body = "{" goal_clauses "}"

goal_clauses = precondition_clause? postcondition_clause? strategy_clause?

precondition_clause = "precondition:" expression

postcondition_clause = "postcondition:" expression  

strategy_clause = "strategy:" IDENTIFIER
```

### Type Constraints

```ebnf
constraint_statement = "constrain" constraint_definition

constraint_definition = IDENTIFIER "::" type_specification constraint_conditions?

type_specification = type_name constraint_modifiers?

type_name = IDENTIFIER

constraint_modifiers = "extends" IDENTIFIER

constraint_conditions = "where" "{" condition_list "}"
```

## Operator Precedence

From highest to lowest precedence:

1. `not`, `-` (unary)
2. `*`, `/`, `%`
3. `+`, `-` (binary)
4. `<`, `>`, `<=`, `>=`
5. `==`, `!=`
6. `and`
7. `or`

## Associativity Rules

- All binary operators are left-associative except unary operators
- Unary operators (`not`, `-`) are right-associative

## Tokens

### Keywords

```
make, a, function, called, takes, returns, end, if, then, else, while, do,
fact, rule, goal, reasoning, mode, on, off, constrain, where, extends,
true, false, and, or, not
```

### Operators

```
+, -, *, /, %, ==, !=, <, >, <=, >=, =, :-, ::
```

### Delimiters

```
(, ), {, }, [, ], ,, ;
```

### Literals

```
NUMBER: [0-9]+ ("." [0-9]+)?
STRING: "\"" [^"]* "\""
IDENTIFIER: [a-zA-Z_][a-zA-Z0-9_]*
```

## Natural Language Constructs

PaTLang supports natural language syntax for improved readability:

- Function definitions: `make a function called name`
- Parameter specification: `takes param1, param2`
- Return specification: `returns expression`

## Grammar Extensions

The grammar is designed to be extensible for future language features:

- Additional control flow constructs
- Enhanced reasoning syntax
- Object-oriented features
- Module system

## Disambiguation Rules

1. **Identifier vs Keyword**: Keywords take precedence in their contexts
2. **Minus operator**: Context determines unary vs binary interpretation
3. **Parentheses**: Grouping takes precedence over function calls
4. **Natural language**: Keyword sequences must be complete and in order

## Error Recovery Points

The grammar defines synchronization points for error recovery:

- Statement boundaries (after `;`, `end`)
- Block boundaries (`{`, `}`)
- Expression boundaries (operators)
- End of file

## Compatibility Notes

This grammar maintains compatibility with the Ruby parser while extending capabilities for native parsing features.