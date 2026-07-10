# PaTLang v0.9 Examples & Tools

This folder contains practical examples and tools written in PaTLang, demonstrating the language's capabilities.

## Quick Examples

### hello_world.patlang
Simplest test - basic arithmetic:
```bash
bin\patlang examples\hello_world.patlang
```
**Output:** `[OUT] 8`

### arithmetic_demo.pat
Demonstrates arithmetic operations:
- Addition, subtraction, multiplication, division
- Modulo operations
- Variable assignments

```bash
bin\patlang examples\arithmetic_demo.pat
```

### control_flow_demo.pat
Control flow examples:
- If/else statements
- While loops
- Nested conditions

```bash
bin\patlang examples\control_flow_demo.pat
```

### function_demo.pat
Function definitions and calls:
- Parameter passing
- Return values
- Recursive functions

```bash
bin\patlang examples\function_demo.pat
```

### logic_demo.pat
Logical operations:
- AND, OR, NOT operators
- Comparison chains
- Boolean expressions

```bash
bin\patlang examples\logic_demo.pat
```

## Advanced Examples

### test_framework.patlang
**A comprehensive testing framework written entirely in PaTLang**

Features:
- Test suite management
- Assertion checking
- Setup and teardown functions
- Test reporting
- Success/failure tracking

**Usage pattern:**
```patlang
suite = create_test_suite("My Tests")

suite = suite_setup(suite, fn() do
  print("Setting up test environment...")
end)

def my_test() do
  assert_equal(2 + 2, 4)
  assert_true(true)
  assert_not_nil("something")
end

suite = add_test(suite, "Basic Math", fn() do
  my_test()
end)

run_tests(suite)
```

**Why it's important:**
- Shows how to build complex systems in PaTLang
- Demonstrates closures, function passing, and data structures
- Useful for testing your own PaTLang programs
- 474 lines of pure PaTLang code

**Run it:**
```bash
bin\patlang examples\test_framework.patlang
```

### test_runner.patlang
**Automated test execution framework**

Features:
- Discovers test files
- Executes tests in sequence
- Collects and reports results
- Failure analysis

**Use this to:**
- Automate testing of your PaTLang programs
- Validate compiler changes
- Generate test reports

### buildtool.patlang
**Intelligent build orchestrator with multi-paradigm integration**

Features:
- Build target resolution
- Dependency graph management
- Parallel execution (design)
- Caching system
- Build configuration management

**Demonstrates:**
- Complex object modeling
- Goal-oriented programming patterns
- State management
- Error handling
- Recursive algorithms

**Size:** 488 lines of sophisticated PaTLang code

**Why it matters:**
- Shows PaTLang's capacity for building production tools
- Demonstrates multi-paradigm integration
- Real-world patterns applicable to other projects

**Run it:**
```bash
bin\patlang examples\buildtool.patlang
```

---

## Learning Path

### Beginner
1. Start with `hello_world.patlang`
2. Try `arithmetic_demo.pat`
3. Explore `logic_demo.pat`

### Intermediate
1. Study `control_flow_demo.pat`
2. Learn `function_demo.pat`
3. Understand closures in `test_framework.patlang`

### Advanced
1. Review `test_framework.patlang` - 474-line testing system
2. Study `test_runner.patlang` - test automation
3. Analyze `buildtool.patlang` - 488-line build system

---

## Documentation

- **[ir_spec.md](../docs/ir_spec.md)** - Intermediate Representation specification
- **[TEST_RUNNER_USAGE_GUIDE.md](../docs/TEST_RUNNER_USAGE_GUIDE.md)** - How to use the test runner
- **[DEPLOYMENT_GUIDE.md](../docs/DEPLOYMENT_GUIDE.md)** - Deployment and distribution

---

## Tips for Writing PaTLang Programs

### 1. Start with Data Structures
```patlang
my_list = [1, 2, 3, 4, 5]
my_dict = { "name": "value", "count": 42 }
```

### 2. Use Functions for Organization
```patlang
def helper_function(x, y) do
  return x + y
end
```

### 3. Leverage Closures
```patlang
def make_counter() do
  count = 0
  return fn() do
    count = count + 1
    return count
  end
end
```

### 4. Error Handling
```patlang
try do
  risky_operation()
catch error do
  print("Caught error: " + error)
end
```

### 5. Control Flow
```patlang
for item in list do
  if item > 5 then
    print(item)
  end
end
```

---

## Performance Notes

All examples are optimized for clarity, not raw speed. Performance characteristics:

- **hello_world.patlang**: <10ms
- **arithmetic_demo.pat**: <20ms
- **control_flow_demo.pat**: <30ms
- **function_demo.pat**: <50ms
- **test_framework.patlang**: <100ms (includes setup overhead)

For production use, consider:
- Caching compiled IR
- Pre-compiling frequently used modules
- Profiling bottleneck code

---

## Extending the Examples

### Adding Your Own Examples

1. Create `my_example.patlang` in this folder
2. Run it: `bin\patlang examples\my_example.patlang`
3. Share it: commit to git for others to learn from

### Using test_framework.patlang in Your Code

Copy the framework into your project:
```bash
cp examples\test_framework.patlang my_project\
```

Then use in your tests:
```patlang
# my_tests.patlang
# include "test_framework.patlang"  # If includes are supported

suite = create_test_suite("My Project Tests")
# ... add your tests
run_tests(suite)
```

---

## Troubleshooting

**"unknown function" error**
- Check spelling of function name
- Ensure function is defined before use
- For test_framework, make sure all helper functions are in scope

**"pop from empty stack"**
- Usually means missing function parameter
- Check function definitions match calls

**"unknown variable"**
- Verify variable is defined in accessible scope
- Remember PaTLang uses lexical scoping

---

## What's Next?

1. **Study the source code** - C implementations in `../tools/compiler/`
2. **Modify examples** - Try changing parameters, adding features
3. **Create your own tools** - Build utilities for your projects
4. **Contribute improvements** - Share useful examples and tools

---

**Version**: 0.9  
**Created**: January 18, 2026  
**Status**: Production-ready examples
