# Patlang Programming Language

Patlang is an innovative programming language designed with incremental development principles, focusing on clear syntax, strong pattern matching capabilities, and goal-oriented programming constructs.

## Overview

Patlang introduces a unique approach to programming by combining:
- **Pattern-based syntax** for intuitive code structure
- **Goal-oriented constructs** that express intent clearly
- **Incremental development** support built into the language design
- **Strong type inference** with optional explicit typing
- **Functional and procedural** programming paradigms

## Current Development Status

**Latest Release**: v0.2.0 Variables and Assignment (Production Ready)
**Current Phase**: v0.3.0 Control Flow Structures (Development Initiated)
**Strategic Goal**: Self-hosting capability - implementing Patlang in Patlang

### v0.3.0 Progress
- ✅ **Planning Complete**: Comprehensive implementation plan established
- 🔄 **Phase 1**: Foundation - Tokens and AST (Ready to Begin)
- ⏳ **Phase 2**: Lexer Extensions (Pending)
- ⏳ **Phase 3**: Parser Grammar Extensions (Pending)
- ⏳ **Phase 4**: Evaluator Logic (Pending)
- ⏳ **Phase 5**: Comprehensive Testing (Pending)

**Target Features for v0.3.0**:
- Boolean values and variables (`true`, `false`)
- Comparison operators (`==`, `!=`, `<`, `>`, `<=`, `>=`)
- Conditional statements (`if`/`then`/`else`/`end`)
- While loops (`while`/`do`/`end`)
- Block statements with proper sequencing

For detailed development tracking, see:
- [`docs/development/v0.3.0-control-flow-plan.md`](docs/development/v0.3.0-control-flow-plan.md) - Complete implementation plan
- [`docs/development/v0.3.0-development-status.md`](docs/development/v0.3.0-development-status.md) - Live development progress
- [`docs/development/self-hosting-gap-analysis.md`](docs/development/self-hosting-gap-analysis.md) - Strategic self-hosting roadmap

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

🎉 **v0.2.0 - Variables and Assignment Complete**

- ✅ Core language specification defined
- ✅ Syntax rules and patterns established
- ✅ Example programs written
- ✅ Testing strategy planned
- ✅ **Complete arithmetic interpreter with lexer, parser, and evaluator**
- ✅ **Interactive REPL for arithmetic expressions**
- ✅ **Variables and assignment functionality**
- ✅ **REPL variable persistence across statements**
- ✅ **Comprehensive test suite (93 tests, 393 assertions, 97.27% coverage)**
- ✅ **Support for integers, decimals, and all arithmetic operations**
- ⏳ Advanced language features (next increment)

## Try the Interpreter

The current interpreter supports:

```bash
# Run the interactive REPL
ruby -Isrc src/patlang.rb

# Try these expressions:
42                    # => 42
3.14 + 2.86          # => 6.0
2 + 3 * 4            # => 14 (operator precedence)
(2 + 3) * 4          # => 20 (parentheses)
10 - 5 / 2           # => 7.5 (mixed operations)

# Variable assignment and usage:
x = 42               # => 42
y = 3.14             # => 3.14
x + y * 2            # => 48.28
result = (x + y) / 2 # => 22.57
result               # => 22.57
```

**Supported Features:**
- Integer and decimal number literals
- Arithmetic operators: `+`, `-`, `*`, `/`
- Variable assignment and lookup
- Variable persistence in REPL sessions
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