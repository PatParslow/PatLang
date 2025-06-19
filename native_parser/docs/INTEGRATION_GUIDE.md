# Integration Guide

## Overview

This guide explains how to integrate the Native PaTLang Parser with existing systems and components.

## Ruby Integration

### AST Compatibility
The native parser maintains full compatibility with Ruby evaluator expectations through automatic AST format conversion.

### Error Format Translation
Parse errors are automatically translated to Ruby-compatible format.

## Native Lexer Integration

### Token Stream Processing
The parser seamlessly integrates with the native lexer through standardized token format validation and conversion.

### Position Synchronization
Line and column tracking is automatically synchronized between lexer and parser.

## Evaluator Bridge

### AST Preparation
The parser prepares AST nodes for evaluation by preserving semantic information and runtime context.

### Performance Optimization
AST optimization passes ensure efficient evaluation performance.

## Usage Examples

```patlang
# Initialize native parser with lexer
lexer = create_native_lexer(input_text)
parser = create_native_parser(lexer)
ast = parse_program(parser)

# Convert for Ruby evaluator if needed
ruby_ast = convert_to_ruby_format(ast)
```

## Migration Strategy

The integration layer enables gradual migration from Ruby parser to native parser with full backward compatibility.