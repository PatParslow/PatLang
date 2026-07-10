//! Stage 36 — numeric tower promotion/normalization helpers.
//!
//! `promote_pair` coerces two operands to a common representation so callers
//! (ir/ops.rs) can implement each arithmetic/comparison op once per "kind"
//! rather than handling every cross-kind combination inline. `normalize`
//! demotes a result back down to the cheapest representation that can hold
//! it exactly, so the fast `Int` path stays fast across a sequence of ops
//! that transiently touch BigInt/Rational.

use super::types::Value;
use num_bigint::BigInt;

/// Reduce a BigInt fraction to lowest terms with a strictly positive
/// denominator. Hand-rolled gcd (no num-integer dependency) per the plan's
/// explicit "note as-is, it's fine" guidance.
fn gcd(mut a: BigInt, mut b: BigInt) -> BigInt {
    while b != BigInt::from(0) {
        let t = &a % &b;
        a = b;
        b = t;
    }
    if a < BigInt::from(0) { -a } else { a }
}

/// Build a reduced Rational, demoting to Int/BigInt if the denominator
/// reduces to 1. Always normalizes sign onto the numerator (den > 0).
pub fn make_rational(mut num: BigInt, mut den: BigInt) -> Value {
    if den == BigInt::from(0) {
        // Callers are expected to have already checked for this; fall back
        // to a deliberately-obvious sentinel rather than panicking.
        return Value::Float(f64::NAN);
    }
    if den < BigInt::from(0) {
        num = -num;
        den = -den;
    }
    let g = gcd(num.clone(), den.clone());
    if g != BigInt::from(0) && g != BigInt::from(1) {
        num /= &g;
        den /= &g;
    }
    normalize(Value::Rational(num, den))
}

/// Demote BigInt->Int if it fits in i64, Rational with denominator 1 ->
/// Int/BigInt, and Complex with an exactly-zero imaginary part -> its real
/// component. Recurses so a chain of demotions collapses in one call.
pub fn normalize(v: Value) -> Value {
    match v {
        Value::BigInt(b) => {
            match i64::try_from(&b) {
                Ok(n) => Value::Int(n),
                Err(_) => Value::BigInt(b),
            }
        }
        Value::Rational(n, d) => {
            if d == BigInt::from(1) {
                normalize(Value::BigInt(n))
            } else {
                Value::Rational(n, d)
            }
        }
        Value::Complex(re, im) => {
            let im_n = normalize(*im);
            let is_zero = matches!(&im_n, Value::Int(0))
                || matches!(&im_n, Value::Float(f) if *f == 0.0)
                || matches!(&im_n, Value::BigInt(b) if *b == BigInt::from(0))
                || matches!(&im_n, Value::Rational(n, _) if *n == BigInt::from(0));
            if is_zero {
                normalize(*re)
            } else {
                Value::Complex(Box::new(normalize(*re)), Box::new(im_n))
            }
        }
        other => other,
    }
}

/// Numeric "rank" used to decide the common representation two operands
/// should be promoted to. Higher rank wins.
fn rank(v: &Value) -> u8 {
    match v {
        Value::Int(_) => 0,
        Value::BigInt(_) => 1,
        Value::Rational(_, _) => 2,
        Value::Float(_) => 3, // float contagion always wins except vs Complex
        Value::Complex(_, _) => 4,
        Value::Unit => 0, // treated as Int(0) by as_number's convention
        _ => 255,
    }
}

fn to_bigint(v: &Value) -> Result<BigInt, String> {
    match v {
        Value::Int(n) => Ok(BigInt::from(*n)),
        Value::BigInt(b) => Ok(b.clone()),
        Value::Unit => Ok(BigInt::from(0)),
        _ => Err("expected integer-valued numeric".into()),
    }
}

fn to_rational(v: &Value) -> Result<(BigInt, BigInt), String> {
    match v {
        Value::Int(n) => Ok((BigInt::from(*n), BigInt::from(1))),
        Value::BigInt(b) => Ok((b.clone(), BigInt::from(1))),
        Value::Rational(n, d) => Ok((n.clone(), d.clone())),
        Value::Unit => Ok((BigInt::from(0), BigInt::from(1))),
        _ => Err("expected rational-representable numeric".into()),
    }
}

/// Coerce `a`/`b` to a common representation. `Int`/`Int` passes through
/// unchanged (checked-arithmetic-with-BigInt-fallback is ops.rs's job, since
/// only that call site knows whether the specific operation would overflow).
pub fn promote_pair(a: &Value, b: &Value) -> Result<(Value, Value), String> {
    // Unit is treated as numeric zero (matches as_number's existing leniency).
    let a = if matches!(a, Value::Unit) { Value::Int(0) } else { a.clone() };
    let b = if matches!(b, Value::Unit) { Value::Int(0) } else { b.clone() };

    let ra = rank(&a);
    let rb = rank(&b);

    // Complex involved: promote the other side to Complex(x, 0).
    if ra == 4 || rb == 4 {
        let ca = match a {
            Value::Complex(re, im) => Value::Complex(re, im),
            other => Value::Complex(Box::new(other), Box::new(Value::Int(0))),
        };
        let cb = match b {
            Value::Complex(re, im) => Value::Complex(re, im),
            other => Value::Complex(Box::new(other), Box::new(Value::Int(0))),
        };
        return Ok((ca, cb));
    }

    // Float involved: both become Float (lossy for BigInt/Rational, documented
    // at as_number's definition site).
    if ra == 3 || rb == 3 {
        let fa = a.as_number()?;
        let fb = b.as_number()?;
        return Ok((Value::Float(fa), Value::Float(fb)));
    }

    // Rational involved: both become Rational(num, den).
    if ra == 2 || rb == 2 {
        let (an, ad) = to_rational(&a)?;
        let (bn, bd) = to_rational(&b)?;
        return Ok((Value::Rational(an, ad), Value::Rational(bn, bd)));
    }

    // BigInt involved (but neither is Rational/Float/Complex): both become BigInt.
    if ra == 1 || rb == 1 {
        let ai = to_bigint(&a)?;
        let bi = to_bigint(&b)?;
        return Ok((Value::BigInt(ai), Value::BigInt(bi)));
    }

    // Both plain Int (or Unit-as-zero already folded above).
    Ok((a, b))
}
