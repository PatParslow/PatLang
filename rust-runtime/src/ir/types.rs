use std::collections::HashMap;
use num_bigint::BigInt;

#[derive(Clone, Debug, PartialEq)]
pub enum Type {
    Unit,
    Bool,
    Number,
    String,
    List(Box<Type>),
    Function { params: Vec<Type>, ret: Box<Type> },
    // Opaque object for runtime integration; refined later
    Object,
}

// Numeric tower (Stage 36 — interpreter only, no codegen-template changes):
// Int is the fast default path for whole numbers; Float is standard IEEE
// double contagion; BigInt/Rational/Complex are auto-promoted to on overflow,
// inexact integer division, and (future, Stage 39) sqrt of a negative number,
// respectively. See ir/numeric.rs for promotion/normalization rules and
// ir/ops.rs for the arithmetic itself.
#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Unit,
    Bool(bool),
    Int(i64),
    Float(f64),
    BigInt(BigInt),
    // Always kept reduced (gcd'd) with a strictly positive denominator.
    Rational(BigInt, BigInt),
    // Real/imaginary parts are each Int|Float|BigInt|Rational (never Complex
    // or a non-numeric kind); enforced by construction sites, not the type.
    Complex(Box<Value>, Box<Value>),
    String(String),
    List(Vec<Value>),
    // Functions are closures with env; for Stage 0 keep them host-side only in the interpreter
    HostFunction(fn(&[Value]) -> Result<Value, String>),
    Object(HashMap<String, Value>),
    // A closure value: the name of its synthesized Function (params =
    // captured names ++ the closure's own params, in that order) plus the
    // captured environment snapshotted at closure-creation time.
    Closure { func_name: String, captured: Vec<(String, Value)> },
}

// Lossy BigInt/Rational -> f64 conversion via decimal string round-trip.
// This avoids pulling in num-traits just for `ToPrimitive`; precision loss
// for values outside f64's range/precision is expected and documented here
// per the plan's "document, don't error" guidance.
fn bigint_to_f64_lossy(b: &BigInt) -> f64 {
    b.to_string().parse::<f64>().unwrap_or(if b.sign() == num_bigint::Sign::Minus { f64::NEG_INFINITY } else { f64::INFINITY })
}

impl Value {
    pub fn as_number(&self) -> Result<f64, String> {
        match self {
            Value::Int(n) => Ok(*n as f64),
            Value::Float(n) => Ok(*n),
            Value::BigInt(b) => Ok(bigint_to_f64_lossy(b)),
            Value::Rational(n, d) => Ok(bigint_to_f64_lossy(n) / bigint_to_f64_lossy(d)),
            Value::Complex(_, _) => Err("expected number, found complex".into()),
            Value::Unit => Ok(0.0),
            _ => Err("expected number".into()),
        }
    }

    pub fn as_bool(&self) -> Result<bool, String> {
        match self {
            Value::Bool(b) => Ok(*b),
            Value::Unit => Ok(false),
            Value::Int(n) => Ok(*n != 0),
            Value::Float(n) => Ok(*n != 0.0),
            Value::BigInt(b) => Ok(!b.eq(&BigInt::from(0))),
            Value::Rational(n, _) => Ok(!n.eq(&BigInt::from(0))),
            Value::Complex(re, im) => Ok(re.as_bool().unwrap_or(true) || im.as_bool().unwrap_or(false)),
            Value::String(s) => Ok(!s.is_empty()),
            Value::List(xs) => Ok(!xs.is_empty()),
            Value::Object(map) => Ok(!map.is_empty()),
            Value::HostFunction(_) => Ok(true),
            Value::Closure { .. } => Ok(true),
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub enum BinOpKind { Add, Sub, Mul, Div, Mod, Eq, Ne, Lt, Le, Gt, Ge, And, Or }

#[derive(Clone, Debug, PartialEq)]
pub enum UnOpKind { Neg, Not }

#[derive(Clone, Debug, PartialEq)]
pub enum Instr {
    // Compute
    Const(Value),
    LoadLocal(String),
    StoreLocal(String),
    BinOp(BinOpKind),
    UnOp(UnOpKind),

    // Control flow
    Jump(usize),           // absolute pc
    JumpIfFalse(usize),    // absolute pc

    // Function calls (host for Stage 0)
    CallHost(String, usize), // name, arg_count
    // User function call by name
    Call(String, usize),     // function name, arg_count

    // Closures: capture N values already on the stack (pushed via LoadLocal
    // in the same order as captured_names) into a Value::Closure bound to
    // func_name, whose params are captured_names ++ the closure's own params.
    MakeClosure(String, Vec<String>), // func_name, captured_names
    // Call a closure value: stack has [closure_value, arg0, .., argN-1]
    // (closure pushed first, then args), argc = N.
    CallValue(usize),

    // Collections
    BuildList(usize), // pop N items and push a list in original order

    // Structured end-of-program
    Return,
}

#[derive(Clone, Debug, Default)]
pub struct Function {
    pub name: String,
    pub params: Vec<String>,
    pub locals: Vec<String>,
    pub body: Vec<Instr>,
}

#[derive(Clone, Debug, Default)]
pub struct Program {
    pub functions: HashMap<String, Function>,
    pub entry: String,
    // Event name -> handler function names
    pub event_handlers: HashMap<String, Vec<String>>,
}
