//! Stage 38 Milestone 2 — hand-rolled `RationalT`/`ComplexT` built directly
//! on top of Milestone 1's `BigIntT` (`ir/bignum_template.rs`), written as
//! ordinary compiler-checked Rust so its arithmetic can be verified by
//! `cargo test` BEFORE it is later hand-copied (Milestone 3) into a
//! `&'static str` prelude chunk in `ir/codegen.rs`.
//!
//! Like `bignum_template.rs`, this file is std-only, no external crates, and
//! is NOT wired into codegen.rs/ChunkId/any prelude chunk yet. It consumes
//! only `bignum_template::BigIntT`'s existing public API — it does not
//! reimplement or modify bignum arithmetic.
//!
//! DELIBERATE ASYMMETRY (mirrors the note in `bignum_template.rs`): the
//! *interpreter*'s Stage 36 tower (`ir/numeric.rs`) uses `num_bigint::BigInt`
//! and lives directly on `Value`. This module is a separate, self-contained
//! implementation intended for *emitted/compiled* PatLang programs, so it
//! cannot depend on `num_bigint` and does not have access to the
//! interpreter's real `Value` enum. `NumT` below is a small local stand-in
//! for the four non-Complex tower kinds, built now because Milestone 3 will
//! need exactly this kind of promotion dispatch once it wires a full tower
//! into codegen's own `Value` copy.

use super::bignum_template::{gcd, BigIntT};
use std::cmp::Ordering;

// ===========================================================================
// RationalT
// ===========================================================================

/// Exact rational number, always stored reduced (gcd'd down) with a
/// canonical strictly-positive denominator — sign lives entirely on the
/// numerator. Mirrors `ir/numeric.rs`'s `make_rational`/`normalize` rules,
/// but implemented purely over `BigIntT`.
#[derive(Debug, Clone)]
pub struct RationalT {
    pub num: BigIntT,
    pub den: BigIntT,
}

impl RationalT {
    /// Construct a reduced rational from a raw numerator/denominator pair.
    ///
    /// Convention (documented, consistent): **panics on a zero denominator**.
    /// Zero-denominator construction is a caller bug (division-by-zero should
    /// be caught before reaching here, exactly like `BigIntT::div_rem`'s own
    /// panic-on-zero-divisor convention that this mirrors), not a recoverable
    /// runtime value — this is the same "let a bad invariant panic loudly"
    /// choice `div_rem` already made, so it's the more consistent option to
    /// carry forward rather than introducing a fallible-vs-panicking split
    /// between `BigIntT` and `RationalT`.
    pub fn new(num: BigIntT, den: BigIntT) -> Self {
        if den.is_zero() {
            panic!("RationalT: zero denominator");
        }
        let (num, den) = if den.is_negative() {
            (num.negate(), den.negate())
        } else {
            (num, den)
        };
        if num.is_zero() {
            return RationalT { num: BigIntT::zero(), den: BigIntT::from_i64(1) };
        }
        let g = gcd(&num, &den);
        if g.is_zero() || g.eq(&BigIntT::from_i64(1)) {
            RationalT { num, den }
        } else {
            let (qn, _) = num.div_rem(&g);
            let (qd, _) = den.div_rem(&g);
            RationalT { num: qn, den: qd }
        }
    }

    pub fn from_i64_pair(n: i64, d: i64) -> Self {
        RationalT::new(BigIntT::from_i64(n), BigIntT::from_i64(d))
    }

    pub fn is_zero(&self) -> bool {
        self.num.is_zero()
    }

    /// `a/b + c/d = (ad + cb) / bd`, reduced via `new`.
    pub fn add(&self, other: &RationalT) -> RationalT {
        let num = self.num.mul(&other.den).add(&other.num.mul(&self.den));
        let den = self.den.mul(&other.den);
        RationalT::new(num, den)
    }

    /// `a/b - c/d = (ad - cb) / bd`, reduced via `new`.
    pub fn sub(&self, other: &RationalT) -> RationalT {
        let num = self.num.mul(&other.den).sub(&other.num.mul(&self.den));
        let den = self.den.mul(&other.den);
        RationalT::new(num, den)
    }

    /// `(a/b) * (c/d) = ac / bd`, reduced via `new`.
    pub fn mul(&self, other: &RationalT) -> RationalT {
        RationalT::new(self.num.mul(&other.num), self.den.mul(&other.den))
    }

    /// `(a/b) / (c/d) = ad / bc`. Panics if `other` is zero (division by
    /// zero), same convention as `BigIntT::div_rem`/`RationalT::new`.
    pub fn div(&self, other: &RationalT) -> RationalT {
        if other.is_zero() {
            panic!("RationalT: division by zero");
        }
        RationalT::new(self.num.mul(&other.den), self.den.mul(&other.num))
    }

    /// Exact comparison via cross-multiplication (`a/b cmp c/d` <=>
    /// `a*d cmp c*b`, valid since both denominators are always positive after
    /// construction) — never converts through `f64`, staying exact.
    pub fn cmp(&self, other: &RationalT) -> Ordering {
        let lhs = self.num.mul(&other.den);
        let rhs = other.num.mul(&self.den);
        lhs.cmp(&rhs)
    }

    pub fn eq(&self, other: &RationalT) -> bool {
        self.cmp(other) == Ordering::Equal
    }

    /// Demote back to a plain `BigIntT` when the reduced denominator is 1,
    /// mirroring `ir/numeric.rs::normalize`'s `Rational -> Int/BigInt`
    /// demotion rule for the interpreter's `Value::Rational`.
    pub fn to_bigint_if_integer(&self) -> Option<BigIntT> {
        if self.den.eq(&BigIntT::from_i64(1)) {
            Some(self.num.clone())
        } else {
            None
        }
    }

    /// Lossy conversion to `f64`, needed for float-contagion cases (e.g.
    /// `Rational + Float`). Can lose precision silently for very large
    /// numerator/denominator (beyond `f64`'s ~53 bits of mantissa) — this is
    /// a documented, accepted limitation, matching the design doc's own
    /// acknowledgment that BigInt/Rational -> f64 conversion "can lose
    /// precision silently; document, don't error."
    pub fn to_f64(&self) -> f64 {
        bigint_to_f64_lossy(&self.num) / bigint_to_f64_lossy(&self.den)
    }
}

/// Lossy `BigIntT -> f64` conversion via decimal-string parsing (simplest
/// correct-enough approach available using only `BigIntT`'s public API —
/// there is no direct limb-to-float routine, and going through the decimal
/// string `to_string()`/`f64::parse` is exact for magnitude/sign and only
/// loses precision in the same way any other big-to-float widening would).
fn bigint_to_f64_lossy(b: &BigIntT) -> f64 {
    b.to_string().parse::<f64>().unwrap_or(f64::NAN)
}

// ===========================================================================
// NumT — small local stand-in for Int/Float/BigInt/Rational, used only to
// give ComplexT's re/im components a place to live and to exercise the same
// "promote to a common kind, then operate" dispatch pattern as
// `ir/numeric.rs::promote_pair`, at the smaller scale this template needs.
// ===========================================================================

#[derive(Debug, Clone)]
pub enum NumT {
    Int(i64),
    Float(f64),
    Big(BigIntT),
    Rat(RationalT),
}

impl NumT {
    fn rank(&self) -> u8 {
        match self {
            NumT::Int(_) => 0,
            NumT::Big(_) => 1,
            NumT::Rat(_) => 2,
            NumT::Float(_) => 3,
        }
    }

    fn to_bigint(&self) -> BigIntT {
        match self {
            NumT::Int(n) => BigIntT::from_i64(*n),
            NumT::Big(b) => b.clone(),
            _ => panic!("NumT::to_bigint: not integer-valued"),
        }
    }

    fn to_rational(&self) -> RationalT {
        match self {
            NumT::Int(n) => RationalT::from_i64_pair(*n, 1),
            NumT::Big(b) => RationalT::new(b.clone(), BigIntT::from_i64(1)),
            NumT::Rat(r) => r.clone(),
            NumT::Float(_) => panic!("NumT::to_rational: not exact"),
        }
    }

    pub fn to_f64(&self) -> f64 {
        match self {
            NumT::Int(n) => *n as f64,
            NumT::Float(f) => *f,
            NumT::Big(b) => bigint_to_f64_lossy(b),
            NumT::Rat(r) => r.to_f64(),
        }
    }

    /// Promote two `NumT`s to a common representation, mirroring
    /// `ir/numeric.rs::promote_pair`'s rank-based dispatch (Int < BigInt <
    /// Rational < Float), but over the local `NumT` kinds only.
    fn promote_pair(a: &NumT, b: &NumT) -> (NumT, NumT) {
        let ra = a.rank();
        let rb = b.rank();
        if ra == 3 || rb == 3 {
            return (NumT::Float(a.to_f64()), NumT::Float(b.to_f64()));
        }
        if ra == 2 || rb == 2 {
            return (NumT::Rat(a.to_rational()), NumT::Rat(b.to_rational()));
        }
        if ra == 1 || rb == 1 {
            return (NumT::Big(a.to_bigint()), NumT::Big(b.to_bigint()));
        }
        (a.clone(), b.clone())
    }

    /// Demote `BigInt -> Int` (if it fits) and `Rational` with denominator 1
    /// `-> Int/BigInt`, mirroring `ir/numeric.rs::normalize`'s rules at the
    /// `NumT` scale.
    fn normalize(self) -> NumT {
        match self {
            NumT::Big(b) => {
                match i64_from_bigint(&b) {
                    Some(n) => NumT::Int(n),
                    None => NumT::Big(b),
                }
            }
            NumT::Rat(r) => match r.to_bigint_if_integer() {
                Some(b) => NumT::Big(b).normalize(),
                None => NumT::Rat(r),
            },
            other => other,
        }
    }

    pub fn add(&self, other: &NumT) -> NumT {
        let (a, b) = NumT::promote_pair(self, other);
        let result = match (a, b) {
            (NumT::Int(x), NumT::Int(y)) => match x.checked_add(y) {
                Some(v) => NumT::Int(v),
                None => NumT::Big(BigIntT::from_i64(x).add(&BigIntT::from_i64(y))),
            },
            (NumT::Big(x), NumT::Big(y)) => NumT::Big(x.add(&y)),
            (NumT::Rat(x), NumT::Rat(y)) => NumT::Rat(x.add(&y)),
            (NumT::Float(x), NumT::Float(y)) => NumT::Float(x + y),
            _ => unreachable!("promote_pair always yields same-kind pairs"),
        };
        result.normalize()
    }

    pub fn sub(&self, other: &NumT) -> NumT {
        let (a, b) = NumT::promote_pair(self, other);
        let result = match (a, b) {
            (NumT::Int(x), NumT::Int(y)) => match x.checked_sub(y) {
                Some(v) => NumT::Int(v),
                None => NumT::Big(BigIntT::from_i64(x).sub(&BigIntT::from_i64(y))),
            },
            (NumT::Big(x), NumT::Big(y)) => NumT::Big(x.sub(&y)),
            (NumT::Rat(x), NumT::Rat(y)) => NumT::Rat(x.sub(&y)),
            (NumT::Float(x), NumT::Float(y)) => NumT::Float(x - y),
            _ => unreachable!("promote_pair always yields same-kind pairs"),
        };
        result.normalize()
    }

    pub fn mul(&self, other: &NumT) -> NumT {
        let (a, b) = NumT::promote_pair(self, other);
        let result = match (a, b) {
            (NumT::Int(x), NumT::Int(y)) => match x.checked_mul(y) {
                Some(v) => NumT::Int(v),
                None => NumT::Big(BigIntT::from_i64(x).mul(&BigIntT::from_i64(y))),
            },
            (NumT::Big(x), NumT::Big(y)) => NumT::Big(x.mul(&y)),
            (NumT::Rat(x), NumT::Rat(y)) => NumT::Rat(x.mul(&y)),
            (NumT::Float(x), NumT::Float(y)) => NumT::Float(x * y),
            _ => unreachable!("promote_pair always yields same-kind pairs"),
        };
        result.normalize()
    }

    pub fn is_zero(&self) -> bool {
        match self {
            NumT::Int(n) => *n == 0,
            NumT::Float(f) => *f == 0.0,
            NumT::Big(b) => b.is_zero(),
            NumT::Rat(r) => r.is_zero(),
        }
    }
}

/// `i64::try_from`-equivalent for `BigIntT`, which has no such conversion in
/// its public API — implemented via decimal round-trip through `to_string`,
/// consistent with `bigint_to_f64_lossy`'s approach elsewhere in this file.
fn i64_from_bigint(b: &BigIntT) -> Option<i64> {
    b.to_string().parse::<i64>().ok()
}

// ===========================================================================
// ComplexT
// ===========================================================================

#[derive(Debug, Clone)]
pub struct ComplexT {
    pub re: NumT,
    pub im: NumT,
}

impl ComplexT {
    pub fn new(re: NumT, im: NumT) -> Self {
        ComplexT { re, im }
    }

    /// `(a+bi) + (c+di) = (a+c) + (b+d)i`
    pub fn add(&self, other: &ComplexT) -> ComplexT {
        ComplexT { re: self.re.add(&other.re), im: self.im.add(&other.im) }
    }

    /// `(a+bi) - (c+di) = (a-c) + (b-d)i`
    pub fn sub(&self, other: &ComplexT) -> ComplexT {
        ComplexT { re: self.re.sub(&other.re), im: self.im.sub(&other.im) }
    }

    /// `(a+bi)(c+di) = (ac-bd) + (ad+bc)i`
    pub fn mul(&self, other: &ComplexT) -> ComplexT {
        let ac = self.re.mul(&other.re);
        let bd = self.im.mul(&other.im);
        let ad = self.re.mul(&other.im);
        let bc = self.im.mul(&other.re);
        ComplexT { re: ac.sub(&bd), im: ad.add(&bc) }
    }

    /// `(a+bi)/(c+di) = (a+bi)(c-di) / (c^2+d^2)`, standard division via the
    /// conjugate. Implemented as a best-effort version on top of `NumT`: it
    /// works cleanly whenever the denominator's magnitude-squared sum and
    /// per-component division land on `NumT` kinds that `div`-equivalent
    /// operations can represent exactly (Int/Float always; BigInt/Rational
    /// only when evenly divisible, since `NumT` has no general `div`, only
    /// `add`/`sub`/`mul`). This is the documented limitation from the task
    /// brief: exotic BigInt-denominator cases where `c^2+d^2` doesn't evenly
    /// divide the numerator components fall through to a lossy `f64` path
    /// rather than staying exact, since building a fully exact `NumT::div`
    /// (Rational-of-BigInt result for a BigInt/BigInt division) is out of
    /// scope for this pass's "not too painful" bar.
    pub fn div(&self, other: &ComplexT) -> ComplexT {
        let denom = other.re.mul(&other.re).add(&other.im.mul(&other.im));
        if denom.is_zero() {
            panic!("ComplexT: division by zero (zero-magnitude divisor)");
        }
        let num_re = self.re.mul(&other.re).add(&self.im.mul(&other.im));
        let num_im = self.im.mul(&other.re).sub(&self.re.mul(&other.im));

        // Exact path: denom is an Int/BigInt and both numerator components
        // are exactly divisible by it -> build an exact Rational (or
        // Int/BigInt after demotion).
        if let Some(denom_big) = to_bigint_exact(&denom) {
            if let (Some(nre), Some(nim)) = (to_bigint_exact(&num_re), to_bigint_exact(&num_im)) {
                let re = NumT::Rat(RationalT::new(nre, denom_big.clone())).normalize();
                let im = NumT::Rat(RationalT::new(nim, denom_big)).normalize();
                return ComplexT { re, im };
            }
        }
        // Fallback: lossy f64 division, documented limitation for exotic
        // BigInt-denominator / non-integer-Rational-component cases.
        let d = denom.to_f64();
        ComplexT { re: NumT::Float(num_re.to_f64() / d), im: NumT::Float(num_im.to_f64() / d) }
    }

    /// Mirrors Stage 36's `Complex`-with-zero-imaginary-part demotion rule
    /// (`ir/numeric.rs::normalize`'s `Value::Complex` arm): returns `Some`
    /// of the real component when the imaginary part is exactly zero.
    pub fn to_real_if_zero_imaginary(&self) -> Option<NumT> {
        if self.im.is_zero() {
            Some(self.re.clone())
        } else {
            None
        }
    }
}

/// Extract an exact `BigIntT` from a `NumT` if it is Int/BigInt-valued, or a
/// Rational that happens to reduce to an integer. Returns `None` for Float
/// or a genuinely fractional Rational — helper for `ComplexT::div`'s
/// exact-path check.
fn to_bigint_exact(v: &NumT) -> Option<BigIntT> {
    match v {
        NumT::Int(n) => Some(BigIntT::from_i64(*n)),
        NumT::Big(b) => Some(b.clone()),
        NumT::Rat(r) => r.to_bigint_if_integer(),
        NumT::Float(_) => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn bi(n: i64) -> BigIntT {
        BigIntT::from_i64(n)
    }

    // ---- RationalT construction / reduction ----

    #[test]
    fn construction_reduces() {
        let r = RationalT::from_i64_pair(6, 8);
        assert_eq!(r.num.to_string(), "3");
        assert_eq!(r.den.to_string(), "4");
    }

    #[test]
    fn construction_normalizes_sign_to_numerator() {
        let r = RationalT::new(bi(3), bi(-4));
        assert_eq!(r.num.to_string(), "-3");
        assert_eq!(r.den.to_string(), "4");

        let r2 = RationalT::new(bi(-3), bi(-4));
        assert_eq!(r2.num.to_string(), "3");
        assert_eq!(r2.den.to_string(), "4");
    }

    #[test]
    fn zero_numerator_normalizes_denominator_to_one() {
        let r = RationalT::new(bi(0), bi(17));
        assert_eq!(r.num.to_string(), "0");
        assert_eq!(r.den.to_string(), "1");
    }

    #[test]
    #[should_panic(expected = "zero denominator")]
    fn zero_denominator_panics() {
        let _ = RationalT::new(bi(1), bi(0));
    }

    // ---- RationalT arithmetic ----

    #[test]
    fn add_matches_hand_computed() {
        // 1/2 + 1/3 = 5/6
        let a = RationalT::from_i64_pair(1, 2);
        let b = RationalT::from_i64_pair(1, 3);
        let got = a.add(&b);
        assert_eq!(got.num.to_string(), "5");
        assert_eq!(got.den.to_string(), "6");
    }

    #[test]
    fn sub_matches_hand_computed() {
        // 1/2 - 1/3 = 1/6
        let a = RationalT::from_i64_pair(1, 2);
        let b = RationalT::from_i64_pair(1, 3);
        let got = a.sub(&b);
        assert_eq!(got.num.to_string(), "1");
        assert_eq!(got.den.to_string(), "6");
    }

    #[test]
    fn mul_matches_hand_computed() {
        // (2/3) * (3/4) = 6/12 = 1/2
        let a = RationalT::from_i64_pair(2, 3);
        let b = RationalT::from_i64_pair(3, 4);
        let got = a.mul(&b);
        assert_eq!(got.num.to_string(), "1");
        assert_eq!(got.den.to_string(), "2");
    }

    #[test]
    fn div_matches_hand_computed() {
        // (2/3) / (4/9) = 18/12 = 3/2
        let a = RationalT::from_i64_pair(2, 3);
        let b = RationalT::from_i64_pair(4, 9);
        let got = a.div(&b);
        assert_eq!(got.num.to_string(), "3");
        assert_eq!(got.den.to_string(), "2");
    }

    #[test]
    fn negative_operands_arithmetic() {
        // -1/2 + 1/3 = -1/6
        let a = RationalT::from_i64_pair(-1, 2);
        let b = RationalT::from_i64_pair(1, 3);
        let got = a.add(&b);
        assert_eq!(got.num.to_string(), "-1");
        assert_eq!(got.den.to_string(), "6");

        // 1/2 * -2/3 = -1/3
        let c = RationalT::from_i64_pair(1, 2);
        let d = RationalT::from_i64_pair(-2, 3);
        let got2 = c.mul(&d);
        assert_eq!(got2.num.to_string(), "-1");
        assert_eq!(got2.den.to_string(), "3");
    }

    // ---- RationalT comparison ----

    #[test]
    fn comparison_ordering_across_several() {
        let half = RationalT::from_i64_pair(1, 2);
        let third = RationalT::from_i64_pair(1, 3);
        let two_thirds = RationalT::from_i64_pair(2, 3);
        let neg_half = RationalT::from_i64_pair(-1, 2);

        assert_eq!(third.cmp(&half), Ordering::Less);
        assert_eq!(half.cmp(&third), Ordering::Greater);
        assert_eq!(two_thirds.cmp(&half), Ordering::Greater);
        assert_eq!(neg_half.cmp(&third), Ordering::Less);
    }

    #[test]
    fn equal_value_different_representation_compares_equal() {
        // 2/4 (unreduced input) vs 1/2 must compare equal after reduction.
        let a = RationalT::from_i64_pair(2, 4);
        let b = RationalT::from_i64_pair(1, 2);
        assert_eq!(a.cmp(&b), Ordering::Equal);
        assert!(a.eq(&b));
    }

    // ---- to_bigint_if_integer ----

    #[test]
    fn to_bigint_if_integer_some_when_reduces_to_integer() {
        // 8/4 reduces to 2/1 -> integer.
        let r = RationalT::from_i64_pair(8, 4);
        let got = r.to_bigint_if_integer();
        assert!(got.is_some());
        assert_eq!(got.unwrap().to_string(), "2");
    }

    #[test]
    fn to_bigint_if_integer_none_when_fractional() {
        let r = RationalT::from_i64_pair(3, 4);
        assert!(r.to_bigint_if_integer().is_none());
    }

    // ---- large numerator/denominator (beyond i64) ----

    #[test]
    fn large_rational_exactness_beyond_i64() {
        // Numerator/denominator both well beyond i64::MAX, sharing a large
        // common factor, to prove reduction + arithmetic stay exact.
        let big_num = BigIntT::from_decimal_str("99999999999999999999000").unwrap(); // = 99999999999999999999 * 1000
        let big_den = BigIntT::from_decimal_str("300000000000000000003").unwrap(); // = 99999999999999999999 * 3 + ... actually just use gcd-derived values below
        // Construct two big numbers sharing a known factor F, so we can
        // hand-verify the reduced result: F = 99999999999999999999 (20 nines),
        // num = F * 1000, den = F * 4 -> reduces to 1000/4 = 250/1.
        let f = BigIntT::from_decimal_str("99999999999999999999").unwrap();
        let num = f.mul(&BigIntT::from_i64(1000));
        let den = f.mul(&BigIntT::from_i64(4));
        let r = RationalT::new(num, den);
        assert_eq!(r.num.to_string(), "250");
        assert_eq!(r.den.to_string(), "1");
        assert_eq!(r.to_bigint_if_integer().unwrap().to_string(), "250");

        // A second large case that does NOT reduce to an integer: F/(F*3+1)
        // shares no obvious small factor with the numerator, so it should
        // stay a genuine large-magnitude fraction after reduction.
        let r2 = RationalT::new(f.clone(), f.mul(&BigIntT::from_i64(3)).add(&BigIntT::from_i64(1)));
        assert!(r2.to_bigint_if_integer().is_none());
        // Reconstruct via cross-multiplication identity to confirm exactness
        // of the stored reduced form against the original (unreduced-here)
        // ratio: r2.num * original_den == original_num * r2.den.
        let orig_den = f.mul(&BigIntT::from_i64(3)).add(&BigIntT::from_i64(1));
        let lhs = r2.num.mul(&orig_den);
        let rhs = f.mul(&r2.den);
        assert!(lhs.eq(&rhs));

        // silence unused-var warnings from the scratch values above
        let _ = (&big_num, &big_den);
    }

    // ---- ComplexT arithmetic ----

    fn c_int(re: i64, im: i64) -> ComplexT {
        ComplexT::new(NumT::Int(re), NumT::Int(im))
    }

    fn as_ints(c: &ComplexT) -> (i64, i64) {
        let re = match &c.re {
            NumT::Int(n) => *n,
            other => panic!("expected Int re, got {other:?}"),
        };
        let im = match &c.im {
            NumT::Int(n) => *n,
            other => panic!("expected Int im, got {other:?}"),
        };
        (re, im)
    }

    #[test]
    fn complex_add_matches_hand_computed() {
        // (2+3i) + (4-5i) = 6-2i
        let a = c_int(2, 3);
        let b = c_int(4, -5);
        assert_eq!(as_ints(&a.add(&b)), (6, -2));
    }

    #[test]
    fn complex_sub_matches_hand_computed() {
        // (2+3i) - (4-5i) = -2+8i
        let a = c_int(2, 3);
        let b = c_int(4, -5);
        assert_eq!(as_ints(&a.sub(&b)), (-2, 8));
    }

    #[test]
    fn complex_mul_matches_hand_computed() {
        // (2+3i) * (4-5i) = (8 - (-15)) + (-10+12)i = 23 + 2i
        let a = c_int(2, 3);
        let b = c_int(4, -5);
        assert_eq!(as_ints(&a.mul(&b)), (23, 2));
    }

    #[test]
    fn complex_div_matches_hand_computed() {
        // (23+2i) / (4-5i): multiply by conjugate (4+5i):
        // numerator = (23+2i)(4+5i) = (92-10) + (115+8)i = 82+123i
        // denom = 16+25 = 41
        // result = 82/41 + 123/41 i = 2 + 3i
        let numerator = c_int(23, 2);
        let divisor = c_int(4, -5);
        let got = numerator.div(&divisor);
        assert_eq!(as_ints(&got), (2, 3));
    }

    #[test]
    fn complex_to_real_if_zero_imaginary() {
        let zero_im = c_int(7, 0);
        let got = zero_im.to_real_if_zero_imaginary();
        assert!(got.is_some());
        match got.unwrap() {
            NumT::Int(n) => assert_eq!(n, 7),
            other => panic!("expected Int, got {other:?}"),
        }

        let nonzero_im = c_int(7, 1);
        assert!(nonzero_im.to_real_if_zero_imaginary().is_none());
    }

    #[test]
    fn complex_mixed_kind_int_float_promotion() {
        // (1 + 2.5i) + (3 + 0.5i) = 4 + 3.0i, exercising NumT's Int/Float
        // promotion dispatch inside ComplexT::add.
        let a = ComplexT::new(NumT::Int(1), NumT::Float(2.5));
        let b = ComplexT::new(NumT::Int(3), NumT::Float(0.5));
        let got = a.add(&b);
        match got.re {
            NumT::Int(n) => assert_eq!(n, 4),
            NumT::Float(f) => assert_eq!(f, 4.0),
            other => panic!("unexpected re kind: {other:?}"),
        }
        match got.im {
            NumT::Float(f) => assert!((f - 3.0).abs() < 1e-12),
            other => panic!("expected Float im, got {other:?}"),
        }
    }

    // ---- NumT / to_f64 sanity ----

    #[test]
    fn rational_to_f64_lossy_but_close() {
        let r = RationalT::from_i64_pair(1, 4);
        assert!((r.to_f64() - 0.25).abs() < 1e-12);
    }

    #[test]
    fn numt_add_overflow_promotes_to_big() {
        let a = NumT::Int(i64::MAX);
        let b = NumT::Int(1);
        match a.add(&b) {
            NumT::Big(v) => assert_eq!(v.to_string(), (i64::MAX as i128 + 1).to_string()),
            other => panic!("expected Big after overflow, got {other:?}"),
        }
    }
}
