# Patlang Development Roadmap - Post v0.1.0

## Current Status (v0.1.0)

✅ **Completed: Arithmetic Interpreter MVP**
- Complete lexer with integer and decimal number support
- Recursive descent parser with proper operator precedence
- AST-based evaluator for arithmetic expressions
- Interactive REPL with demonstration mode
- Comprehensive test suite (42+ tests, 140+ assertions)
- Support for: `+`, `-`, `*`, `/`, parentheses, decimals

## Next Increment: Variables and Assignment (v0.2.0)

**Target Features:**
- Variable declaration and assignment
- Variable lookup and evaluation
- Memory management for variable storage
- Enhanced REPL with variable persistence across expressions

**Implementation Plan:**

### 1. Lexer Enhancements
- Add `IDENTIFIER` token type for variable names
- Add `EQUALS` token type for assignment operator (`=`)
- Update lexer to recognize valid identifier patterns (`[a-zA-Z_][a-zA-Z0-9_]*`)

### 2. Parser Extensions
- Add `AssignmentNode` AST node for variable assignments
- Add `VariableNode` AST node for variable references
- Extend grammar to handle assignment statements
- Update expression parsing to include variable lookup

### 3. Evaluator Updates
- Add symbol table/environment for variable storage
- Implement assignment statement evaluation
- Implement variable lookup with error handling for undefined variables
- Maintain variable state across REPL sessions

### 4. Test Coverage
- Variable declaration and assignment tests
- Variable lookup and reference tests
- Error handling for undefined variables
- Integration tests for mixed arithmetic and variables

**Example Usage After v0.2.0:**
```
> x = 42
42
> y = 3.14
3.14
> x + y * 2
48.28
> result = (x + y) / 2
22.57
```

**Known to Unknown Progression:**
Variables are fundamental to programming and well-understood. This builds naturally on our arithmetic foundation without introducing complex concepts.

## Future Increments (Tentative)

### v0.3.0: String Literals and Operations
- String literal support with double quotes
- String concatenation operator
- Mixed string and numeric expressions
- String interpolation basics

### v0.4.0: Boolean Logic and Comparisons
- Boolean literals (`true`, `false`)
- Comparison operators (`==`, `!=`, `<`, `>`, `<=`, `>=`)
- Logical operators (`and`, `or`, `not`)
- Boolean expressions in conditions

### v0.5.0: Control Flow - Conditional Statements
- `if`/`else` statements
- Nested conditions
- Conditional expressions

### v0.6.0: Control Flow - Loops
- `while` loops
- Basic iteration constructs
- Loop control flow

### v0.7.0: Functions (Simple)
- Function definition without parameters
- Function calls and return values
- Local scope basics

### v0.8.0: Functions (Advanced)
- Functions with parameters
- Local variable scoping
- Return statements

## Development Principles

### Incremental "Known to Unknown"
- Each increment builds on well-understood programming concepts
- Complexity increases gradually
- Each phase delivers working, testable functionality
- Clear progression toward full Patlang interpreter

### Quality Assurance
- Comprehensive test suite for each increment
- Backward compatibility maintained
- Documentation updated with each release
- Git workflow with feature branches and tags

### Architecture Considerations
- Clean separation between lexer, parser, and evaluator
- Extensible AST node hierarchy
- Flexible symbol table design for future scoping features
- Error handling framework for meaningful user feedback

## Success Criteria for v0.2.0

- [ ] Variables can be declared and assigned values
- [ ] Variables can be referenced in arithmetic expressions
- [ ] Error messages for undefined variables
- [ ] REPL maintains variable state across input lines
- [ ] All existing arithmetic functionality preserved
- [ ] Test suite passes with new variable functionality
- [ ] Documentation updated with variable examples

## Estimated Timeline

**v0.2.0 Variables and Assignment**: 1-2 weeks
- Simple, foundational feature
- Builds directly on existing evaluator infrastructure

**Future Increments**: 1-2 weeks each
- Maintains steady development velocity
- Allows for thorough testing and documentation

## Risk Mitigation

- **Scope Creep**: Strict adherence to increment boundaries
- **Complexity**: Gradual introduction of language features
- **Testing**: Comprehensive test coverage before moving to next increment
- **Documentation**: Keep documentation current with implementation

---

This roadmap ensures steady progress toward the full Patlang interpreter while maintaining quality and following incremental development principles.