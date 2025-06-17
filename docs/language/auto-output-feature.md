# Automatic Console Output Feature

## Overview

Patlang now includes automatic console output functionality for standalone value expressions. This feature allows expressions that evaluate to values (without side effects like assignments or conditionals) to automatically display their results to the console, making interactive programming more intuitive.

## Feature Behavior

### What Auto-Outputs

Standalone expressions that evaluate to values automatically output to the console:

- **String literals**: `"Hello World"` → outputs: `Hello World`
- **Number literals**: `42` → outputs: `42.0`
- **Arithmetic expressions**: `5 + 3` → outputs: `8.0`
- **String concatenation**: `"Result: " + (10 * 2)` → outputs: `Result: 20`
- **Variable references**: `x` → outputs the value of x
- **Method calls**: `text.length` → outputs the length value

### What Does NOT Auto-Output

Control structures and assignments do not trigger automatic output:

- **Assignments**: `x = 42` → no output (assignment returns value internally)
- **Conditionals**: `if condition then value end` → no output 
- **Loops**: `while condition do body end` → no output
- **Function definitions**: `make function...` → no output

## Examples

### Basic Auto-Output
```patlang
# These expressions auto-output:
"Hello World"           # → Hello World
42                      # → 42.0
5 + 3                   # → 8.0
"Result: " + (10 * 2)   # → Result: 20
```

### Mixed Program
```patlang
# Assignment - no output
greeting = "Hello"
name = "World" 

# Auto-output expression
greeting + ", " + name + "!"   # → Hello, World!

# Assignment - no output  
length = 13

# Auto-output expression
"Message length: " + length    # → Message length: 13
```

### With Control Flow
```patlang
x = 10

# Conditional - no output
if x > 5 then
  result = "big number"
else
  result = "small number"
end

# Auto-output the result
result                          # → big number
```

## Implementation Details

### Architecture

The auto-output feature is implemented using three key components:

1. **AutoOutputNode**: New AST node type that wraps expressions requiring auto-output
2. **Parser Enhancement**: Modified [`statement()`](../src/parser.rb:162) method to detect standalone expressions
3. **Evaluator Enhancement**: New [`visit_auto_output_node()`](../src/evaluator.rb:691) method for handling output

### Detection Logic

The parser identifies standalone expressions by checking if a parsed expression falls through to the default [`expression()`](../src/parser.rb:226) handler rather than being handled by specific statement types (assignments, conditionals, etc.).

### Output Formatting

Values are formatted appropriately based on their data type:
- **Strings**: Output as-is (no quotes)
- **Numbers**: Convert to string representation  
- **Booleans**: Output as "true" or "false"
- **Nil**: Output as empty string
- **Other types**: Use `.to_s` method

## Technical Implementation

### Files Modified

- [`src/ast_nodes.rb`](../src/ast_nodes.rb): Added [`AutoOutputNode`](../src/ast_nodes.rb:196) class
- [`src/parser.rb`](../src/parser.rb): Modified [`statement()`](../src/parser.rb:162) method to wrap standalone expressions
- [`src/evaluator.rb`](../src/evaluator.rb): Added [`visit_auto_output_node()`](../src/evaluator.rb:691) method and case handling

### Testing

Comprehensive test suite in [`test/test_auto_output_functionality.rb`](../test/test_auto_output_functionality.rb) validates:
- Standalone expressions auto-output correctly
- Assignments and conditionals do not auto-output
- Mixed programs behave correctly
- Output formatting works for all data types

## Backward Compatibility

This feature is fully backward compatible:
- Existing Patlang programs continue to work unchanged
- No breaking changes to existing syntax
- Optional feature that enhances user experience

## Performance Impact

Minimal performance impact:
- Only affects parsing of standalone expressions  
- No overhead for assignments or control structures
- Output formatting is lightweight

## Future Enhancements

Potential improvements for future versions:
- Optional output formatting options
- Configurable auto-output enable/disable
- Custom output handlers for specific data types
- Integration with debugging and development tools

## Usage Guidelines

### Best Practices

1. **Interactive Development**: Use auto-output for quick debugging and exploration
2. **Program Results**: Display final calculations and results automatically
3. **Debugging**: Add standalone expressions to see intermediate values

### When to Use Assignments Instead

Use assignments when you need to:
- Store values for later use
- Avoid cluttering output with intermediate results
- Build complex expressions step by step

## Example: String Processing Demo

Here's how the auto-output feature enhances the string processing example:

```patlang
# Setup (no output)
text = "  Hello World Programming  "
length = text.length

# Auto-output results
"Original text: '" + text + "'"              # → Original text: '  Hello World Programming  '
"Length: " + length                          # → Length: 24

# Processing (no output)  
trimmed = text.trim()
upper = trimmed.uppercase()

# Auto-output results
"Trimmed: '" + trimmed + "'"                 # → Trimmed: 'Hello World Programming'
"Uppercase: '" + upper + "'"                 # → Uppercase: 'HELLO WORLD PROGRAMMING'
```

This feature makes Patlang programs more interactive and provides immediate feedback for expression evaluation, enhancing the development experience while maintaining clean separation between value expressions and control flow.