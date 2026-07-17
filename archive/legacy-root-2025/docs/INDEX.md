# PaTLang v0.9 Documentation Index

Welcome to PaTLang - a pure C implementation compiler and runtime for the PaTLang language.

## Quick Navigation

### Getting Started
- **[../README.md](../README.md)** - Quick start guide
- **Start here:** `bin\patlang examples\hello_world.patlang`

### Learning by Example
- **[examples/README.md](../examples/README.md)** - Learn from 8 working examples
  - Basic: hello_world, arithmetic, logic
  - Intermediate: control flow, functions
  - Advanced: test framework (474 lines), build tool (488 lines)

### Understanding the System

#### IR Specification
- **[ir_spec.md](ir_spec.md)** - Complete bytecode instruction reference
  - All 30+ IR opcodes documented
  - Stack-based execution model
  - Examples for each instruction

#### Architecture & Design
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - How v0.9 was built and released
  - Architecture overview
  - Version history
  - Cross-platform deployment notes

#### Testing & Validation
- **[TEST_RUNNER_USAGE_GUIDE.md](TEST_RUNNER_USAGE_GUIDE.md)** - Run and write tests
  - Test discovery
  - Running test suites
  - Writing custom tests
  - Test framework usage

### Source Code

#### Key Files (in `../tools/compiler/`)

**ir_generator_v2.c** (940 lines)
- Hand-written lexer and recursive-descent parser
- Converts PaTLang source → IR bytecode
- Supports all language features

**runtime.c** (1,081 lines)
- Stack-based bytecode interpreter
- 30+ instruction implementations
- Variable scoping and function calls
- Exception handling

#### Building from Source
```bash
# IR Generator
clang -O2 -o ir_generator.exe ir_generator_v2.c

# Runtime
clang -O2 -o pat_runtime.exe runtime.c
```

## Feature Matrix

| Feature | Status | Example |
|---------|--------|---------|
| Variables | ✅ | `x = 5` |
| Arithmetic | ✅ | `x + y * 2` |
| Comparisons | ✅ | `x < 10 && y > 5` |
| If/Else | ✅ | `if x > 0 then ... end` |
| While Loops | ✅ | `while x < 10 do ... end` |
| For Loops | ✅ | `for item in list do ... end` |
| Functions | ✅ | `def add(a, b) do ... end` |
| Parameters | ✅ | `def f(x, y, z) do ... end` |
| Returns | ✅ | `return value` |
| Lambdas | ✅ | `fn(x) do x + 1 end` |
| Closures | ✅ | `fn() do x end` (captures x) |
| Arrays | ✅ | `[1, 2, 3, 4, 5]` |
| Try/Catch | ✅ | `try do ... catch e do ... end` |
| Throw | ✅ | `throw "error message"` |
| Print | ✅ | `print(value)` |

## Common Tasks

### Run a Program
```bash
bin\patlang your_file.patlang
```

### Run All Examples
```bash
bin\patlang examples\hello_world.patlang
bin\patlang examples\arithmetic_demo.pat
bin\patlang examples\control_flow_demo.pat
bin\patlang examples\function_demo.pat
bin\patlang examples\logic_demo.pat
```

### Study a Complex Example
```bash
# 474-line testing framework
bin\patlang examples\test_framework.patlang

# 488-line build tool
bin\patlang examples\buildtool.patlang
```

### Rebuild Executables
```bash
cd tools\compiler

# IR Generator
clang -O2 -o ir_generator.exe ir_generator_v2.c

# Runtime
clang -O2 -o pat_runtime.exe runtime.c
```

### Create Your Own Test Suite
```patlang
# my_tests.patlang - Copy from examples\test_framework.patlang
suite = create_test_suite("My Tests")

def test_math() do
  assert_equal(2 + 2, 4)
  assert_true(1 < 2)
end

suite = add_test(suite, "Math", fn() do test_math() end)
run_tests(suite)
```

## Architecture Overview

### Execution Pipeline
```
PaTLang Source (.patlang)
    ↓
[C IR Generator] - lexer + parser (ir_generator_v2.c)
    ↓
Intermediate Representation (JSON bytecode)
    ↓
[C Runtime] - bytecode interpreter (runtime.c)
    ↓
Program Output
```

### Runtime Environment
- **Stack-based:** Values pushed/popped for execution
- **Call Stack:** Function frames with parameter passing
- **Variables:** Lexical scoping with closure support
- **Exceptions:** Try/catch with throw
- **Functions:** Named functions and anonymous lambdas

## Performance Characteristics

| Operation | Time | Notes |
|-----------|------|-------|
| IR Generation | <100ms | Includes lexing and parsing |
| Simple Execution | <50ms | Basic math and I/O |
| Complex Programs | <200ms | With closures and exceptions |
| Test Framework Overhead | ~30ms | Per test suite |

## Debugging Tips

### If Something Goes Wrong

**"unknown function" error**
- Function must be defined before use
- Check spelling exactly
- See examples for correct syntax

**"IR_DIVIDE non-numeric" error**
- Both operands must be numbers
- Check variable values with `print()`

**"pop from empty stack" error**
- Usually incorrect parameter count
- Verify function definitions match calls

**"parse error" in output**
- Check syntax matches examples
- Valid: `if x > 0 then ... end` (with 'then' and 'end')
- Invalid: `if x > 0 { ... }` (Python syntax not supported)

### Enable Debugging
Add print statements to understand flow:
```patlang
def my_function(x) do
  print("DEBUG: x = ")
  print(x)
  result = x + 1
  print("DEBUG: result = ")
  print(result)
  return result
end
```

## Version Information

- **Version**: 0.9 (January 18, 2026)
- **Status**: Stable, production-ready
- **Implementation**: Pure C (no Ruby dependency)
- **Binaries**: Standalone Windows executables
- **Source Code**: C code compiles on Windows/Linux/Mac

## What's New in v0.9

✅ Pure C implementation (no Ruby)  
✅ 100% feature parity with Ruby version  
✅ All 7 core tests passing  
✅ Self-contained deployment package  
✅ Production-ready runtime  
✅ Cross-platform source code  

## Future Versions

**v0.10 (Planned)**
- Module system with imports
- Module caching for performance

**v0.11 (Planned)**
- Standard library functions
- Math, string, array utilities

**v1.0 (Target)**
- Feature complete
- Optimized compilation
- Production distributions

## Getting Help

### Examples First
Start with `examples/hello_world.patlang` and work up to advanced examples.

### Read the Source
Both C files are well-commented:
- `tools/compiler/ir_generator_v2.c` - How to parse
- `tools/compiler/runtime.c` - How to execute

### Study Working Code
The test framework (474 lines) shows real patterns:
- Data structures
- Function passing
- Closure usage
- Error handling

---

**For Issues or Questions:**
- Review examples in `examples/README.md`
- Check IR specification in `ir_spec.md`
- Study test framework patterns
- Read C source code comments

**Ready to build something?** Start with an example and modify it!
