# Patlang Intermediate Representation (IR) - Draft

Goal: a minimal, typed, portable IR to bootstrap a self-hosting compiler. Stage 0 targets an interpreter and a transpile-to-Rust backend.

## Values and Types
- Types: Unit, Bool, Number, String, List<T>, Function(Params->Ret), Object (opaque)
- Values: Unit, Bool, Number(f64), String, List<Value>, HostFunction (Stage 0), Object{string->Value}

## Instructions (stack-based)
- Const(Value), LoadLocal(name), StoreLocal(name)
- UnOp(Neg|Not)
- BinOp(Add|Sub|Mul|Div|Eq|Ne|Lt|Le|Gt|Ge|And|Or)
- Jump(pc), JumpIfFalse(pc)
- CallHost(name, argc)     // Stage 0 calls into runtime/built-ins
- Return
- BuildList(n)             // pop n values, push List in evaluation order

## Functions and Program
- Function: name, params, locals, body(Vec<Instr>)
- Program: functions(HashMap), entry(String)

## Semantics
- Stack machine; locals env by string for simplicity (fasten later with slots).
- Short-circuit: implemented via Jump/JumpIfFalse or BinOp And/Or.
- Closures: Stage 0 uses HostFunction; Stage 1 will add captured envs.

## Next
- Add slots (u16) for locals/params; SSA-like temp ids for analysis.
- Add Call (user function) with frame/args.
- Add List ops, Map/Object ops, and Field access.
- Define FFI surface mapping to runtime APIs.
