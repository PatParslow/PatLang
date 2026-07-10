use super::types::*;
use super::numeric::{promote_pair, normalize, make_rational};
use num_bigint::BigInt;

pub fn add(a: &Value, b: &Value) -> Result<Value, String> {
    match (a, b) {
        // String concatenation (including mixed types) — untouched per plan.
        (Value::String(x), Value::String(y)) => Ok(Value::String(format!("{}{}", x, y))),
        (Value::String(x), other) => Ok(Value::String(format!("{}{}", x, v_to_string(other)))),
        (other, Value::String(y)) => Ok(Value::String(format!("{}{}", v_to_string(other), y))),
        _ => numeric_binop(a, b, "add",
            |x, y| x.checked_add(y),
            |x, y| x + y,
            |x, y| x + y,
            |(an, ad), (bn, bd)| (an * &bd + bn * &ad, ad * bd),
        ),
    }
}

pub fn sub(a: &Value, b: &Value) -> Result<Value, String> {
    numeric_binop(a, b, "sub",
        |x, y| x.checked_sub(y),
        |x, y| x - y,
        |x, y| x - y,
        |(an, ad), (bn, bd)| (an * &bd - bn * &ad, ad * bd),
    )
}

pub fn mul(a: &Value, b: &Value) -> Result<Value, String> {
    match (a, b) {
        (Value::Complex(_, _), _) | (_, Value::Complex(_, _)) => complex_mul(a, b),
        _ => numeric_binop(a, b, "mul",
            |x, y| x.checked_mul(y),
            |x, y| x * y,
            |x, y| x * y,
            |(an, ad), (bn, bd)| (an * bn, ad * bd),
        ),
    }
}

pub fn div(a: &Value, b: &Value) -> Result<Value, String> {
    let (pa, pb) = promote_pair(a, b)?;
    match (pa, pb) {
        (Value::Complex(_, _), _) | (_, Value::Complex(_, _)) => {
            // Complex division is out of this stage's exercised scope; best
            // effort would need a conjugate-multiply, but nothing in Stage 36
            // requires it, so we surface a clear error instead of guessing.
            Err("complex division not supported in this stage".into())
        }
        (Value::Float(x), Value::Float(y)) => Ok(Value::Float(x / y)),
        (Value::Int(x), Value::Int(y)) => {
            if y == 0 { return Err("division by zero".into()); }
            if x % y == 0 {
                Ok(Value::Int(x / y))
            } else {
                // Inexact int division promotes to an exact Rational rather
                // than a lossy float — the locked-in Scheme-style decision.
                Ok(make_rational(BigInt::from(x), BigInt::from(y)))
            }
        }
        (Value::BigInt(x), Value::BigInt(y)) => {
            if y == BigInt::from(0) { return Err("division by zero".into()); }
            let rem = &x % &y;
            if rem == BigInt::from(0) {
                Ok(normalize(Value::BigInt(&x / &y)))
            } else {
                Ok(make_rational(x, y))
            }
        }
        (Value::Rational(an, ad), Value::Rational(bn, bd)) => {
            if bn == BigInt::from(0) { return Err("division by zero".into()); }
            Ok(make_rational(an * bd, ad * bn))
        }
        _ => Err("type error in div".into()),
    }
}

pub fn modu(a: &Value, b: &Value) -> Result<Value, String> {
    let (pa, pb) = promote_pair(a, b)?;
    match (pa, pb) {
        (Value::Float(x), Value::Float(y)) => Ok(Value::Float(x % y)),
        (Value::Int(x), Value::Int(y)) => {
            if y == 0 { return Err("modulo by zero".into()); }
            Ok(Value::Int(x % y))
        }
        (Value::BigInt(x), Value::BigInt(y)) => {
            if y == BigInt::from(0) { return Err("modulo by zero".into()); }
            Ok(normalize(Value::BigInt(&x % &y)))
        }
        (Value::Rational(an, ad), Value::Rational(bn, bd)) => {
            // a mod b for rationals: a - b * floor(a/b); implemented via
            // cross-multiplied integer remainder on numerators scaled to a
            // common denominator, which is exact and avoids a separate floor.
            if bn == BigInt::from(0) { return Err("modulo by zero".into()); }
            let common = &an * &bd;
            let rhs = &bn * &ad;
            let rem = &common % &rhs;
            Ok(make_rational(rem, &ad * &bd))
        }
        _ => Err("type error in mod".into()),
    }
}

pub fn cmp(kind: BinOpKind, a: &Value, b: &Value) -> Result<Value, String> {
    use BinOpKind::*;
    // String comparisons stay string-native (lexicographic), untouched.
    if let (Value::String(x), Value::String(y)) = (a, b) {
        return Ok(Value::Bool(match kind {
            Eq => x == y,
            Ne => x != y,
            Lt => x < y,
            Le => x <= y,
            Gt => x > y,
            Ge => x >= y,
            _ => return Err("invalid cmp op".into()),
        }));
    }

    // Eq/Ne must remain defined for every value kind (List, Object, Unit,
    // mismatched types, etc.), matching the pre-tower behavior of falling
    // back to derived structural PartialEq. Only attempt numeric promotion
    // first so numeric cross-kind equality (Int(3) == Rational(3,1)) still
    // works; anything promote_pair can't handle falls back to plain `==`.
    // Unit is deliberately excluded from the promotion path here: promote_pair
    // folds Unit into Int(0) for arithmetic's sake (matching as_number's
    // existing leniency), but that must NOT make `Unit == 0` true under
    // structural equality — the pre-tower behavior (and every other Value
    // variant's Eq impl) treats Unit as equal only to Unit.
    if matches!(kind, Eq | Ne) {
        if matches!(a, Value::Unit) || matches!(b, Value::Unit) {
            // Bypass promote_pair entirely: Unit must only equal Unit.
            return Ok(Value::Bool(if kind == Eq { a == b } else { a != b }));
        }
        if let Ok((pa, pb)) = promote_pair(a, b) {
            if let Some(eq) = structural_numeric_eq(&pa, &pb) {
                return Ok(Value::Bool(if kind == Eq { eq } else { !eq }));
            }
        }
        return Ok(Value::Bool(if kind == Eq { a == b } else { a != b }));
    }

    // Promote both sides through the same tower rules used by arithmetic so
    // e.g. Int(3) < Rational(7,2) works.
    let (pa, pb) = promote_pair(a, b)?;
    let ordering = match (&pa, &pb) {
        (Value::Int(x), Value::Int(y)) => x.cmp(y),
        (Value::Float(x), Value::Float(y)) => x.partial_cmp(y).ok_or("NaN comparison")?,
        (Value::BigInt(x), Value::BigInt(y)) => x.cmp(y),
        (Value::Rational(an, ad), Value::Rational(bn, bd)) => (an * bd).cmp(&(bn * ad)),
        (Value::Complex(are, aim), Value::Complex(bre, bim)) => {
            // Complex only supports Eq/Ne meaningfully; ordering falls back
            // to comparing real parts (documented best-effort, per plan).
            match kind {
                Eq | Ne => {
                    let eq = are == bre && aim == bim;
                    return Ok(Value::Bool(if kind == Eq { eq } else { !eq }));
                }
                _ => are.as_number().unwrap_or(0.0).partial_cmp(&bre.as_number().unwrap_or(0.0)).ok_or("NaN comparison")?,
            }
        }
        _ => return Err("type error in cmp".into()),
    };
    Ok(Value::Bool(match kind {
        Eq => ordering == std::cmp::Ordering::Equal,
        Ne => ordering != std::cmp::Ordering::Equal,
        Lt => ordering == std::cmp::Ordering::Less,
        Le => ordering != std::cmp::Ordering::Greater,
        Gt => ordering == std::cmp::Ordering::Greater,
        Ge => ordering != std::cmp::Ordering::Less,
        _ => return Err("invalid cmp op".into()),
    }))
}

/// Shared dispatch for +/-/* : same-kind arithmetic after promotion, with
/// checked Int arithmetic falling back to BigInt on overflow (always
/// succeeds after fallback). `rat_op` receives (numerator, denominator)
/// pairs for each side and returns the resulting (numerator, denominator).
fn numeric_binop(
    a: &Value,
    b: &Value,
    op_name: &str,
    int_checked: impl Fn(i64, i64) -> Option<i64>,
    big_op: impl Fn(BigInt, BigInt) -> BigInt,
    float_op: impl Fn(f64, f64) -> f64,
    rat_op: impl Fn((BigInt, BigInt), (BigInt, BigInt)) -> (BigInt, BigInt),
) -> Result<Value, String> {
    if matches!(a, Value::Complex(_, _)) || matches!(b, Value::Complex(_, _)) {
        return complex_add_sub(a, b, op_name);
    }
    let (pa, pb) = promote_pair(a, b)?;
    match (pa, pb) {
        (Value::Int(x), Value::Int(y)) => {
            match int_checked(x, y) {
                Some(r) => Ok(Value::Int(r)),
                None => Ok(normalize(Value::BigInt(big_op(BigInt::from(x), BigInt::from(y))))),
            }
        }
        (Value::Float(x), Value::Float(y)) => Ok(Value::Float(float_op(x, y))),
        (Value::BigInt(x), Value::BigInt(y)) => Ok(normalize(Value::BigInt(big_op(x, y)))),
        (Value::Rational(an, ad), Value::Rational(bn, bd)) => {
            let (rn, rd) = rat_op((an, ad), (bn, bd));
            Ok(make_rational(rn, rd))
        }
        _ => Err(format!("type error in {}", op_name)),
    }
}

fn complex_add_sub(a: &Value, b: &Value, op_name: &str) -> Result<Value, String> {
    let (pa, pb) = promote_pair(a, b)?;
    match (pa, pb) {
        (Value::Complex(are, aim), Value::Complex(bre, bim)) => {
            let (re, im) = match op_name {
                "add" => (add(&are, &bre)?, add(&aim, &bim)?),
                "sub" => (sub(&are, &bre)?, sub(&aim, &bim)?),
                _ => return Err(format!("complex {} not supported", op_name)),
            };
            Ok(normalize(Value::Complex(Box::new(re), Box::new(im))))
        }
        _ => Err(format!("type error in {}", op_name)),
    }
}

fn complex_mul(a: &Value, b: &Value) -> Result<Value, String> {
    let (pa, pb) = promote_pair(a, b)?;
    match (pa, pb) {
        (Value::Complex(are, aim), Value::Complex(bre, bim)) => {
            // (a+bi)(c+di) = (ac-bd) + (ad+bc)i
            let ac = mul(&are, &bre)?;
            let bd = mul(&aim, &bim)?;
            let ad = mul(&are, &bim)?;
            let bc = mul(&aim, &bre)?;
            let re = sub(&ac, &bd)?;
            let im = add(&ad, &bc)?;
            Ok(normalize(Value::Complex(Box::new(re), Box::new(im))))
        }
        _ => Err("type error in mul".into()),
    }
}

/// Truncating conversion for list-index-style math: Int -> usize, Float ->
/// as usize (truncated), BigInt -> usize if it fits, error on negative or
/// non-numeric. This is the escape hatch replacing ad hoc `as f64 as usize`.
pub fn as_index(v: &Value) -> Result<usize, String> {
    match v {
        Value::Int(n) if *n >= 0 => Ok(*n as usize),
        Value::Int(_) => Err("expected non-negative index".into()),
        Value::Float(n) if *n >= 0.0 => Ok(*n as usize),
        Value::Float(_) => Err("expected non-negative index".into()),
        Value::BigInt(b) => {
            if *b < BigInt::from(0) { return Err("expected non-negative index".into()); }
            b.to_string().parse::<usize>().map_err(|_| "index too large".to_string())
        }
        Value::Rational(n, d) => {
            let f = n.to_string().parse::<f64>().unwrap_or(0.0) / d.to_string().parse::<f64>().unwrap_or(1.0);
            if f < 0.0 { return Err("expected non-negative index".into()); }
            Ok(f as usize)
        }
        Value::Unit => Ok(0),
        _ => Err("expected numeric index".into()),
    }
}

/// Unary negation across every numeric kind in the tower.
pub fn negate(v: &Value) -> Result<Value, String> {
    match v {
        Value::Int(n) => n.checked_neg().map(Value::Int)
            .ok_or_else(|| "negate overflow".to_string())
            .or_else(|_| Ok(normalize(Value::BigInt(-BigInt::from(*n))))),
        Value::Float(n) => Ok(Value::Float(-n)),
        Value::BigInt(b) => Ok(normalize(Value::BigInt(-b.clone()))),
        Value::Rational(n, d) => Ok(Value::Rational(-n.clone(), d.clone())),
        Value::Complex(re, im) => Ok(Value::Complex(Box::new(negate(re)?), Box::new(negate(im)?))),
        Value::Unit => Ok(Value::Int(0)),
        _ => Err("expected number".into()),
    }
}

/// Structural equality for two already-promoted (same-kind) numeric values.
/// Returns `None` if the promoted pair isn't a numeric kind this function
/// knows how to compare (shouldn't happen given promote_pair's contract, but
/// kept total rather than panicking).
fn structural_numeric_eq(pa: &Value, pb: &Value) -> Option<bool> {
    match (pa, pb) {
        (Value::Int(x), Value::Int(y)) => Some(x == y),
        (Value::Float(x), Value::Float(y)) => Some(x == y),
        (Value::BigInt(x), Value::BigInt(y)) => Some(x == y),
        (Value::Rational(an, ad), Value::Rational(bn, bd)) => Some(an * bd == bn * ad),
        (Value::Complex(are, aim), Value::Complex(bre, bim)) => Some(are == bre && aim == bim),
        _ => None,
    }
}

pub fn v_to_string(v: &Value) -> String {
    match v {
        Value::Unit => String::new(),
        Value::Bool(b) => b.to_string(),
        Value::Int(n) => n.to_string(),
        Value::Float(n) => {
            if n.fract() == 0.0 && n.is_finite() { format!("{}", *n as i64) } else { n.to_string() }
        }
        Value::BigInt(b) => b.to_string(),
        Value::Rational(n, d) => format!("{}/{}", n, d),
        Value::Complex(re, im) => format!("{}+{}i", v_to_string(re), v_to_string(im)),
        Value::String(s) => s.clone(),
        Value::List(xs) => {
            let parts: Vec<String> = xs.iter().map(v_to_string).collect();
            format!("[{}]", parts.join(", "))
        }
        Value::HostFunction(_) => "<hostfn>".into(),
        Value::Closure { .. } => "<closure>".into(),
        Value::Object(map) => {
            let mut kvs: Vec<String> = map.iter().map(|(k, v)| format!("{}: {}", k, v_to_string(v))).collect();
            kvs.sort();
            format!("{{{}}}", kvs.join(", "))
        }
    }
}
