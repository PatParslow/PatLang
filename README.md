# Patlang Programming Language

Patlang is an innovative programming language designed with incremental development principles, focusing on clear syntax, strong pattern matching capabilities, and goal-oriented programming constructs.

## Overview

Patlang introduces a unique approach to programming by combining:
- **Pattern-based syntax** for intuitive code structure
- **Goal-oriented constructs** that express intent clearly
- **Incremental development** support built into the language design
- **Strong type inference** with optional explicit typing
- **Functional and procedural** programming paradigms

## Quick Start

For a comprehensive introduction to Patlang, see:
- [`getting-started.md`](getting-started.md) - Complete tutorial and examples

## Documentation Structure

### Language Specification
- [`docs/language/Patlang.md`](docs/language/Patlang.md) - Core language specification
- [`docs/language/syntax.md`](docs/language/syntax.md) - Syntax reference and rules
- [`docs/language/language-reference.md`](docs/language/language-reference.md) - Complete language reference

### Development
- [`docs/development/developer-guide.md`](docs/development/developer-guide.md) - Developer setup and contribution guide
- [`docs/development/devplan.md`](docs/development/devplan.md) - Development roadmap
- [`docs/development/interpreter-architecture.md`](docs/development/interpreter-architecture.md) - Interpreter design and architecture

### Examples
- [`docs/examples/`](docs/examples/) - Language examples and use cases
  - Contract patterns, form handling, functional programming
  - Goal-oriented programming examples
  - Real-world application patterns

### Testing
- [`docs/testing/`](docs/testing/) - Comprehensive testing strategy
  - Test plans, categories, and infrastructure
  - Quality assurance processes

## Development Approach

Patlang is being developed using an **incremental approach**:

1. **Language Design** - Core syntax and semantics definition
2. **Parser Development** - Building the language parser
3. **Interpreter Core** - Basic execution engine
4. **Standard Library** - Essential language features
5. **Advanced Features** - Pattern matching, goal constructs
6. **Optimization** - Performance improvements

## Current Status

🎉 **v0.1.0 - Arithmetic Interpreter MVP Complete**

- ✅ Core language specification defined
- ✅ Syntax rules and patterns established
- ✅ Example programs written
- ✅ Testing strategy planned
- ✅ **Complete arithmetic interpreter with lexer, parser, and evaluator**
- ✅ **Interactive REPL for arithmetic expressions**
- ✅ **Comprehensive test suite (42+ tests, 140+ assertions)**
- ✅ **Support for integers, decimals, and all arithmetic operations**
- 🔄 Variables and assignment (next increment)
- ⏳ Advanced language features (planned)

## Try the Interpreter

The current arithmetic interpreter supports:

```bash
# Run the interactive REPL
ruby -Isrc src/patlang.rb

# Try these expressions:
42                    # => 42
3.14 + 2.86          # => 6.0
2 + 3 * 4            # => 14 (operator precedence)
(2 + 3) * 4          # => 20 (parentheses)
10 - 5 / 2           # => 7.5 (mixed operations)
```

**Supported Features:**
- Integer and decimal number literals
- Arithmetic operators: `+`, `-`, `*`, `/`
- Parentheses for grouping expressions
- Proper operator precedence and associativity
- Comprehensive error handling

## Getting Involved

1. Read the [Developer Guide](docs/development/developer-guide.md)
2. Review the [Language Specification](docs/language/Patlang.md)
3. Try the [Examples](docs/examples/)
4. Check the [Development Plan](docs/development/devplan.md)

## Project Structure

```
/
├── docs/
│   ├── language/          # Language specification and reference
│   ├── development/       # Developer guides and processes  
│   ├── testing/          # Test plans and strategies
│   └── examples/         # Language examples and use cases
├── src/                  # Future interpreter source code
├── test/                 # Test files and frameworks
├── tools/                # Build tools and scripts
├── getting-started.md    # Quick start guide
└── README.md            # This file
```

---

**Patlang** - A language designed for clarity, built for growth.