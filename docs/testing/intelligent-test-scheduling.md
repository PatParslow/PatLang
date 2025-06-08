# Intelligent Test Scheduling System for PATLANG

## Overview

The PATLANG Intelligent Test Scheduling System provides smart test selection and execution to optimize development workflows. Instead of always running the full test suite (1600+ tests), developers can run targeted tests based on changes, performance characteristics, and coverage requirements.

## Key Features

### 🚀 Multiple Scheduling Modes
- **Smoke Tests**: Critical functionality validation (~10 tests, < 30 seconds)
- **Fast Feedback**: Tests completing within time threshold (< 30 seconds default)
- **Targeted Tests**: Based on file changes and dependencies
- **Coverage-Driven**: Target specific coverage gaps
- **Git-Aware**: Tests for files changed since specific commit
- **Full Validation**: Complete suite with performance monitoring

### ⚡ Performance Optimization
- **Parallel Execution**: Independent test suites run concurrently
- **Result Caching**: Avoid redundant test runs
- **Progressive Execution**: Fail fast on critical issues
- **Memory Efficiency**: Optimized test loading and cleanup

### 🎯 Smart Test Selection
- **Dependency Mapping**: Understands which tests are affected by code changes
- **Performance Classification**: Fast, medium, slow, and very slow test categories
- **Priority Scoring**: Critical path testing prioritization
- **Pattern Matching**: Intelligent test discovery based on naming conventions

## Architecture

### Core Components

#### 1. Intelligent Test Scheduler (`test/intelligent_test_scheduler.rb`)
The main scheduling engine that:
- Manages different scheduling modes
- Handles parallel execution
- Implements caching strategies
- Tracks performance metrics

#### 2. Test Performance Analyzer (`test/test_performance_analyzer.rb`)
Analyzes test execution characteristics:
- Measures execution times
- Tracks memory usage
- Calculates complexity scores
- Provides optimization recommendations

#### 3. Test Dependency Mapper (`test/test_dependency_mapper.rb`)
Maps relationships between source files and tests:
- Static dependency analysis (require statements)
- Pattern-based dependency rules
- Coverage relationship analysis
- Reverse dependency mapping

#### 4. Smart Test Runner (`test/smart_test_runner.rb`)
Unified CLI interface that:
- Integrates all scheduling modes
- Provides comprehensive status reporting
- Manages system setup and validation
- Offers dry-run capabilities

## Usage

### Quick Start

1. **Setup the system** (one-time):
   ```bash
   rake test:setup_smart
   # OR
   ruby test/smart_test_runner.rb setup
   ```

2. **Run fast feedback tests** (most common):
   ```bash
   rake smart:fast
   # OR
   ruby test/smart_test_runner.rb run fast
   ```

### Scheduling Modes

#### Smoke Tests
Perfect for pre-commit validation:
```bash
rake smart:smoke
ruby test/smart_test_runner.rb run smoke
```
- **Time**: < 30 seconds
- **Tests**: ~10 critical functionality tests
- **Use case**: Quick validation before commits

#### Fast Feedback
Ideal for development workflow:
```bash
rake smart:fast
ruby test/smart_test_runner.rb run fast --threshold=30
```
- **Time**: < 30 seconds total
- **Tests**: All tests completing within threshold
- **Use case**: Rapid feedback during development

#### Targeted Tests
Smart selection based on changes:
```bash
rake smart:targeted
ruby test/smart_test_runner.rb run targeted
```
- **Time**: Variable based on changes
- **Tests**: Tests affected by recent file changes
- **Use case**: Testing impact of specific changes

#### Coverage-Driven
Target coverage gaps:
```bash
rake smart:coverage
ruby test/smart_test_runner.rb run coverage --coverage
```
- **Time**: Medium (depends on gaps)
- **Tests**: Tests targeting uncovered code
- **Use case**: Improving test coverage systematically

#### Git-Aware Testing
Test changes since specific commit:
```bash
rake smart:changed
ruby test/smart_test_runner.rb run changed --since=HEAD~3
```
- **Time**: Variable based on change scope
- **Tests**: Tests for files changed since reference
- **Use case**: Validating changes across multiple commits

#### Full Validation
Complete suite with optimization:
```bash
rake smart:full
ruby test/smart_test_runner.rb run full --parallel --coverage
```
- **Time**: Full suite duration with optimization
- **Tests**: All tests with intelligent scheduling
- **Use case**: Comprehensive validation for releases

### Advanced Options

#### Parallel Execution
```bash
ruby test/smart_test_runner.rb run fast --parallel
```
Automatically distributes tests across multiple workers for faster execution.

#### Coverage Analysis
```bash
ruby test/smart_test_runner.rb run targeted --coverage
```
Enables detailed coverage tracking and reporting.

#### Caching Control
```bash
ruby test/smart_test_runner.rb run fast --no-cache
```
Disables result caching to force fresh test execution.

#### Dry Run
```bash
ruby test/smart_test_runner.rb run targeted --dry-run
```
Shows which tests would be executed without actually running them.

## Performance Optimization

### Test Classification

Tests are automatically classified based on execution time:

- **🚀 Fast Tests** (< 1s avg): Ideal for smoke tests and fast feedback
- **🏃 Medium Tests** (1-5s avg): Good for targeted testing
- **🐌 Slow Tests** (5-15s avg): Suitable for parallel execution
- **🐌🐌 Very Slow Tests** (> 15s avg): Need optimization or special handling

### Caching Strategy

The system caches test results when:
- Test files haven't been modified
- Source dependencies haven't changed
- Test execution was successful
- Caching is enabled (default)

Cache hits provide immediate results, significantly reducing execution time for unchanged code.

### Parallel Execution

Tests are distributed across workers using:
- Load balancing based on estimated execution time
- Independent test suite identification
- Memory-efficient worker management
- Fail-fast behavior for critical test failures

## Dependency Mapping

### How It Works

The system builds a comprehensive map of relationships between source files and tests through:

1. **Static Analysis**: Parsing `require` and `require_relative` statements
2. **Pattern Matching**: Naming convention analysis (e.g., `lexer.rb` → `test_lexer.rb`)
3. **Directory Relationships**: Component-based dependencies
4. **Coverage Analysis**: Runtime dependency detection

### Dependency Rules

#### Infrastructure Tests
- **Dependencies**: `src/lexer.rb`, `src/parser.rb`, `src/token.rb`, `src/ast_nodes.rb`
- **Priority**: Highest (infrastructure changes affect everything)
- **Fast Tests**: Core lexer and parser functionality

#### Ruby Implementation Tests
- **Dependencies**: `src/object_model/`, `src/evaluator.rb`
- **Priority**: Medium (implementation-specific)
- **Fast Tests**: Object model and string operations

#### PATLANG Language Tests
- **Dependencies**: All `src/` files (end-to-end testing)
- **Priority**: Lower (integration tests)
- **Fast Tests**: Basic integration scenarios

## Configuration

### Scheduler Configuration (`test/scheduler_config.json`)

```json
{
  "fast_feedback_threshold": 30,
  "smoke_test_count": 10,
  "parallel_workers": 4,
  "cache_enabled": true,
  "git_tracking": true,
  "categories": {
    "infrastructure": {
      "priority": 1,
      "fast_tests": ["test_lexer.rb", "test_parser.rb"],
      "smoke_tests": ["test_lexer.rb"],
      "dependencies": ["src/lexer.rb", "src/parser.rb"]
    }
  }
}
```

### Performance Tuning

#### Fast Feedback Threshold
Adjust based on your development workflow:
```bash
ruby test/smart_test_runner.rb run fast --threshold=15  # More aggressive
ruby test/smart_test_runner.rb run fast --threshold=60  # More inclusive
```

#### Parallel Workers
Optimize for your system:
```json
{
  "parallel_workers": 8  // For powerful development machines
}
```

#### Cache Settings
Control caching behavior:
```json
{
  "cache_enabled": true,
  "cache_ttl": 3600  // Cache validity in seconds
}
```

## Integration with Development Workflow

### Git Hooks

#### Pre-commit Hook
```bash
#!/bin/sh
# .git/hooks/pre-commit
ruby test/smart_test_runner.rb run smoke
if [ $? -ne 0 ]; then
  echo "❌ Smoke tests failed - commit aborted"
  exit 1
fi
```

#### Pre-push Hook
```bash
#!/bin/sh
# .git/hooks/pre-push
ruby test/smart_test_runner.rb run targeted
```

### CI/CD Integration

#### Staged Test Execution
```yaml
# .github/workflows/test.yml
jobs:
  smoke:
    runs-on: ubuntu-latest
    steps:
      - name: Smoke Tests
        run: ruby test/smart_test_runner.rb run smoke
  
  targeted:
    needs: smoke
    runs-on: ubuntu-latest
    steps:
      - name: Targeted Tests
        run: ruby test/smart_test_runner.rb run targeted
  
  full:
    needs: targeted
    runs-on: ubuntu-latest
    steps:
      - name: Full Validation
        run: ruby test/smart_test_runner.rb run full --parallel
```

### IDE Integration

#### VS Code Tasks
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Smart Test: Fast",
      "type": "shell",
      "command": "ruby test/smart_test_runner.rb run fast",
      "group": "test",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": false,
        "panel": "shared"
      }
    }
  ]
}
```

## Monitoring and Reporting

### System Status
```bash
rake test:smart_status
ruby test/smart_test_runner.rb status
```

Shows:
- Test organization status
- Performance data availability
- Dependency mapping coverage
- Git integration status
- Recent execution history

### Performance Analysis
```bash
rake test:analyze
ruby test/smart_test_runner.rb analyze
```

Provides:
- Test execution time analysis
- Performance classification
- Bottleneck identification
- Optimization recommendations

### Execution Reports

The system generates comprehensive reports including:
- Test selection rationale
- Execution times and success rates
- Cache hit rates
- Performance trends
- Coverage impact

## Troubleshooting

### Common Issues

#### "No tests affected by changes"
**Problem**: Targeted mode finds no relevant tests
**Solution**: 
- Ensure dependency mapping is built: `rake test:map`
- Check if changes are in tracked files
- Fall back to smoke tests

#### "Slow test execution"
**Problem**: Tests taking longer than expected
**Solution**:
- Run performance analysis: `rake test:analyze`
- Check for bottleneck tests
- Consider parallel execution: `--parallel`

#### "Cache issues"
**Problem**: Stale cached results
**Solution**:
- Disable cache temporarily: `--no-cache`
- Clear cache directory: `rm -rf test/cache/*`
- Check file modification times

### Debug Mode

Enable verbose output for troubleshooting:
```bash
ruby test/smart_test_runner.rb run targeted --verbose --dry-run
```

## Performance Benefits

### Before Intelligent Scheduling
- **Full suite**: 15+ minutes
- **No change awareness**: All tests run regardless of changes
- **Sequential execution**: No parallelization
- **No caching**: Redundant test execution

### After Intelligent Scheduling
- **Smoke tests**: < 30 seconds
- **Fast feedback**: < 30 seconds 
- **Targeted tests**: 1-5 minutes (depending on changes)
- **Parallel execution**: 3-4x speedup on multi-core systems
- **Caching**: 80%+ cache hit rate for unchanged code

### Real-World Impact

For typical development workflows:
- **Daily development**: 90% faster feedback (30s vs 15+ minutes)
- **Pre-commit validation**: 95% faster (30s vs 15+ minutes)
- **CI/CD optimization**: 60% faster overall (staged execution)
- **Coverage-driven development**: Targeted testing improves efficiency

## Future Enhancements

### Planned Features
- **ML-based test selection**: Learn from historical failure patterns
- **Flaky test detection**: Identify and isolate unreliable tests
- **Resource usage optimization**: Memory and CPU usage tracking
- **Integration testing optimization**: Smart end-to-end test selection

### Extensibility
The system is designed for extension:
- **Custom scheduling modes**: Add domain-specific test strategies
- **Additional analyzers**: Integrate with external tools
- **Reporter plugins**: Custom reporting formats
- **Integration hooks**: Connect with external CI/CD systems

## Contributing

### Adding New Scheduling Modes
1. Extend `IntelligentTestScheduler` class
2. Add mode-specific logic
3. Update CLI interface
4. Add documentation and tests

### Improving Dependency Detection
1. Enhance `TestDependencyMapper`
2. Add new pattern rules
3. Integrate with static analysis tools
4. Test with various codebases

### Performance Optimization
1. Profile existing implementation
2. Identify bottlenecks
3. Implement optimizations
4. Validate improvements with benchmarks

---

*For more information about PATLANG testing strategy, see [test-strategy.md](test-strategy.md)*