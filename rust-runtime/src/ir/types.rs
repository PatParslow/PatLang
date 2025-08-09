use std::collections::HashMap;

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

#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Unit,
    Bool(bool),
    Number(f64),
    String(String),
    List(Vec<Value>),
    // Functions are closures with env; for Stage 0 keep them host-side only in the interpreter
    HostFunction(fn(&[Value]) -> Result<Value, String>),
    Object(HashMap<String, Value>),
}

impl Value {
    pub fn as_number(&self) -> Result<f64, String> {
        match self {
            Value::Number(n) => Ok(*n),
            Value::Unit => Ok(0.0),
            _ => Err("expected number".into()),
        }
    }

    pub fn as_bool(&self) -> Result<bool, String> {
        match self {
            Value::Bool(b) => Ok(*b),
            Value::Unit => Ok(false),
            _ => Err("expected bool".into()),
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
}
