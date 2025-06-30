# PaTLang Build Tool - Usage Guide

## Overview

The PaTLang Build Tool is a sophisticated goal-oriented build system that leverages PaTLang's reasoning capabilities for intelligent dependency resolution, parallel execution, and adaptive build strategies.

## Installation & Setup

1. Ensure Ruby is installed on your system
2. Navigate to the PaTLang project directory
3. The build tool is located in the `build_tool/` directory
4. Make the CLI script executable: `chmod +x build_tool/patlang_build.rb`

## Basic Usage

### Command Line Interface

```bash
# Show help
ruby build_tool/patlang_build.rb --help

# Show version
ruby build_tool/patlang_build.rb --version

# Run demonstration
ruby build_tool/patlang_build.rb --demo

# Build with default build file (build.patlang)
ruby build_tool/patlang_build.rb

# Build with specific build file
ruby build_tool/patlang_build.rb -f my_project.build

# Build specific targets
ruby build_tool/patlang_build.rb compile test

# List available targets
ruby build_tool/patlang_build.rb -f build_tool/examples/simple_project.build --list

# Show dependency graph
ruby build_tool/patlang_build.rb -f build_tool/examples/simple_project.build --graph

# Clean build artifacts
ruby build_tool/patlang_build.rb --clean

# Verbose output
ruby build_tool/patlang_build.rb -v

# Disable parallel execution
ruby build_tool/patlang_build.rb --no-parallel
```

## Build File Format

Build files use PaTLang's goal-oriented DSL syntax:

### Basic Structure

```ruby
# Variables
var :src_dir, "src"
var :build_dir, "build"
var :test_dir, "test"

# Default targets
default :build, :test

# Target definitions
compile :compile_sources do
  description "Compile all source files"
  inputs glob("#{var(:src_dir)}/**/*.rb")
  outputs ["#{var(:build_dir)}/app.rb"]
  depends_on :clean
  parallel_safe true
  
  action do |target, context|
    # Build logic here
    puts "Compiling #{target.inputs.length} source files..."
    # ... compilation logic ...
    "Successfully compiled #{target.inputs.length} files"
  end
end

test :run_tests do
  description "Run all unit tests"
  depends_on :compile_sources
  inputs glob("#{var(:test_dir)}/**/*test*.rb")
  
  precondition "Dir.exist?('#{var(:build_dir)}')"
  postcondition "test_results[:passed] > 0"
  
  action do |target, context|
    # Test execution logic
    test_results = { total: 10, passed: 9, failed: 1 }
    context.set(:test_results, test_results)
    test_results
  end
end
```

### Target Types

1. **compile** - Compilation targets
2. **link** - Linking targets  
3. **test** - Test execution targets
4. **package** - Packaging targets
5. **clean** - Cleanup targets
6. **target** - Generic targets

### DSL Features

#### Variables
```ruby
var :project_name, "My Project"
var :version, "1.0.0"
var :dynamic_var do
  Time.now.strftime("%Y%m%d")
end
```

#### File Patterns
```ruby
inputs glob("src/**/*.rb")
inputs ["file1.rb", "file2.rb"]
outputs ["build/app.rb"]
```

#### Dependencies
```ruby
depends_on :compile_sources
depends_on :compile_sources, :prepare_environment
```

#### Conditions
```ruby
precondition "File.exist?('config.yml')"
postcondition "File.size('output.bin') > 1000"
```

#### Commands
```ruby
# Shell command
shell "gcc -o app main.c"

# Ruby block
action do |target, context|
  puts "Building #{target.name}..."
  # Custom build logic
  { status: :success, message: "Build completed" }
end
```

#### Build Properties
```ruby
parallel_safe true        # Enable parallel execution
incremental do |target, context|
  # Custom incremental check logic
  target.inputs.any? { |f| File.mtime(f) > File.mtime(target.outputs.first) }
end
```

## Examples

### Simple Project
See `build_tool/examples/simple_project.build` for a basic example with:
- Source compilation
- Test execution
- Packaging
- Installation

### Complex Project
See `build_tool/examples/complex_project.build` for advanced features:
- Multi-stage compilation
- Parallel execution
- Conditional logic
- Environment detection
- Advanced dependency management

## Key Features

### 1. Goal-Oriented Programming Integration
- Leverages PaTLang's reasoning system
- Intelligent strategy selection
- Adaptive build optimization

### 2. Advanced Dependency Resolution
- Automatic dependency graph generation
- Circular dependency detection
- Optimal build order calculation

### 3. Parallel Execution
- Automatic parallelization of independent targets
- Thread-safe execution
- Performance optimization

### 4. Incremental Builds
- Smart change detection
- Customizable incremental checks
- Efficient rebuilds

### 5. Rich DSL
- Intuitive syntax
- Ruby integration
- Powerful abstractions

### 6. Error Handling
- Comprehensive error reporting
- Graceful failure handling
- Detailed diagnostics

## Performance Tips

1. **Use Parallel Execution**: Mark targets as `parallel_safe true` when possible
2. **Optimize Dependencies**: Minimize unnecessary dependencies
3. **Incremental Builds**: Implement custom incremental checks for large projects
4. **File Patterns**: Use efficient glob patterns
5. **Caching**: Leverage the reasoning system's caching capabilities

## Troubleshooting

### Common Issues

1. **"Build file not found"**
   - Ensure build file exists and path is correct
   - Use `-f` option to specify custom build file

2. **"Circular dependency detected"**
   - Review target dependencies
   - Use dependency graph (`--graph`) to visualize

3. **"Target failed"**
   - Use verbose mode (`-v`) for detailed output
   - Check target preconditions and commands

4. **"Reasoning mode error"**
   - Ensure PaTLang core systems are properly initialized
   - Check reasoning coordinator configuration

### Debug Mode
```bash
ruby build_tool/patlang_build.rb -v -f my.build target_name
```

## Integration with PaTLang

The build tool seamlessly integrates with PaTLang's core systems:

- **Reasoning System**: For intelligent dependency resolution
- **Goal System**: For target definition and execution
- **Object Model**: For rich build context management
- **Error Handling**: For comprehensive failure management

## Contributing

To extend the build tool:

1. Add new target types in `build_tool/dsl/build_dsl.rb`
2. Implement custom strategies in `build_tool/core/build_runner.rb`  
3. Add reasoning integration in goal strategies
4. Test with `build_tool_test_suite.rb`

## API Reference

### BuildRunner
- `define_target(name, **options)` - Define a build target
- `build(targets)` - Execute build for specified targets
- `dependency_graph` - Get dependency graph
- `list_targets` - List all available targets
- `clean(targets)` - Clean build artifacts

### BuildDSL
- `quick_build(&block)` - Execute inline build definition
- `DSLLoader.execute_build_file(file, targets)` - Execute build file

See source code for complete API documentation.