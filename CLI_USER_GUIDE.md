# PaTLang CLI User Guide

## Overview

The PaTLang CLI is a professional command-line interface that provides multiple backend execution options for PaTLang programs. It supports `.pat` and `.patlang` file extensions and offers comprehensive debugging and analysis features.

## Installation

The CLI is located in `bin/patlang` and is executable directly:

```bash
./bin/patlang script.pat
```

## Quick Start

```bash
# Run a PaTLang program with default Ruby backend
patlang script.pat

# Use Phase 1 self-hosting bridge
patlang --backend phase1 script.pat

# Compare results across all available backends
patlang --compare script.pat

# Show detailed execution information
patlang --verbose --time script.pat
```

## Backend Options

### Ruby Backend (Default)
- **Command**: `--backend ruby` (default)
- **Description**: Uses the mature Ruby-based evaluator
- **Features**: Full PaTLang language support, reasoning mode for `.patlang` files
- **Availability**: Always available

### Phase 1 Self-Hosting Bridge
- **Command**: `--backend phase1`
- **Description**: Uses the Phase 1 self-hosting bridge with PaTLang evaluator
- **Features**: Demonstrates self-hosting capabilities
- **Availability**: Available when `native_evaluator/ruby_bridge.rb` exists

### Native Evaluator
- **Command**: `--backend native`
- **Description**: Compiled native evaluator for maximum performance
- **Features**: Fast execution, minimal memory usage
- **Availability**: Available when native evaluator is compiled

### Transpile Backend
- **Command**: `--backend transpile`
- **Description**: Transpiles PaTLang to C and compiles for native execution
- **Features**: Maximum performance, standalone executable generation
- **Availability**: Available when transpiler is implemented

## Command Line Options

### Backend Selection
```bash
-b, --backend BACKEND    Select backend: ruby, phase1, native, transpile
-c, --compare           Compare results across all available backends
```

### Output Options
```bash
-o, --output FILE       Save output to file (JSON format)
-q, --quiet            Suppress non-essential output
```

### Debugging Options
```bash
-v, --verbose          Enable verbose output
-d, --debug            Enable debug mode with detailed error information
-t, --time             Show execution timing and performance statistics
```

### Information
```bash
--version              Show version information
--backends             List available backends and their status
-h, --help             Show comprehensive help
```

## File Extension Support

- **`.pat`**: Standard PaTLang files
- **`.patlang`**: PaTLang files with automatic reasoning mode enabled

## Usage Examples

### Basic Execution
```bash
# Run a simple arithmetic program
patlang examples/arithmetic_demo.pat

# Run with verbose output
patlang --verbose examples/arithmetic_demo.pat
```

### Backend Comparison
```bash
# Compare all available backends
patlang --compare examples/arithmetic_demo.pat

# Output will show:
# - Success/failure for each backend
# - Execution times
# - Result consistency check
# - Performance comparison
```

### Performance Analysis
```bash
# Show detailed timing information
patlang --time --verbose script.pat

# Save results to JSON file for analysis
patlang --output results.json --time script.pat
```

### Debugging
```bash
# Enable debug mode for troubleshooting
patlang --debug --verbose problematic_script.pat

# Use quiet mode to suppress info messages
patlang --quiet script.pat
```

## Output Formats

### Standard Output
```
INFO: Executed script.pat using ruby backend
42
```

### Verbose Output
```
VERBOSE: Executing script.pat with ruby backend
INFO: Executed script.pat using ruby backend
VERBOSE: Result type: {:base_type=>"Number", :constraints=>[]}
VERBOSE: Backend: ruby
VERBOSE: Success: true
42
```

### Comparison Output
```
============================================================
BACKEND COMPARISON RESULTS
============================================================
File: script.pat
Timestamp: 2025-06-20T14:26:22+01:00

Successful backends: ruby, phase1
Failed backends: native, transpile

RUBY BACKEND:
--------------------
✓ Success
Result: 42
Time: 0.045s

PHASE1 BACKEND:
--------------------
✓ Success
Result: 42
Time: 0.078s

PERFORMANCE COMPARISON:
--------------------
ruby: 0.045s (⚡ FASTEST)
phase1: 0.078s (1.7x slower)

RESULT CONSISTENCY:
--------------------
✓ All backends produced identical results
```

### JSON Output (`--output file.json`)
```json
{
  "filename": "script.pat",
  "backend": "ruby",
  "execution_time": 0.045,
  "timestamp": "2025-06-20T14:26:22+01:00",
  "result": {
    "value": 42,
    "type": {"base_type": "Number", "constraints": []},
    "backend": "ruby",
    "success": true
  }
}
```

## Error Handling

The CLI provides comprehensive error handling with different levels of detail:

### Basic Error
```bash
ERROR: File not found: nonexistent.pat
```

### Debug Mode Error
```bash
ERROR: Execution failed with ruby backend: undefined method 'invalid_function'
DEBUG: Error details: NoMethodError: undefined method 'invalid_function'
DEBUG: Backtrace:
  script.pat:5:in 'evaluate'
  ...
```

## Performance Features

### Execution Statistics
When using `--time`, the CLI shows:
- Individual execution times
- Backend performance comparison
- Total processing time
- Files processed count

### Backend Availability Check
The CLI automatically detects which backends are available and shows their status with `--backends`.

## Integration Examples

### Shell Scripting
```bash
#!/bin/bash
# Run multiple PaTLang scripts with performance analysis
for script in *.pat; do
    echo "Processing $script..."
    patlang --time --quiet "$script"
done
```

### Continuous Integration
```bash
# Verify all backends produce consistent results
patlang --compare --quiet test_suite.pat
if [ $? -eq 0 ]; then
    echo "All backends consistent"
else
    echo "Backend inconsistency detected"
    exit 1
fi
```

### Development Workflow
```bash
# Development: Use Ruby backend for fast iteration
patlang --backend ruby --verbose script.pat

# Testing: Compare all backends
patlang --compare script.pat

# Production: Use fastest available backend
patlang --backend native script.pat
```

## Troubleshooting

### Backend Not Available
```bash
# Check which backends are available
patlang --backends

# Install missing dependencies
make -C native_evaluator  # For native backend
```

### Performance Issues
```bash
# Use timing to identify bottlenecks
patlang --time --verbose script.pat

# Try different backends
patlang --compare script.pat
```

### Syntax Errors
```bash
# Use debug mode for detailed error information
patlang --debug problematic_script.pat
```

## Advanced Usage

### Custom Backend Selection Logic
The CLI automatically selects the most appropriate backend based on:
- File extension (`.patlang` enables reasoning mode)
- Code content analysis
- Available backends
- Performance requirements

### Result Validation
When using `--compare`, the CLI validates that all successful backends produce identical results, helping ensure implementation consistency.

### Performance Monitoring
The CLI tracks execution statistics and can identify performance regressions when comparing different backend implementations.

---

For more information about PaTLang language features, see the main documentation at https://github.com/patlang/patlang