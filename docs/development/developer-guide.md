# Patlang Developer Contribution Guide

## Table of Contents

1. [Overview for Language Implementers](#overview-for-language-implementers)
2. [Development Environment Setup](#development-environment-setup)
3. [Git Workflow and Repository Structure](#git-workflow-and-repository-structure)
4. [Incremental Development Philosophy](#incremental-development-philosophy)
5. [Getting Started with Your First Contribution](#getting-started-with-your-first-contribution)
6. [Development Phases and Milestones](#development-phases-and-milestones)
7. [Testing Strategy for Contributors](#testing-strategy-for-contributors)
8. [Resources and Documentation](#resources-and-documentation)

---

## Overview for Language Implementers

Welcome to the Patlang implementation project! This guide is specifically for developers contributing to the **interpreter implementation**, not users of the language.

### What We're Building

Patlang is a revolutionary multi-paradigm programming language that seamlessly integrates:

- **Object-Oriented Programming** - Natural class definitions with design by contract
- **Functional Programming** - Higher-order functions, composition, and immutability
- **Goal-Oriented Programming** - Declarative dependency resolution
- **Event-Driven Programming** - First-class event handling and reactive patterns
- **Logic Programming** - Rule-based reasoning and constraint solving

### The Multi-Paradigm Integration Challenge

The core technical challenge is creating a unified runtime that allows these paradigms to work together naturally without friction. Key challenges include:

- **Type System Integration** - Ensuring type safety across paradigm boundaries
- **Memory Management** - Handling different memory models (immutable functional data vs mutable OOP objects)
- **Execution Model** - Coordinating procedural, declarative, and reactive execution
- **Error Handling** - Consistent error propagation across paradigms
- **Performance Optimization** - Maintaining efficiency while supporting multiple paradigms

### The 22-Week Development Timeline

Our implementation follows a structured 22-week development plan with clear phases:

- **Phase 1 (Weeks 1-4)**: Core Interpreter Infrastructure
- **Phase 2 (Weeks 5-8)**: Object-Oriented Implementation
- **Phase 3 (Weeks 9-12)**: Functional Programming Features
- **Phase 4 (Weeks 13-16)**: Goal-Oriented and Event-Driven Systems
- **Phase 5 (Weeks 17-20)**: Logic Programming Integration
- **Phase 6 (Weeks 21-22)**: Multi-Paradigm Integration and Optimization

---

## Development Environment Setup

### Ruby Version Requirements

Patlang is implemented in Ruby. Ensure you have the correct version:

```bash
# Required: Ruby 3.0 or higher
ruby --version
# Should output: ruby 3.0.0 or higher

# If you need to install Ruby 3.0+
# Using rbenv (recommended)
rbenv install 3.0.0
rbenv local 3.0.0

# Or using rvm
rvm install 3.0.0
rvm use 3.0.0
```

### Required Gems and Dependencies

Install the development dependencies:

```bash
# Clone the repository
git clone <repository-url>
cd patlang

# Install bundler if not present
gem install bundler

# Install project dependencies
bundle install

# Verify installation
bundle exec ruby --version
bundle exec rspec --version
```

### Essential Gems for Development

The project uses these key gems:

- **rspec** - Testing framework for TDD
- **simplecov** - Code coverage analysis
- **rubocop** - Code style and quality enforcement
- **yard** - Documentation generation
- **pry** - Debugging and REPL
- **benchmark-ips** - Performance testing

### IDE/Editor Recommendations

**VS Code Setup:**
```json
{
  "ruby.useLanguageServer": true,
  "ruby.lint": {
    "rubocop": true
  },
  "ruby.format": "rubocop",
  "files.associations": {
    "*.pat": "patlang"
  }
}
```

**Recommended Extensions:**
- Ruby LSP
- Ruby Solargraph
- GitLens
- Test Explorer

**Vim/Neovim:**
- Install `vim-ruby` plugin
- Configure with Solargraph LSP
- Set up [`rspec.vim`](https://github.com/thoughtbot/vim-rspec) for test running

### Testing Framework Setup

Verify your testing environment:

```bash
# Run all tests
bundle exec rspec

# Run with coverage
bundle exec rspec --format documentation

# Run specific test categories
bundle exec rspec spec/lexer_spec.rb
bundle exec rspec spec/parser_spec.rb
bundle exec rspec spec/interpreter_spec.rb

# Run performance tests
bundle exec rspec spec/performance_spec.rb

# Generate documentation
bundle exec yard doc
```

---

## Git Workflow and Repository Structure

### Repository Organization

```
patlang/
├── lib/                    # Core interpreter implementation
│   ├── patlang/
│   │   ├── lexer.rb       # Tokenization
│   │   ├── parser.rb      # AST generation
│   │   ├── interpreter.rb # Core execution engine
│   │   ├── type_system.rb # Type checking and inference
│   │   └── paradigms/     # Paradigm-specific implementations
│   │       ├── oop/       # Object-oriented features
│   │       ├── functional/ # Functional programming
│   │       ├── goals/     # Goal-oriented programming
│   │       ├── events/    # Event-driven programming
│   │       └── logic/     # Logic programming
├── spec/                  # Test suite
│   ├── unit/              # Unit tests
│   ├── integration/       # Integration tests
│   ├── acceptance/        # End-to-end tests
│   └── performance/       # Performance tests
├── docs/                  # Documentation
├── examples/              # Example programs
└── tools/                 # Development tools
```

### Branch Structure

**Main Branches:**
- [`main`](README.md) - Stable releases and integration
- [`develop`](README.md) - Active development integration
- [`feature/*`](README.md) - Individual feature development
- [`release/*`](README.md) - Release preparation
- [`hotfix/*`](README.md) - Critical bug fixes

### Feature Branch Naming Conventions

Use descriptive branch names following this pattern:

```bash
# Feature development
feature/lexer-string-interpolation
feature/oop-inheritance-support
feature/goal-dependency-resolution

# Bug fixes
bugfix/parser-array-indexing
bugfix/memory-leak-functional-calls

# Performance improvements
perf/optimize-ast-traversal
perf/reduce-goal-resolution-overhead

# Documentation
docs/update-contribution-guide
docs/add-paradigm-integration-examples

# Infrastructure
infra/setup-ci-pipeline
infra/add-performance-benchmarks
```

### Commit Message Standards

Follow conventional commits format:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat`: New feature implementation
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring without feature changes
- `test`: Adding or updating tests
- `perf`: Performance improvements
- `ci`: CI/CD pipeline changes

**Examples:**
```bash
feat(lexer): add support for string interpolation syntax

Implements tokenization for #{expression} syntax within string literals.
Handles nested expressions and escape sequences correctly.

Closes #123

fix(parser): resolve precedence issue with goal operators

The goal activation operator was incorrectly binding tighter than
function calls, causing parsing errors in complex expressions.

test(integration): add multi-paradigm integration test suite

Covers OOP-functional, goal-event, and logic-oop integration scenarios
to ensure seamless paradigm interoperation.
```

### Pull Request Process

1. **Create Feature Branch**
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/your-feature-name
   ```

2. **Development Cycle**
   ```bash
   # Make incremental commits
   git add .
   git commit -m "feat(component): implement initial structure"
   
   # Push regularly for backup
   git push origin feature/your-feature-name
   ```

3. **Pre-PR Checklist**
   ```bash
   # Run full test suite
   bundle exec rspec
   
   # Check code quality
   bundle exec rubocop
   
   # Verify documentation
   bundle exec yard doc
   
   # Update CHANGELOG if needed
   ```

4. **Create Pull Request**
   - Use descriptive title and detailed description
   - Reference related issues with `Closes #123`
   - Include testing instructions
   - Add [`paradigm:*`](README.md) labels for paradigm-specific changes

5. **Code Review Process**
   - At least one reviewer required
   - All tests must pass
   - Code coverage must not decrease
   - Documentation must be updated

### Integration Workflow

**Continuous Integration Checks:**
- All test suites pass (unit, integration, acceptance)
- Code coverage ≥ 90%
- RuboCop style checks pass
- Performance benchmarks within acceptable ranges
- Documentation builds successfully

**Merge Strategy:**
- Use "Squash and Merge" for feature branches
- Maintain clean, linear history on [`develop`](README.md)
- Tag releases on [`main`](README.md) with semantic versioning

---

## Incremental Development Philosophy

### "Known to Unknown" Development Approach

We follow a systematic approach where each step builds on proven foundations:

1. **Start with Simplest Case** - Implement the most basic version first
2. **Verify Completely** - Ensure current implementation is rock-solid
3. **Identify Next Increment** - Choose the smallest meaningful addition
4. **Implement and Test** - Add only what's needed for the next step
5. **Integrate and Validate** - Ensure the addition doesn't break existing functionality

### Small, Verifiable Steps Methodology

**Example: Implementing Function Calls**

❌ **Wrong Approach:**
```ruby
# Trying to implement everything at once
def evaluate_function_call(node)
  # Handle all possible cases: currying, partial application,
  # higher-order functions, default parameters, keyword arguments,
  # variable arguments, etc.
end
```

✅ **Right Approach:**
```ruby
# Step 1: Basic function calls only
def evaluate_function_call(node)
  function = evaluate(node.function)
  args = node.arguments.map { |arg| evaluate(arg) }
  function.call(*args)
end

# Step 2: Add parameter validation
def evaluate_function_call(node)
  function = evaluate(node.function)
  args = node.arguments.map { |arg| evaluate(arg) }
  validate_parameter_count(function, args)
  function.call(*args)
end

# Step 3: Add default parameters
# Step 4: Add type checking
# etc.
```

### Test-Driven Development Practices

**Red-Green-Refactor Cycle:**

1. **Red**: Write a failing test for the next small increment
2. **Green**: Write minimal code to make the test pass
3. **Refactor**: Clean up code while keeping tests green

**Example TDD Workflow:**

```ruby
# 1. RED: Write failing test
describe "Function calls" do
  it "calls function with no arguments" do
    code = "greet()"
    result = interpreter.evaluate(code)
    expect(result).to eq("Hello, World!")
  end
end

# 2. GREEN: Minimal implementation
def evaluate_function_call(node)
  if node.function.name == "greet" && node.arguments.empty?
    "Hello, World!"
  else
    raise NotImplementedError
  end
end

# 3. REFACTOR: Generalize while keeping tests green
def evaluate_function_call(node)
  function = resolve_function(node.function.name)
  args = node.arguments.map { |arg| evaluate(arg) }
  function.call(*args)
end
```

### Validation at Each Step

**Testing Levels:**
1. **Unit Tests** - Test individual components in isolation
2. **Integration Tests** - Test component interactions
3. **Acceptance Tests** - Test complete language features
4. **Performance Tests** - Ensure no regressions

**Validation Checklist for Each Increment:**
- [ ] All existing tests still pass
- [ ] New functionality has comprehensive tests
- [ ] Code coverage maintained or improved
- [ ] Performance benchmarks within acceptable range
- [ ] Documentation updated
- [ ] Integration with other paradigms verified

---

## Getting Started with Your First Contribution

### How to Pick Up a Task from the Development Plan

1. **Review Current Phase**
   ```bash
   # Check current development phase
   cat docs/devplan.md | grep -A 5 "Current Phase"
   
   # Look at open issues for current phase
   # Use GitHub labels: phase-1, phase-2, etc.
   ```

2. **Choose Appropriate Task Level**
   - **Beginner**: [`good-first-issue`](README.md) label, documentation, tests
   - **Intermediate**: Feature implementation, bug fixes
   - **Advanced**: Architecture, paradigm integration, performance

3. **Understand Dependencies**
   ```bash
   # Check what tasks are blocking/blocked
   # Review task dependencies in devplan.md
   # Ensure prerequisite features are complete
   ```

### Setting Up Your Feature Branch

```bash
# 1. Sync with latest development
git checkout develop
git pull origin develop

# 2. Create feature branch
git checkout -b feature/lexer-numeric-literals

# 3. Set up initial structure
mkdir -p spec/unit/lexer
touch spec/unit/lexer/numeric_literals_spec.rb
touch lib/patlang/lexer/numeric_token.rb

# 4. Make initial commit
git add .
git commit -m "feat(lexer): setup numeric literals implementation structure

- Add test file for numeric literal tokenization
- Add placeholder for NumericToken class
- Prepare for TDD implementation"
```

### Writing Tests First

**Start with acceptance test:**

```ruby
# spec/acceptance/numeric_literals_spec.rb
describe "Numeric Literals" do
  let(:interpreter) { Patlang::Interpreter.new }

  it "evaluates integer literals" do
    expect(interpreter.evaluate("42")).to eq(42)
  end

  it "evaluates float literals" do
    expect(interpreter.evaluate("3.14159")).to eq(3.14159)
  end

  it "evaluates scientific notation" do
    expect(interpreter.evaluate("1.23e4")).to eq(12300.0)
  end
end
```

**Add unit tests:**

```ruby
# spec/unit/lexer/numeric_literals_spec.rb
describe Patlang::Lexer do
  describe "numeric literal tokenization" do
    let(:lexer) { described_class.new }

    it "tokenizes integer literals" do
      tokens = lexer.tokenize("42")
      expect(tokens).to contain_exactly(
        have_attributes(type: :INTEGER, value: 42)
      )
    end

    it "tokenizes float literals" do
      tokens = lexer.tokenize("3.14")
      expect(tokens).to contain_exactly(
        have_attributes(type: :FLOAT, value: 3.14)
      )
    end
  end
end
```

### Implementation Approach

**Follow incremental implementation:**

1. **Make tests pass one by one**
2. **Implement minimal viable solution**
3. **Refactor for clarity and performance**
4. **Add edge case handling**
5. **Integrate with existing systems**

```ruby
# lib/patlang/lexer.rb
class Lexer
  def tokenize_number
    start_pos = @position
    
    # Start with integers only
    while current_char&.match?(/\d/)
      advance
    end
    
    # Add float support in next increment
    if current_char == '.'
      advance
      while current_char&.match?(/\d/)
        advance
      end
    end
    
    number_text = @source[start_pos...@position]
    value = number_text.include?('.') ? number_text.to_f : number_text.to_i
    
    Token.new(:NUMBER, value, start_pos)
  end
end
```

### Testing and Validation

**Run tests frequently:**

```bash
# Run your specific tests
bundle exec rspec spec/unit/lexer/numeric_literals_spec.rb

# Run related integration tests
bundle exec rspec spec/integration/lexer_parser_spec.rb

# Run full test suite before committing
bundle exec rspec

# Check code coverage
open coverage/index.html
```

**Performance validation:**

```bash
# Run performance tests if they exist
bundle exec rspec spec/performance/lexer_performance_spec.rb

# Profile your implementation
bundle exec ruby tools/profile_lexer.rb
```

### Committing and Creating Pull Requests

**Commit incrementally:**

```bash
# After each test passes
git add spec/unit/lexer/numeric_literals_spec.rb
git commit -m "test(lexer): add tests for integer literal tokenization"

git add lib/patlang/lexer.rb
git commit -m "feat(lexer): implement basic integer literal tokenization

- Recognize sequences of digits as integer tokens
- Convert token value to Ruby Integer
- Handle position tracking correctly"

# Continue with float support
git add spec/unit/lexer/numeric_literals_spec.rb
git commit -m "test(lexer): add tests for float literal tokenization"

git add lib/patlang/lexer.rb  
git commit -m "feat(lexer): add support for float literal tokenization

- Recognize decimal point in number sequences
- Convert to Ruby Float when decimal present
- Maintain backward compatibility with integers"
```

**Create comprehensive PR:**

```markdown
## Implement Numeric Literal Tokenization

### Summary
Adds support for tokenizing integer and float literals in the lexer, enabling basic numeric expressions in Patlang source code.

### Changes
- ✅ Integer literal tokenization (42, 0, 123)
- ✅ Float literal tokenization (3.14, 0.5, 42.0)
- ✅ Comprehensive test coverage
- ✅ Integration with existing lexer architecture

### Testing
- Unit tests for lexer tokenization
- Integration tests with parser
- Acceptance tests for end-to-end evaluation
- Performance benchmarks within acceptable range

### Next Steps
- Scientific notation support (follow-up PR)
- Hexadecimal/binary literal support (future enhancement)

Closes #45
```

---

## Development Phases and Milestones

### Overview of the 22-Week Phases

#### Phase 1: Core Interpreter Infrastructure (Weeks 1-4)
**Focus**: Foundation for all paradigms

**Key Deliverables:**
- Lexical analysis and tokenization
- Parser and AST generation
- Basic interpreter execution engine
- Type system foundation
- Error handling framework

**Entry Criteria:**
- Development environment set up
- Git workflow established
- Initial project structure created

**Exit Criteria:**
- Can parse and execute basic expressions
- All core infrastructure tests pass
- Type system handles primitive types
- Error reporting framework functional

**Weekly Breakdown:**
- Week 1: Lexer implementation
- Week 2: Parser and AST
- Week 3: Basic interpreter
- Week 4: Type system foundation

#### Phase 2: Object-Oriented Implementation (Weeks 5-8)
**Focus**: Classes, objects, inheritance, and design by contract

**Key Deliverables:**
- Class definition and instantiation
- Method calls and inheritance
- Instance variables and properties
- Design by contract (invariants, pre/post conditions)
- Object-oriented type checking

**Entry Criteria:**
- Phase 1 complete and stable
- Basic expressions work correctly
- Type system ready for extension

**Exit Criteria:**
- Full OOP feature set implemented
- Complex inheritance hierarchies work
- Design by contract enforced
- OOP integration tests pass

#### Phase 3: Functional Programming Features (Weeks 9-12)
**Focus**: Functions as first-class citizens, immutability, composition

**Key Deliverables:**
- Higher-order functions
- Lambda expressions and closures
- Function composition and currying
- Immutable data structures
- Functional collection operations

**Entry Criteria:**
- OOP implementation stable
- Function calls working
- Type system supports function types

**Exit Criteria:**
- Complete functional programming support
- Seamless OOP-functional integration
- Performance acceptable for functional operations

#### Phase 4: Goal-Oriented and Event-Driven Systems (Weeks 13-16)
**Focus**: Declarative programming and reactive systems

**Key Deliverables:**
- Goal definition and activation
- Dependency resolution engine
- Event system and handlers
- Integration between goals and events
- Asynchronous execution support

**Entry Criteria:**
- OOP and functional paradigms stable
- Type system supports declarative constructs

**Exit Criteria:**
- Goal-oriented programming fully functional
- Event system working with complex scenarios
- Goals and events integrate with OOP/functional code

#### Phase 5: Logic Programming Integration (Weeks 17-20)
**Focus**: Facts, rules, queries, and constraint solving

**Key Deliverables:**
- Fact and rule definition
- Query execution engine
- Unification and backtracking
- Integration with other paradigms
- Performance optimization

**Entry Criteria:**
- All other paradigms implemented
- Query syntax defined and parsed

**Exit Criteria:**
- Logic programming fully implemented
- Complex queries and rules work
- Integration with OOP/functional/goals/events

#### Phase 6: Multi-Paradigm Integration and Optimization (Weeks 21-22)
**Focus**: Seamless paradigm interoperation and performance

**Key Deliverables:**
- Cross-paradigm integration testing
- Performance optimization
- Memory management tuning
- Documentation completion
- Release preparation

**Entry Criteria:**
- All paradigms individually complete
- Basic integration working

**Exit Criteria:**
- All paradigms work together seamlessly
- Performance meets target benchmarks
- Complete test coverage
- Documentation ready for release

### How to Understand Where We Are in Development

**Check Current Status:**

```bash
# View current phase status
cat docs/devplan.md | grep -A 10 "Current Status"

# Check milestone progress
git log --oneline --grep="milestone"

# Review completed features
bundle exec rspec --tag=implemented

# See what's in progress
git branch -r | grep feature/

# Check upcoming tasks
cat docs/devplan.md | grep -A 20 "Next Milestones"
```

**Development Metrics:**

```bash
# Test coverage by component
bundle exec simplecov

# Performance benchmarks
bundle exec rspec spec/performance/ --format=documentation

# Code quality metrics
bundle exec rubocop --format=progress

# Documentation coverage
bundle exec yard stats
```

### Entry/Exit Criteria for Phases

**Phase Entry Checklist:**
- [ ] Previous phase 100% complete
- [ ] All previous phase tests passing
- [ ] Performance benchmarks met
- [ ] Documentation updated
- [ ] Integration tests with previous phases pass

**Phase Exit Checklist:**
- [ ] All phase deliverables implemented
- [ ] Comprehensive test coverage (≥90%)
- [ ] Performance within acceptable bounds
- [ ] Documentation complete and reviewed
- [ ] Integration with existing features verified
- [ ] Code review and approval completed

### Integration Points

**Weekly Integration:**
- Every Friday: merge completed features to [`develop`](README.md)
- Run full integration test suite
- Performance regression testing
- Update documentation

**Phase Integration:**
- End of each phase: comprehensive integration testing
- Cross-paradigm interaction verification
- Performance optimization review
- Architecture review and refactoring if needed

**Release Integration:**
- Every 4 phases: release candidate preparation
- Full system testing
- Performance benchmarking
- Security review
- Documentation finalization

---

## Testing Strategy for Contributors

### How to Run the Test Suite

**Full Test Suite:**
```bash
# Run all tests with coverage
bundle exec rspec --format=documentation

# Run with specific output format
bundle exec rspec --format=json --out=test_results.json

# Run tests in parallel (faster)
bundle exec parallel_rspec spec/
```

**Test Categories:**

```bash
# Unit tests only
bundle exec rspec spec/unit/

# Integration tests only  
bundle exec rspec spec/integration/

# Acceptance tests only
bundle exec rspec spec/acceptance/

# Performance tests only
bundle exec rspec spec/performance/

# Specific paradigm tests
bundle exec rspec --tag=oop
bundle exec rspec --tag=functional
bundle exec rspec --tag=goals
bundle exec rspec --tag=events
bundle exec rspec --tag=logic
```

**Focused Testing:**

```bash
# Test specific component
bundle exec rspec spec/unit/lexer_spec.rb

# Test specific feature
bundle exec rspec spec/integration/function_calls_spec.rb

# Test with specific tags
bundle exec rspec --tag=slow --tag=integration

# Test excluding certain tags
bundle exec rspec --tag=~slow
```

### Writing New Tests

**Test Structure:**

```ruby
# spec/unit/component/feature_spec.rb
require 'spec_helper'

describe Patlang::Component::Feature do
  # Use descriptive context blocks
  describe "#method_name" do
    context "when given valid input" do
      it "returns expected result" do
        # Arrange
        input = "test input"
        expected_output = "expected result"
        
        # Act
        result = subject.method_name(input)
        
        # Assert
        expect(result).to eq(expected_output)
      end
    end
    
    context "when given invalid input" do
      it "raises appropriate error" do
        expect { subject.method_name(nil) }.to raise_error(ArgumentError)
      end
    end
  end
end
```

**Test Categories and Tagging:**

```ruby
describe "Feature", :unit do
  # Tag tests by category
  it "basic functionality", :basic do
    # Test basic case
  end
  
  it "edge case handling", :edge_cases do
    # Test edge cases
  end
  
  it "error conditions", :error_handling do
    # Test error scenarios
  end
  
  it "performance requirements", :performance, :slow do
    # Performance-sensitive tests
  end
end
```

**Paradigm-Specific Test Patterns:**

```ruby
# OOP tests
describe "Class inheritance", :oop do
  let(:parent_class) { create_class("Parent") }
  let(:child_class) { create_class("Child", parent: parent_class) }
  
  it "inherits parent methods" do
    expect(child_class.instance_methods).to include(*parent_class.instance_methods)
  end
end

# Functional tests
describe "Higher-order functions", :functional do
  let(:map_function) { ->(fn, list) { list.map(&fn) } }
  let(:double_function) { ->(x) { x * 2 } }
  
  it "applies function to all elements" do
    result = map_function.call(double_function, [1, 2, 3])
    expect(result).to eq([2, 4, 6])
  end
end

# Goal-oriented tests
describe "Goal activation", :goals do
  let(:goal) { create_goal("test_goal", dependencies: ["dep1", "dep2"]) }
  
  it "resolves dependencies before execution" do
    expect(goal).to receive(:resolve_dependencies).ordered
    expect(goal).to receive(:execute).ordered
    goal.activate
  end
end
```

### Multi-Paradigm Integration Testing

**Cross-Paradigm Scenarios:**

```ruby
describe "Multi-paradigm integration", :integration do
  describe "OOP with functional programming" do
    it "allows functional operations on object collections" do
      # Create objects using OOP
      users = [
        User.new("Alice", 25),
        User.new("Bob", 30),
        User.new("Charlie", 35)
      ]
      
      # Use functional programming to process
      adult_names = users
        .filter { |user| user.age >= 18 }
        .map { |user| user.name }
        .sort
      
      expect(adult_names).to eq(["Alice", "Bob", "Charlie"])
    end
  end
  
  describe "Goals with events" do
    it "triggers events when goals complete" do
      goal = create_goal("send_email")
      event_fired = false
      
      # Set up event handler
      when_event("email:sent") { event_fired = true }
      
      # Activate goal
      goal.activate
      
      expect(event_fired).to be true
    end
  end
  
  describe "Logic programming with OOP" do
    it "queries object relationships using logic rules" do
      # Create objects
      alice = Person.new("Alice")
      bob = Person.new("Bob")
      
      # Define relationships using logic programming
      fact("parent(alice, bob)")
      rule("grandparent(X, Z) :- parent(X, Y), parent(Y, Z)")
      
      # Query using object instances
      result = query("grandparent(alice, ?)")
      expect(result).to include(bob)
    end
  end
end
```

### Performance Testing Considerations

**Benchmark Structure:**

```ruby
require 'benchmark/ips'

describe "Performance benchmarks", :performance do
  describe "lexer tokenization" do
    let(:large_source) { "x = 1\n" * 10000 }
    let(:lexer) { Patlang::Lexer.new }
    
    it "tokenizes large files efficiently" do
      Benchmark.ips do |x|
        x.report("tokenize 10k lines") do
          lexer.tokenize(large_source)
        end
        
        # Require minimum performance
        x.compare!
      end
    end
    
    it "memory usage stays reasonable" do
      before_memory = memory_usage
      lexer.tokenize(large_source)
      after_memory = memory_usage
      
      memory_increase = after_memory - before_memory
      expect(memory_increase).to be < 100.megabytes
    end
  end
  
  describe "multi-paradigm overhead" do
    it "paradigm switching has minimal overhead" do
      Benchmark.ips do |x|
        x.report("pure OOP") { execute_oop_code }
        x.report("pure functional") { execute_functional_code }
        x.report("mixed paradigms") { execute_mixed_code }
        
        x.compare!
      end
    end
  end
end
```

**Performance Regression Prevention:**

```ruby
# spec/performance/regression_spec.rb
describe "Performance regressions", :performance do
  # Baseline measurements stored in spec/fixtures/benchmarks/
  let(:baseline) { load_baseline_benchmarks }
  
  it "lexer performance doesn't regress" do
    current_performance = benchmark_lexer
    regression_threshold = 1.1 # 10% slower maximum
    
    expect(current_performance).to be < (baseline[:lexer] * regression_threshold)
  end
  
  it "memory usage doesn't increase significantly" do
    current_memory = benchmark_memory_usage
    memory_threshold = 1.05 # 5% increase maximum
    
    expect(current_memory).to be < (baseline[:memory] * memory_threshold)
  end
end
```

**Continuous Performance Monitoring:**

```bash
# Add to CI pipeline
bundle exec rspec spec/performance/ --tag=baseline

# Profile memory usage
bundle exec ruby tools/memory_profiler.rb

# Profile execution time
bundle exec ruby tools/time_profiler.rb

# Check for memory leaks
bundle exec ruby tools/leak_detector.rb
```

---

## Resources and Documentation

### Key Documentation Files

**Architecture and Design:**
- [`interpreter-architecture.md`](interpreter-architecture.md) - Core interpreter design and component interactions
- [`language-reference.md`](language-reference.md) - Complete language specification and grammar
- [`syntax.md`](syntax.md) - Detailed syntax rules and examples

**Development Planning:**
- [`devplan.md`](devplan.md) - 22-week development timeline and milestones  
- [`test-strategy.md`](test-strategy.md) - Comprehensive testing approach and standards
- [`test-plan.md`](test-plan.md) - Detailed test planning and categories

**Language Examples:**
- [`examples_to_cover.md`](examples_to_cover.md) - Core examples for each paradigm
- [`real-world-examples.md`](real-world-examples.md) - Complex multi-paradigm applications
- [`example_*.md`](example_form.md) files - Specific paradigm examples

### Language Specification Documents

**Core Language Features:**
- [`Patlang.md`](Patlang.md) - High-level language overview and philosophy
- [`language-reference.md`](language-reference.md) - Formal grammar and semantics
- [`syntax.md`](syntax.md) - Syntax rules and parsing guidelines

**Paradigm-Specific Specifications:**
- Object-Oriented: Class definition, inheritance, design by contract
- Functional: Higher-order functions, immutability, composition
- Goal-Oriented: Dependency resolution, declarative programming
- Event-Driven: Event handling, reactive patterns, asynchronous execution
- Logic Programming: Facts, rules, queries, unification

### Testing Documentation

**Testing Framework:**
- [`test-plan-overview.md`](test-plan-overview.md) - Overall testing strategy and approach
- [`test-categories.md`](test-categories.md) - Test categorization and organization  
- [`test-infrastructure.md`](test-infrastructure.md) - Testing tools and automation

**Quality Assurance:**
- Code coverage requirements (≥90%)
- Performance benchmarking standards
- Integration testing protocols
- Multi-paradigm testing strategies

### Communication Channels and Processes

**Development Communication:**
- **GitHub Issues**: Feature requests, bug reports, task tracking
- **Pull Requests**: Code review and integration discussion
- **GitHub Discussions**: Design decisions and architectural questions
- **Wiki**: Collaborative documentation and design notes

**Code Review Process:**
1. **Self-Review**: Use [`pre-commit`](README.md) hooks and local testing
2. **Peer Review**: At least one team member review required
3. **Architecture Review**: Senior developer review for major changes
4. **Integration Review**: Full team review for paradigm interactions

**Documentation Standards:**
- **Code Comments**: Document complex algorithms and paradigm interactions
- **Commit Messages**: Follow conventional commits format
- **PR Descriptions**: Include rationale, testing approach, and impact analysis
- **Architecture Decisions**: Document in ADR (Architecture Decision Records) format

### Quick Reference for Contributors

**Essential Commands:**
```bash
# Development workflow
git checkout develop && git pull origin develop
git checkout -b feature/your-feature
bundle exec rspec  # Run tests
bundle exec rubocop  # Check style
git commit -m "type(scope): description"
git push origin feature/your-feature

# Testing shortcuts
bundle exec rspec spec/unit/  # Unit tests only
bundle exec rspec --tag=oop  # OOP tests only  
bundle exec rspec --tag=slow --tag=~performance  # Slow tests, not performance

# Quality checks
bundle exec rubocop --auto-correct  # Fix style issues
bundle exec yard doc  # Generate documentation
open coverage/index.html  # View test coverage
```

**Key File Locations:**
- Core interpreter: [`lib/patlang/interpreter.rb`](lib/patlang/interpreter.rb)
- Lexer: [`lib/patlang/lexer.rb`](lib/patlang/lexer.rb)
- Parser: [`lib/patlang/parser.rb`](lib/patlang/parser.rb)
- Type system: [`lib/patlang/type_system.rb`](lib/patlang/type_system.rb)
- Paradigm implementations: [`lib/patlang/paradigms/`](lib/patlang/paradigms/)

**Getting Help:**
- Review existing tests for examples
- Check [`real-world-examples.md`](real-world-examples.md) for complex scenarios
- Search GitHub issues for similar problems
- Ask in GitHub Discussions for design questions
- Reference [`interpreter-architecture.md`](interpreter-architecture.md) for system understanding

---

## Getting Started Checklist

Ready to contribute? Follow this checklist:

### Environment Setup
- [ ] Ruby 3.0+ installed and configured
- [ ] Repository cloned and dependencies installed (`bundle install`)
- [ ] IDE/editor configured with Ruby support
- [ ] Git configured with your details
- [ ] Pre-commit hooks installed (if available)

### Understanding the Codebase  
- [ ] Read [`interpreter-architecture.md`](interpreter-architecture.md) for system overview
- [ ] Review [`devplan.md`](devplan.md) to understand current phase
- [ ] Examine existing tests to understand patterns
- [ ] Run full test suite successfully (`bundle exec rspec`)

### First Contribution
- [ ] Pick a [`good-first-issue`](README.md) from current phase
- [ ] Create feature branch with descriptive name
- [ ] Write failing tests first (TDD approach)
- [ ] Implement minimal solution to pass tests
- [ ] Ensure all tests pass and code quality checks succeed
- [ ] Create comprehensive pull request with description

### Integration
- [ ] Follow incremental development approach
- [ ] Test paradigm interactions if applicable
- [ ] Update documentation as needed
- [ ] Respond to code review feedback
- [ ] Celebrate your contribution to Patlang! 🎉

---

Welcome to the Patlang implementation team! Your contributions are helping build the next generation of multi-paradigm programming languages. Every small, incremental improvement brings us closer to a language that truly unifies programming paradigms in a natural, powerful way.

Remember: **think incrementally, test thoroughly, and integrate carefully**. The strength of Patlang lies not just in its individual features, but in how seamlessly they work together.

Happy coding! 🚀