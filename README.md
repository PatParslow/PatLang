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

**Latest Release**: v0.4.0 String Operations (Production Ready)
**Current Phase**: v0.5.0 Functions (Next Priority)
**Strategic Goal**: Self-hosting capability - implementing Patlang in Patlang

### 🎉 MAJOR ACHIEVEMENT: 100% Test Suite Success (June 2025)
**Milestone**: Complete elimination of all test failures through systematic approach
- **427 tests passing** with 1912 assertions, 0 failures, 0 errors
- **99.7% line coverage** with comprehensive validation
- **Sub-second execution** providing fast feedback for development
- **Robust foundation** for confident continued development

See [`docs/development/test-infrastructure-success.md`](docs/development/test-infrastructure-success.md) for full details.

### ✅ v0.4.0 Complete - String Operations
- ✅ **All Phases Complete**: Critical Blocker #2 RESOLVED
- ✅ **String literals with escape sequences** (`"Hello World"`, `"Line 1\nLine 2"`)
- ✅ **String concatenation** (`"Hello" + " " + "World"`)
- ✅ **String comparison operators** (`==`, `!=`, `<`, `>`, `<=`, `>=`)
- ✅ **Character indexing** (`string[1]`, `string[-1]` for last character)
- ✅ **String methods** (`.length`, `.uppercase()`, `.lowercase()`, `.trim()`, `.substring()`)
- ✅ **Advanced string methods** (`.starts_with()`, `.ends_with()`)
- ✅ **Method chaining** (`text.trim().uppercase().substring(1, 5)`)
- ✅ **File execution support** (`ruby src/patlang.rb examples/string_demo.pat`)

### 🎯 v0.5.0 Next - Functions (Critical Blocker #3)
**Strategic Priority**: Essential for modular code organization
**Target Features**:
- Function definition with parameters
- Return values and local scope
- Function calls and recursion
- Parameter passing and argument validation

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
ruby src/patlang.rb --repl

# Run a file
ruby src/patlang.rb examples/string_demo.pat

# Try these expressions in REPL:
42                    # => 42
3.14 + 2.86          # => 6.0
2 + 3 * 4            # => 14 (operator precedence)
(2 + 3) * 4          # => 20 (parentheses)

# Variable assignment and usage:
x = 42               # => 42
y = 3.14             # => 3.14
x + y * 2            # => 48.28

# String operations:
name = "Patlang"                    # => "Patlang"
version = "0.4.0"                   # => "0.4.0"
message = "Welcome to " + name      # => "Welcome to Patlang"
length = message.length             # => 17
first_char = name[1]                # => "P"
upper_name = name.uppercase()       # => "PATLANG"
formatted = name.trim().lowercase() # => "patlang"

# Control flow with strings:
if name.starts_with("Pat") then
  "Language name starts with Pat!"
else
  "Different language"
end
```

**Supported Features:**
- Integer and decimal number literals
- Arithmetic operators: `+`, `-`, `*`, `/`
- String literals with escape sequences
- String concatenation and comparison
- String methods: `.length`, `.uppercase()`, `.lowercase()`, `.trim()`, `.substring()`, `.starts_with()`, `.ends_with()`
- Character indexing with `[]` operator (1-based, negative indices supported)
- Variable assignment and lookup with persistence
- Boolean values and comparison operators
- Control flow: `if`/`then`/`else`/`end`, `while`/`do`/`end`
- Parentheses for grouping expressions
- Proper operator precedence and associativity
- Comprehensive error handling and bounds checking

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