# PaTLang Goal-Oriented Build Tool

A sophisticated build system that leverages PaTLang's goal-oriented programming and advanced reasoning capabilities to provide intelligent dependency resolution, parallel execution, and adaptive build strategies.

## 🎯 Key Features

### Goal-Oriented Architecture
- **Build targets as goals**: Each build target is a goal with preconditions, postconditions, and resolution strategies
- **Intelligent dependency resolution**: Uses PaTLang's reasoning system for sophisticated dependency analysis
- **Adaptive execution strategies**: Automatically selects optimal build strategies based on project characteristics

### Advanced Reasoning Integration
- **Dependency facts**: Build relationships expressed as logical facts for reasoning
- **Constraint satisfaction**: Preconditions and postconditions verified using constraint system
- **Dynamic optimization**: Real-time build plan adaptation based on changing conditions

### Parallel Execution & Performance
- **Intelligent parallelization**: Automatic detection of parallel-safe targets
- **Resource-aware scheduling**: Optimal resource allocation for build tasks
- **Incremental builds**: Smart change detection with goal-oriented invalidation

### Rich DSL
- **Ruby-based syntax**: Familiar and powerful build file definition
- **Conditional logic**: Environment-aware build configurations
- **Composable targets**: Modular and reusable build definitions

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Build DSL     │───▶│   BuildRunner    │───▶│ ReasoningCoord. │
│  (build files)  │    │  (orchestration) │    │  (intelligence) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   BuildGoal     │    │  DependencyRes.  │    │ AdvancedGoal    │
│ (target def.)   │    │   (resolution)   │    │  Strategies     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  BuildContext   │    │   FactsDatabase  │    │   Goal System   │
│ (environment)   │    │   (knowledge)    │    │ (execution)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### Installation
```bash
# Clone the PaTLang repository
git clone <repository-url>
cd patlang

# The build tool is ready to use
./build_tool/patlang_build.rb --help
```

### Basic Usage
```bash
# Run the demonstration
./build_tool/patlang_build.rb --demo

# Build with default targets
./build_tool/patlang_build.rb

# Build specific targets
./build_tool/patlang_build.rb compile test

# List available targets
./build_tool/patlang_build.rb --list

# Show dependency graph
./build_tool/patlang_build.rb --graph

# Clean build artifacts
./build_tool/patlang_build.rb --clean
```

## 📝 Build File Syntax

### Basic Structure
```ruby
# Variables
var :src_dir, "src"
var :build_dir, "build"
var :version, "1.0.0"

# Default targets
default :build, :test

# Target definitions
compile :compile_sources do
  description "Compile all source files"
  inputs glob("#{var(:src_dir)}/**/*.rb")
  outputs ["#{var(:build_dir)}/app.rb"]
  depends_on :clean
  parallel_safe true
  
  precondition "Dir.exist?('#{var(:src_dir)}')"
  postcondition "File.exist?('#{var(:build_dir)}/app.rb')"
  
  action do |target, context|
    # Build logic here
    puts "Compiling #{target.inputs.length} files..."
    # ... compilation logic ...
    "Compilation completed successfully"
  end
end
```

### Target Types
```ruby
# Compilation target
compile :compile_lib do
  inputs ["lib.c", "lib.h"]
  outputs ["lib.o"]
  shell "gcc -c lib.c -o lib.o"
end

# Linking target
link :link_app do
  depends_on :compile_lib
  inputs ["main.o", "lib.o"]
  outputs ["app"]
  shell "gcc main.o lib.o -o app"
end

# Test target
test :run_tests do
  depends_on :link_app
  inputs glob("test/**/*.rb")
  action do |target, context|
    # Run test suite
    test_results = run_test_suite(target.inputs)
    context.set(:test_results, test_results)
    test_results
  end
end

# Package target
package :create_package do
  depends_on :link_app, :run_tests
  outputs ["dist/app-#{var(:version)}.tar.gz"]
  shell "tar -czf dist/app-#{var(:version)}.tar.gz app"
end

# Clean target
clean :clean do
  remove var(:build_dir), "*.o", "*.log"
end
```

### Advanced Features
```ruby
# Conditional execution
when_condition ENV['RELEASE'] == 'true' do
  target :optimize do
    depends_on :compile_sources
    shell "optimizer --aggressive #{var(:build_dir)}/app.rb"
  end
end

# Custom incremental check
target :smart_compile do
  inputs glob("src/**/*.rb")
  outputs ["build/optimized.rb"]
  
  incremental do |target, context|
    # Custom logic to determine if rebuild needed
    source_changed = target.inputs.any? { |f| File.mtime(f) > target.get_last_built_time }
    config_changed = File.mtime("config/build.yml") > target.get_last_built_time
    source_changed || config_changed
  end
  
  action do |target, context|
    # Intelligent compilation with optimization
  end
end

# Parallel execution
target :parallel_modules do
  description "Build modules in parallel"
  parallel_safe true
  
  action do |target, context|
    # This target can run in parallel with other parallel-safe targets
  end
end

# Goal-oriented resolution
target :adaptive_build do
  strategy :performance_optimized
  
  action do |target, context|
    # Uses advanced goal strategies for optimization
  end
end
```

## 🔧 Integration with PaTLang Systems

### Reasoning System Integration
```ruby
# Build runner automatically integrates with reasoning coordinator
runner = BuildRunner.new(evaluator)

# Dependency facts are asserted automatically
runner.define_target(:app, dependencies: [:lib])
# → asserts "depends_on(app, lib)" as fact

# Query dependency relationships
runner.reasoning_coordinator.query("depends_on(app, X)")
# → returns all dependencies of 'app'
```

### Goal System Integration
```ruby
# Build targets are goals with full goal system support
target = BuildGoal.new(:compile, {
  preconditions: ["source_files_exist"],
  postconditions: ["output_file_valid"],
  strategy: :parallel_compile
})

# Goal resolution uses advanced strategies
result = target.resolve(context: build_context)
```

### Advanced Strategy Integration
```ruby
# Use advanced goal strategies for complex builds
runner.goal_strategies.execute_parallel_strategies(
  "parallel_build_strategy",
  strategy_definition,
  build_context
)

# Adaptive execution with real-time optimization
runner.goal_strategies.execute_adaptive_goal(
  "adaptive_optimization",
  optimization_config,
  build_context
)
```

## 📊 Example Projects

### Simple Project
See `build_tool/examples/simple_project.build`:
- Basic compilation and testing
- File operations and dependencies
- Incremental build support

### Complex Project  
See `build_tool/examples/complex_project.build`:
- Multi-stage compilation pipeline
- Parallel execution optimization
- Conditional builds and deployment
- Advanced goal-oriented strategies

## 🧪 Running the Demonstration

```bash
# Run complete demonstration
./build_tool/patlang_build.rb --demo

# Or run directly
ruby build_tool/demo/build_tool_demo.rb
```

The demonstration shows:
1. **Basic DSL Usage**: Simple target definition and execution
2. **Dependency Resolution**: Complex dependency chains with reasoning
3. **Parallel Execution**: Optimal parallel build strategies
4. **Goal-Oriented Strategies**: Advanced optimization techniques
5. **Real Build Files**: Execution of example build configurations

## 🎯 Use Cases

### Software Development
- **Multi-language projects**: Coordinate builds across different languages
- **Microservices**: Manage complex service dependencies
- **CI/CD pipelines**: Intelligent build optimization for continuous integration

### Research & Academia
- **Experiment pipelines**: Manage complex experimental workflows
- **Data processing**: Coordinate data transformation and analysis steps
- **Document generation**: Automated documentation and report generation

### System Administration
- **Configuration management**: Deploy and update system configurations
- **Infrastructure provisioning**: Coordinate resource allocation and setup
- **Monitoring setup**: Deploy monitoring and alerting systems

## 🔮 Advanced Features

### Intelligent Caching
- **Semantic caching**: Cache based on build semantics, not just file timestamps
- **Distributed caching**: Share build artifacts across team members
- **Dependency-aware invalidation**: Smart cache invalidation based on dependency changes

### Performance Optimization
- **Build profiling**: Detailed analysis of build performance bottlenecks
- **Resource optimization**: Automatic tuning of parallel execution
- **Predictive building**: Pre-build targets based on anticipated changes

### Extensibility
- **Plugin system**: Extend functionality with custom goal strategies
- **Language integration**: Support for domain-specific build requirements
- **Tool integration**: Connect with existing development tools and IDEs

## 🤝 Contributing

The PaTLang Build Tool is part of the larger PaTLang project. Contributions are welcome in areas such as:

- **New goal strategies**: Implement domain-specific build optimizations
- **Language support**: Add support for additional programming languages
- **Performance improvements**: Optimize build execution and reasoning
- **Documentation**: Improve examples and tutorials

## 📚 Further Reading

- **PaTLang Goal System**: Understanding goal-oriented programming concepts
- **Reasoning Coordinator**: Deep dive into the reasoning and constraint systems
- **Advanced Goal Strategies**: Sophisticated problem-solving techniques
- **Dependency Resolution**: Theory and implementation of dependency management

---

*The PaTLang Build Tool demonstrates the power of goal-oriented programming applied to practical software development challenges, providing a glimpse into the future of intelligent development tools.*