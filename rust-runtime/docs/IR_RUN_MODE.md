# IR Run Mode

You can execute Patlang via the IR path (Parser → Lowerer → Interpreter) without the Rust evaluator.

Usage:

- cargo run -- --ir-run <file.pat>

Notes:
- Stage 0 supports: numbers, strings, identifiers, let, return, if/else, unary/binary ops, and identifier-based function calls mapped to Host functions.
- To wire host functions, add built-ins in the interpreter or future runtime integration. Currently, only the lowering emits CallHost; main.rs simply prints final value.
