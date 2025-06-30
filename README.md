# Patlang Programming Language

Patlang is an innovative programming language designed with incremental development principles, focusing on clear syntax, strong pattern matching capabilities, and goal-oriented programming constructs.

## Overview

Patlang introduces a unique approach to programming by combining:
- **Pattern-based syntax** for intuitive code structure
- **Goal-oriented constructs** that express intent clearly
- **Incremental development** support built into the language design
- **Strong type inference** with optional explicit typing
- **Functional and procedural** programming paradigms

## ⚠️ Architecture Migration Notice

**Patlang has migrated to a new modular architecture!** If you're an existing user:

- **New Entry Point**: `ruby ruby-host/bootstrap/patlang_bootstrap.rb` (was `ruby src/patlang.rb`)
- **New Test Runner**: `ruby test/fixed_comprehensive_coverage_runner.rb`
- **Migration Guide**: See [`ARCHITECTURE_MIGRATION_GUIDE.md`](ARCHITECTURE_MIGRATION_GUIDE.md) for complete migration instructions

## Current Development Status

**Current Status**: Active Development - Solid Foundation (June 2025)
**Test Success Rate**: 40.7% (24/59 test files passing)
**Core Infrastructure**: 56% passing - solid foundation established
**Strategic Goal**: Building toward self-hosting capability

### 📊 Current Test Status Summary (June 2025)
Based on comprehensive test analysis ([`current-test-status.txt`](current-test-status.txt)):

**✅ Strong Foundation Areas (Working Well)**:
- **Core Infrastructure** (56% passing): Lexer, Parser, AST nodes, Facts database
- **Branch Coverage Testing** (100% passing): Conditional logic and error handling
- **Utility Components** (100% passing): Auto output, dependency mapping, performance analysis

**🚧 Partially Working Features**:
- **Language Features** (30% passing): Flexible function syntax, IS keyword implementation, basic evaluator
- **Ruby Implementation** (20% passing): Object model foundation exists but needs stability improvements

**🎯 Areas Under Development**:
- Integration layer reliability (0% passing)
- Helper components (errors need resolution)
- Test coverage improvement (currently 9.38% line coverage)

### ✅ Confirmed Working Features
- **Arithmetic expressions** with proper operator precedence
- **Lexer functionality** with comprehensive error handling
- **Parser core operations** for syntax analysis
- **AST node processing** for syntax tree manipulation
- **Facts database operations** for reasoning foundation
- **Flexible function syntax** (partial implementation)
- **IS keyword implementation** (partial functionality)
- **Branch coverage validation** (complete test suite)

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

## Current Capabilities

### ✅ Working Now
- **Basic arithmetic interpreter** with lexer, parser, and evaluator
- **Interactive REPL** for arithmetic expressions
- **Core infrastructure** components (lexer, parser, AST processing)
- **Comprehensive error handling** and bounds checking
- **Branch coverage testing** framework
- **Performance analysis** and dependency mapping tools

### 🚧 In Active Development
- **Variable assignment** and lookup (IS keyword partially working)
- **Function definitions** and calls (flexible syntax partially implemented)
- **Object model integration** (foundation exists, needs stability)
- **String operations** (architecture planned)
- **Control flow** constructs (parser support exists)

### 🎯 Architecture Completed
- Language specification and syntax rules
- Parser infrastructure and AST framework
- Reasoning system foundation
- Test infrastructure and coverage analysis
- Error handling and diagnostic systems

## Try the Current Interpreter

The current interpreter supports basic arithmetic evaluation:

```bash
# Run the interactive arithmetic REPL
ruby ruby-host/bootstrap/patlang_bootstrap.rb

# Try these working expressions in REPL:
42                    # => 42
3.14 + 2.86          # => 6.0
2 + 3 * 4            # => 14 (operator precedence)
(2 + 3) * 4          # => 20 (parentheses)
10 - 5 / 2           # => 7.5 (mixed operations)

# Exit the REPL
exit                 # => Goodbye!
```

### ✅ Currently Supported Features:
- **Arithmetic Operations**: Integer and decimal number literals with operators `+`, `-`, `*`, `/`
- **Expression Evaluation**: Parentheses for grouping with proper operator precedence
- **Interactive REPL**: Live arithmetic expression evaluation
- **Error Handling**: Comprehensive bounds checking and diagnostic messages

### 🚧 Partially Working (Under Development):
- **Variable Assignment**: IS keyword implementation (foundation exists)
- **Function Syntax**: Flexible function definitions (parser support exists)
- **String Operations**: Architecture designed (not yet integrated)
- **Control Flow**: Basic constructs (parser foundation exists)

### 📊 Test Status
Run the test suite to see current development progress:
```bash
# Run comprehensive tests (see current-test-status.txt for latest results)
ruby test/fixed_comprehensive_coverage_runner.rb

# Current status: 40.7% passing (24/59 test files)
# Strong areas: Core infrastructure (56% passing), Branch coverage (100% passing)
# Development areas: Integration layer, Ruby implementation stability
```

## Getting Involved

1. **Migration**: Read the [Architecture Migration Guide](ARCHITECTURE_MIGRATION_GUIDE.md) for updated paths and commands
2. **Development**: Read the [Developer Guide](docs/development/developer-guide.md) for contribution guidelines
3. **Language**: Review the [Language Specification](docs/language/Patlang.md) for syntax and features
4. **Architecture**: See the [Modular Architecture Overview](docs/architecture/MODULAR_ARCHITECTURE_OVERVIEW.md) for system design
5. **Examples**: Try the [Examples](docs/examples/) to see Patlang in action
6. **Planning**: Check the [Development Plan](docs/development/devplan.md) for roadmap

## Project Structure

```
/
├── patlang-core/         # Core language implementation
│   ├── ast/             # Abstract Syntax Tree nodes
│   ├── evaluator/       # Expression and statement evaluation
│   ├── lexer/           # Tokenization and lexical analysis
│   ├── object_model/    # Object system and type infrastructure
│   ├── parser/          # Syntax parsing and analysis
│   └── reasoning/       # Logic programming and constraint solving
├── ruby-host/           # Ruby bootstrap and runtime environment
│   ├── bootstrap/       # Language bootstrap and entry points
│   ├── interop/         # Ruby-Patlang interoperability
│   └── runtime/         # Runtime support and utilities
├── dev-tools/           # Development and build tools
│   ├── analysis/        # Code analysis tools
│   ├── build/           # Build scripts and VS Code extensions
│   ├── coverage/        # Coverage analysis tools
│   └── testing/         # Test runners and diagnostic tools
├── docs/
│   ├── language/        # Language specification and reference
│   ├── development/     # Developer guides and processes
│   ├── testing/         # Test plans and strategies
│   └── examples/        # Language examples and use cases
├── test/                # Comprehensive test suite
├── examples/            # Example programs and tutorials
├── getting-started.md   # Quick start guide
└── README.md           # This file
```

---

**Patlang** - A language designed for clarity, built for growth.