# Patlang Architecture Migration Guide

## Overview

Patlang has successfully migrated from a monolithic structure to a clean modular architecture. This guide helps existing users and developers transition to the new structure.

## 🚀 Quick Migration for Existing Users

### Updated Commands

**Old Commands** → **New Commands**
```bash
# Running the REPL
ruby src/patlang.rb                     → ruby ruby-host/bootstrap/patlang_bootstrap.rb

# Running tests  
ruby test/comprehensive_test_suite_runner.rb → ruby test/fixed_comprehensive_coverage_runner.rb

# Development tools
ruby test/enhanced_test_runner.rb       → ruby dev-tools/testing/enhanced_test_runner.rb
```

### Updated File Paths

**Core Language Files** (moved from `src/` to `patlang-core/`):
- `src/lexer.rb` → `patlang-core/lexer/lexer.rb`
- `src/parser.rb` → `patlang-core/parser/parser.rb`
- `src/evaluator.rb` → `patlang-core/evaluator/evaluator.rb`
- `src/ast_nodes.rb` → `patlang-core/ast/ast_nodes.rb`
- `src/token.rb` → `patlang-core/lexer/token.rb`

**Bootstrap Files** (moved to `ruby-host/`):
- `src/patlang.rb` → `ruby-host/bootstrap/patlang_bootstrap.rb`
- `src/emergency_timeout.rb` → `ruby-host/bootstrap/emergency_timeout.rb`

**Development Tools** (organized in `dev-tools/`):
- Test runners → `dev-tools/testing/`
- Build tools → `dev-tools/build/`
- Coverage tools → `dev-tools/coverage/`

## 📁 New Directory Structure

```
patlang/
├── patlang-core/          # Core language implementation
│   ├── ast/              # Abstract Syntax Tree nodes
│   ├── evaluator/        # Expression and statement evaluation
│   ├── lexer/            # Tokenization and lexical analysis
│   ├── object_model/     # Object system and type infrastructure
│   ├── parser/           # Syntax parsing and analysis
│   ├── reasoning/        # Logic programming and constraint solving
│   └── exceptions.rb     # Core exception classes
├── ruby-host/            # Ruby bootstrap and runtime environment
│   ├── bootstrap/        # Language bootstrap and entry points
│   ├── interop/          # Ruby-Patlang interoperability
│   └── runtime/          # Runtime support and utilities
├── dev-tools/            # Development and build tools
│   ├── analysis/         # Code analysis tools
│   ├── build/            # Build scripts and VS Code extensions
│   ├── coverage/         # Coverage analysis tools
│   └── testing/          # Test runners and diagnostic tools
├── test/                 # Comprehensive test suite
├── docs/                 # Documentation (updated)
├── examples/             # Example programs
└── src/                  # Legacy files (being phased out)
```

## 🔄 Migration Steps for Developers

### 1. Update Your Development Environment

```bash
# Update your REPL command
alias patlang="ruby ruby-host/bootstrap/patlang_bootstrap.rb"

# Update your test command
alias test-patlang="ruby test/fixed_comprehensive_coverage_runner.rb"
```

### 2. Update Import Paths in Your Code

If you have Ruby code that requires Patlang components:

```ruby
# Old imports
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'

# New imports
require_relative 'patlang-core/lexer/lexer'
require_relative 'patlang-core/parser/parser'
require_relative 'patlang-core/evaluator/evaluator'
```

### 3. Update Your Build Scripts

If you have scripts that reference the old structure:

```bash
# Update file paths in your scripts
sed -i 's|src/|patlang-core/|g' your-build-script.sh

# Update test runner references
sed -i 's|comprehensive_test_suite_runner|fixed_comprehensive_coverage_runner|g' your-ci-script.sh
```

### 4. Update Documentation References

If you maintain documentation that references Patlang:

- Update all `src/` references to `patlang-core/`
- Update entry point references to `ruby-host/bootstrap/patlang_bootstrap.rb`
- Update test runner references to `test/fixed_comprehensive_coverage_runner.rb`

## 🆘 Troubleshooting

### Common Issues and Solutions

**Issue**: `LoadError: cannot load such file -- src/lexer`
**Solution**: Update require paths to use `patlang-core/lexer/lexer`

**Issue**: `No such file or directory - src/patlang.rb`
**Solution**: Use `ruby-host/bootstrap/patlang_bootstrap.rb` instead

**Issue**: Test runner not found
**Solution**: Use `test/fixed_comprehensive_coverage_runner.rb`

### Compatibility Mode

For temporary compatibility, you can create symbolic links:

```bash
# Create compatibility links (temporary solution)
ln -s patlang-core/lexer/lexer.rb src/lexer.rb
ln -s ruby-host/bootstrap/patlang_bootstrap.rb src/patlang.rb

# Note: Remove these once you've updated your scripts
```

## 📈 Benefits of the New Architecture

### 1. **Separation of Concerns**
- Core language logic separated from bootstrap concerns
- Clear module boundaries and responsibilities
- Easier to understand and maintain

### 2. **Improved Organization**
- Related files grouped together logically
- Consistent naming and structure
- Reduced cognitive load when navigating codebase

### 3. **Better Development Experience**
- Clear entry points for different use cases
- Organized development tools
- Structured test suite organization

### 4. **Enhanced Scalability**
- Modular structure supports future growth
- Easy to add new components
- Clean abstraction layers

## 🔮 Future Compatibility

The new architecture is designed for long-term stability:

- **Module Boundaries**: Clear interfaces between modules
- **Entry Points**: Stable entry points that won't change
- **Backward Compatibility**: Legacy support during transition period
- **Extension Points**: Designed for future enhancements

## 🆔 Version Compatibility

| Version | Architecture | Entry Point | Status |
|---------|-------------|-------------|---------|
| v0.6.x and earlier | Monolithic | `src/patlang.rb` | Legacy (deprecated) |
| v0.7.x and later | Modular | `ruby-host/bootstrap/patlang_bootstrap.rb` | Current |

## 📞 Support

If you encounter issues during migration:

1. **Check this guide** for common solutions
2. **Update your scripts** using the examples provided
3. **Test your changes** with the new test runner
4. **Report issues** if you find compatibility problems

The architecture migration improves Patlang's maintainability and provides a better foundation for future development while preserving all existing functionality.