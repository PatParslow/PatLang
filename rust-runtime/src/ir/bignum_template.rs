//! Stage 38 Milestone 1 — hand-rolled, self-contained arbitrary-precision
//! BigInt, written as ordinary compiler-checked Rust so its arithmetic can be
//! verified by `cargo test` BEFORE it is later hand-copied (Milestone 3) into
//! a `&'static str` prelude chunk in `ir/codegen.rs`.
//!
//! DELIBERATE ASYMMETRY (see `review-memory-for-the-swirling-octopus.md`,
//! Stage 38): the *interpreter* uses the real `num_bigint::BigInt` crate
//! (`ir/numeric.rs`). This module is a SEPARATE, independent implementation
//! for *emitted/compiled PatLang programs*, which build via bare `rustc` on
//! a single `.rs` file with zero `Cargo.toml`/dependencies
//! (`compile_source_to_exe` in `ir/hosts.rs`) — so the emitted program cannot
//! depend on `num_bigint`. This type is named `BigIntT` (not `BigInt`)
//! specifically so it is never confused with `num_bigint::BigInt`.
//!
//! This file is NOT wired into codegen.rs, ChunkId, or any prelude chunk yet
//! — that's a later milestone. This is a pure, standalone addition: std-only,
//! no external crates, nothing else in the repo touched.
//!
//! ## Representation choice: decimal limbs (base 1_000_000_000), not base 2^32
//!
//! Chosen over binary (base 2^32) limbs deliberately, even though binary
//! limbs would make `add`/`sub`/`mul` marginally simpler (no need to mask
//! carries against a non-power-of-two base):
//!   - `to_string`/`from_decimal_str` are the operations this type will be
//!     exercised through constantly (every PatLang integer literal is
//!     decimal, and every printed value is decimal). With decimal limbs,
//!     converting is a trivial per-limb zero-padded concatenation/parse in
//!     each direction. With binary limbs, decimal conversion requires a full
//!     repeated-divide-by-10^9 (or by 10) pass — extra logic that is exactly
//!     the kind of "one more place to get subtly wrong" this task exists to
//!     avoid before hand-transcription into a string literal.
//!   - The whole point of this module (per the plan) is "known-correct
//!     enough to blindly copy into a template later" — fewer distinct pieces
//!     of logic (no separate binary<->decimal conversion routine) means less
//!     surface area for a transcription slip in Milestone 3.
//!   - Base 1_000_000_000 (10^9) is the largest power of ten such that two
//!     limbs multiplied together (< 10^18) fit in a u64 without overflow,
//!     which is what schoolbook `mul`'s inner product needs.

use std::cmp::Ordering;
use std::fmt;

/// Sign of a `BigIntT`. Magnitude zero is always `Sign::Zero` (canonical —
/// there is exactly one representation of zero, never `Positive`/`Negative`
/// with an empty/all-zero limb vec). This sidesteps a whole class of
/// "negative zero" edge cases in comparison and normalization.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Sign {
    Zero,
    Positive,
    Negative,
}

/// Base of each limb: 10^9. Two limbs' product is < 10^18, well within u64.
const BASE: u64 = 1_000_000_000;
const BASE_DIGITS: usize = 9;

/// Sign-magnitude arbitrary-precision integer. `limbs` is little-endian
/// (least-significant limb first), always normalized: no trailing
/// (most-significant) zero limbs, and `limbs` is empty iff `sign == Zero`.
#[derive(Debug, Clone)]
pub struct BigIntT {
    sign: Sign,
    limbs: Vec<u32>, // each limb in [0, BASE)
}

impl BigIntT {
    /// Canonical zero.
    pub fn zero() -> Self {
        BigIntT { sign: Sign::Zero, limbs: Vec::new() }
    }

    pub fn is_zero(&self) -> bool {
        self.sign == Sign::Zero
    }

    pub fn is_negative(&self) -> bool {
        self.sign == Sign::Negative
    }

    /// Strip trailing (most-significant) zero limbs and fix up sign to the
    /// canonical Zero case if the magnitude collapsed to nothing.
    fn normalize(mut self) -> Self {
        while self.limbs.last() == Some(&0) {
            self.limbs.pop();
        }
        if self.limbs.is_empty() {
            self.sign = Sign::Zero;
        }
        self
    }

    pub fn from_i64(n: i64) -> Self {
        if n == 0 {
            return BigIntT::zero();
        }
        let sign = if n < 0 { Sign::Negative } else { Sign::Positive };
        // i64::MIN negation would overflow i64; go via i128/u64 instead.
        let mut mag: u64 = if n == i64::MIN {
            (i64::MAX as u64) + 1
        } else {
            n.unsigned_abs()
        };
        let mut limbs = Vec::new();
        if mag == 0 {
            limbs.push(0);
        }
        while mag > 0 {
            limbs.push((mag % BASE) as u32);
            mag /= BASE;
        }
        BigIntT { sign, limbs }.normalize()
    }

    /// Parse a decimal string, optionally signed (`-123`, `+123`, `123`).
    /// Returns `None` on malformed input (empty digits, non-digit chars).
    pub fn from_decimal_str(s: &str) -> Option<Self> {
        let s = s.trim();
        if s.is_empty() {
            return None;
        }
        let (neg, digits) = match s.as_bytes()[0] {
            b'-' => (true, &s[1..]),
            b'+' => (false, &s[1..]),
            _ => (false, s),
        };
        if digits.is_empty() || !digits.bytes().all(|b| b.is_ascii_digit()) {
            return None;
        }
        // Strip leading zeros for parsing convenience (e.g. "000123").
        let trimmed = digits.trim_start_matches('0');
        if trimmed.is_empty() {
            return Some(BigIntT::zero());
        }
        let mut limbs = Vec::new();
        let bytes = trimmed.as_bytes();
        let mut end = bytes.len();
        while end > 0 {
            let start = if end >= BASE_DIGITS { end - BASE_DIGITS } else { 0 };
            let chunk = std::str::from_utf8(&bytes[start..end]).unwrap();
            let limb: u32 = chunk.parse().unwrap();
            limbs.push(limb);
            end = start;
        }
        let sign = if neg { Sign::Negative } else { Sign::Positive };
        Some(BigIntT { sign, limbs }.normalize())
    }

    pub fn to_string(&self) -> String {
        if self.is_zero() {
            return "0".to_string();
        }
        let mut s = String::new();
        if self.sign == Sign::Negative {
            s.push('-');
        }
        // Most-significant limb printed without zero-padding, the rest
        // zero-padded to BASE_DIGITS so concatenation is positionally correct.
        let mut iter = self.limbs.iter().rev();
        let msl = iter.next().unwrap();
        s.push_str(&msl.to_string());
        for limb in iter {
            s.push_str(&format!("{:0width$}", limb, width = BASE_DIGITS));
        }
        s
    }

    pub fn negate(&self) -> Self {
        let sign = match self.sign {
            Sign::Zero => Sign::Zero,
            Sign::Positive => Sign::Negative,
            Sign::Negative => Sign::Positive,
        };
        BigIntT { sign, limbs: self.limbs.clone() }
    }

    /// Compare magnitudes only (ignores sign).
    fn cmp_mag(a: &[u32], b: &[u32]) -> Ordering {
        if a.len() != b.len() {
            return a.len().cmp(&b.len());
        }
        for i in (0..a.len()).rev() {
            if a[i] != b[i] {
                return a[i].cmp(&b[i]);
            }
        }
        Ordering::Equal
    }

    fn add_mag(a: &[u32], b: &[u32]) -> Vec<u32> {
        let mut result = Vec::with_capacity(a.len().max(b.len()) + 1);
        let mut carry: u64 = 0;
        for i in 0..a.len().max(b.len()) {
            let av = *a.get(i).unwrap_or(&0) as u64;
            let bv = *b.get(i).unwrap_or(&0) as u64;
            let sum = av + bv + carry;
            result.push((sum % BASE) as u32);
            carry = sum / BASE;
        }
        if carry > 0 {
            result.push(carry as u32);
        }
        result
    }

    /// Subtract magnitudes: requires a >= b. Result has no trailing zero
    /// limbs guaranteed by caller's `.normalize()`.
    fn sub_mag(a: &[u32], b: &[u32]) -> Vec<u32> {
        let mut result = Vec::with_capacity(a.len());
        let mut borrow: i64 = 0;
        for i in 0..a.len() {
            let av = a[i] as i64;
            let bv = *b.get(i).unwrap_or(&0) as i64;
            let mut diff = av - bv - borrow;
            if diff < 0 {
                diff += BASE as i64;
                borrow = 1;
            } else {
                borrow = 0;
            }
            result.push(diff as u32);
        }
        result
    }

    pub fn add(&self, other: &BigIntT) -> BigIntT {
        if self.is_zero() {
            return other.clone();
        }
        if other.is_zero() {
            return self.clone();
        }
        if self.sign == other.sign {
            BigIntT { sign: self.sign, limbs: Self::add_mag(&self.limbs, &other.limbs) }
                .normalize()
        } else {
            // Different signs: subtract smaller magnitude from larger,
            // result takes the sign of the larger-magnitude operand.
            match Self::cmp_mag(&self.limbs, &other.limbs) {
                Ordering::Equal => BigIntT::zero(),
                Ordering::Greater => {
                    BigIntT { sign: self.sign, limbs: Self::sub_mag(&self.limbs, &other.limbs) }
                        .normalize()
                }
                Ordering::Less => {
                    BigIntT { sign: other.sign, limbs: Self::sub_mag(&other.limbs, &self.limbs) }
                        .normalize()
                }
            }
        }
    }

    pub fn sub(&self, other: &BigIntT) -> BigIntT {
        self.add(&other.negate())
    }

    pub fn mul(&self, other: &BigIntT) -> BigIntT {
        if self.is_zero() || other.is_zero() {
            return BigIntT::zero();
        }
        let mut result = vec![0u64; self.limbs.len() + other.limbs.len()];
        for (i, &av) in self.limbs.iter().enumerate() {
            if av == 0 {
                continue;
            }
            let mut carry: u64 = 0;
            for (j, &bv) in other.limbs.iter().enumerate() {
                let idx = i + j;
                let prod = (av as u64) * (bv as u64) + result[idx] + carry;
                result[idx] = prod % BASE;
                carry = prod / BASE;
            }
            let mut k = i + other.limbs.len();
            while carry > 0 {
                let sum = result[k] + carry;
                result[k] = sum % BASE;
                carry = sum / BASE;
                k += 1;
            }
        }
        let sign = if self.sign == other.sign { Sign::Positive } else { Sign::Negative };
        let limbs: Vec<u32> = result.into_iter().map(|x| x as u32).collect();
        BigIntT { sign, limbs }.normalize()
    }

    /// Long division: returns (quotient, remainder). Remainder has the same
    /// sign as the dividend (truncating division, matching Rust's native
    /// integer division semantics), or is zero. Panics on division by zero,
    /// matching native integer division's own panic behavior.
    pub fn div_rem(&self, other: &BigIntT) -> (BigIntT, BigIntT) {
        if other.is_zero() {
            panic!("BigIntT division by zero");
        }
        if self.is_zero() {
            return (BigIntT::zero(), BigIntT::zero());
        }
        if Self::cmp_mag(&self.limbs, &other.limbs) == Ordering::Less {
            // |self| < |other|: quotient 0, remainder == self exactly.
            return (BigIntT::zero(), self.clone());
        }

        // Schoolbook long division, digit-by-digit over decimal limbs:
        // process from the most-significant limb down, maintaining a
        // running remainder, and at each step find the largest digit d in
        // [0, BASE) such that other_mag * d <= running_remainder, via
        // binary search (avoids a per-limb linear scan up to 1e9).
        let other_mag = BigIntT { sign: Sign::Positive, limbs: other.limbs.clone() };
        let mut remainder = BigIntT::zero();
        let mut quotient_limbs = vec![0u32; self.limbs.len()];

        for i in (0..self.limbs.len()).rev() {
            // remainder = remainder * BASE + self.limbs[i]
            remainder = remainder.mul_by_base().add(&BigIntT::from_i64(self.limbs[i] as i64));

            // Binary search largest d in [0, BASE-1] with other_mag*d <= remainder
            let mut lo: u64 = 0;
            let mut hi: u64 = BASE - 1;
            while lo < hi {
                let mid = (lo + hi + 1) / 2;
                let candidate = other_mag.mul(&BigIntT::from_i64(mid as i64));
                if Self::cmp_mag(&candidate.limbs, &remainder.limbs) != Ordering::Greater {
                    lo = mid;
                } else {
                    hi = mid - 1;
                }
            }
            quotient_limbs[i] = lo as u32;
            remainder = remainder.sub(&other_mag.mul(&BigIntT::from_i64(lo as i64)));
        }

        let quotient_sign_positive = self.sign == other.sign;
        let quotient = BigIntT {
            sign: if quotient_limbs.iter().all(|&x| x == 0) {
                Sign::Zero
            } else if quotient_sign_positive {
                Sign::Positive
            } else {
                Sign::Negative
            },
            limbs: quotient_limbs,
        }
        .normalize();

        // Remainder takes the dividend's sign (truncating division).
        let remainder = if remainder.is_zero() {
            BigIntT::zero()
        } else {
            BigIntT { sign: self.sign, limbs: remainder.limbs }.normalize()
        };

        (quotient, remainder)
    }

    /// Multiply by BASE (shift limbs up by one position) — helper for
    /// long division's running remainder update.
    fn mul_by_base(&self) -> BigIntT {
        if self.is_zero() {
            return BigIntT::zero();
        }
        let mut limbs = Vec::with_capacity(self.limbs.len() + 1);
        limbs.push(0);
        limbs.extend_from_slice(&self.limbs);
        BigIntT { sign: self.sign, limbs }.normalize()
    }

    /// Full ordering (sign-aware).
    pub fn cmp(&self, other: &BigIntT) -> Ordering {
        use Sign::*;
        match (self.sign, other.sign) {
            (Zero, Zero) => Ordering::Equal,
            (Zero, Positive) => Ordering::Less,
            (Zero, Negative) => Ordering::Greater,
            (Positive, Zero) => Ordering::Greater,
            (Negative, Zero) => Ordering::Less,
            (Positive, Negative) => Ordering::Greater,
            (Negative, Positive) => Ordering::Less,
            (Positive, Positive) => Self::cmp_mag(&self.limbs, &other.limbs),
            (Negative, Negative) => Self::cmp_mag(&other.limbs, &self.limbs),
        }
    }

    pub fn eq(&self, other: &BigIntT) -> bool {
        self.cmp(other) == Ordering::Equal
    }
}

impl fmt::Display for BigIntT {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.to_string())
    }
}

impl PartialEq for BigIntT {
    fn eq(&self, other: &Self) -> bool {
        BigIntT::eq(self, other)
    }
}
impl Eq for BigIntT {}

impl PartialOrd for BigIntT {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}
impl Ord for BigIntT {
    fn cmp(&self, other: &Self) -> Ordering {
        BigIntT::cmp(self, other)
    }
}

/// Greatest common divisor of two `BigIntT`s, always returned non-negative.
/// Needed later for exact-`Rational` reduction (Stage 38 Milestone 2) —
/// implemented now since the Euclidean algorithm is a direct, low-risk
/// application of `div_rem`, already built above.
pub fn gcd(a: &BigIntT, b: &BigIntT) -> BigIntT {
    let mut a = BigIntT { sign: if a.is_zero() { Sign::Zero } else { Sign::Positive }, limbs: a.limbs.clone() };
    let mut b = BigIntT { sign: if b.is_zero() { Sign::Zero } else { Sign::Positive }, limbs: b.limbs.clone() };
    while !b.is_zero() {
        let (_, r) = a.div_rem(&b);
        let r_abs = BigIntT { sign: if r.is_zero() { Sign::Zero } else { Sign::Positive }, limbs: r.limbs };
        a = b;
        b = r_abs;
    }
    a
}

#[cfg(test)]
mod tests {
    use super::*;

    fn b(n: i64) -> BigIntT {
        BigIntT::from_i64(n)
    }

    // ---- Basic sanity: small values match plain i64 arithmetic ----

    #[test]
    fn small_add_matches_i64() {
        for a in -20i64..20 {
            for c in -20i64..20 {
                let expected = a + c;
                let got = b(a).add(&b(c));
                assert_eq!(got.to_string(), expected.to_string(), "{a} + {c}");
            }
        }
    }

    #[test]
    fn small_sub_matches_i64() {
        for a in -20i64..20 {
            for c in -20i64..20 {
                let expected = a - c;
                let got = b(a).sub(&b(c));
                assert_eq!(got.to_string(), expected.to_string(), "{a} - {c}");
            }
        }
    }

    #[test]
    fn small_mul_matches_i64() {
        for a in -20i64..20 {
            for c in -20i64..20 {
                let expected = a * c;
                let got = b(a).mul(&b(c));
                assert_eq!(got.to_string(), expected.to_string(), "{a} * {c}");
            }
        }
    }

    #[test]
    fn small_div_rem_matches_i64() {
        for a in -20i64..20 {
            for c in -20i64..20 {
                if c == 0 {
                    continue;
                }
                let (q, r) = b(a).div_rem(&b(c));
                assert_eq!(q.to_string(), (a / c).to_string(), "{a} / {c}");
                assert_eq!(r.to_string(), (a % c).to_string(), "{a} % {c}");
            }
        }
    }

    #[test]
    fn small_cmp_matches_i64() {
        for a in -20i64..20 {
            for c in -20i64..20 {
                assert_eq!(b(a).cmp(&b(c)), a.cmp(&c), "{a} cmp {c}");
            }
        }
    }

    // ---- Overflow-scale correctness ----

    #[test]
    fn multiply_beyond_i64_max() {
        // 99999999999999999999 (20 nines) * 99999999999999999999
        let x = BigIntT::from_decimal_str("99999999999999999999").unwrap();
        let y = BigIntT::from_decimal_str("99999999999999999999").unwrap();
        let got = x.mul(&y);
        // Hand-verified: (10^20 - 1)^2 = 10^40 - 2*10^20 + 1
        let expected =
            "9999999999999999999800000000000000000001";
        assert_eq!(got.to_string(), expected);
    }

    #[test]
    fn multiply_i64_max_by_i64_max() {
        // i64::MAX = 9223372036854775807
        let m = i64::MAX;
        let x = b(m);
        let got = x.mul(&x);
        let expected = (m as i128) * (m as i128);
        assert_eq!(got.to_string(), expected.to_string());
    }

    #[test]
    fn factorial_20_matches_known_value() {
        // 20! = 2432902008176640000 (fits in i64, cross-checkable directly)
        let mut acc = b(1);
        for i in 1..=20i64 {
            acc = acc.mul(&b(i));
        }
        assert_eq!(acc.to_string(), "2432902008176640000");
    }

    #[test]
    fn factorial_30_beyond_i64() {
        // 30! = 265252859812191058636308480000000 (known value, exceeds i64::MAX)
        let mut acc = b(1);
        for i in 1..=30i64 {
            acc = acc.mul(&b(i));
        }
        assert_eq!(acc.to_string(), "265252859812191058636308480000000");
    }

    // ---- Division edge cases ----

    #[test]
    fn div_exact() {
        let (q, r) = b(100).div_rem(&b(5));
        assert_eq!(q.to_string(), "20");
        assert!(r.is_zero());
    }

    #[test]
    fn div_with_remainder() {
        let (q, r) = b(17).div_rem(&b(5));
        assert_eq!(q.to_string(), "3");
        assert_eq!(r.to_string(), "2");
    }

    #[test]
    fn div_divisor_larger_than_dividend() {
        let (q, r) = b(5).div_rem(&b(17));
        assert!(q.is_zero());
        assert_eq!(r.to_string(), "5");
    }

    #[test]
    fn div_sign_combinations() {
        // Matches Rust's native truncating i64 division/remainder exactly.
        let cases: &[(i64, i64)] = &[(17, 5), (-17, 5), (17, -5), (-17, -5), (7, 3), (-7, 3), (7, -3), (-7, -3)];
        for &(a, c) in cases {
            let (q, r) = b(a).div_rem(&b(c));
            assert_eq!(q.to_string(), (a / c).to_string(), "quotient {a}/{c}");
            assert_eq!(r.to_string(), (a % c).to_string(), "remainder {a}%{c}");
        }
    }

    #[test]
    fn div_large_values() {
        let dividend = BigIntT::from_decimal_str("123456789012345678901234567890").unwrap();
        let divisor = BigIntT::from_decimal_str("987654321").unwrap();
        let (q, r) = dividend.div_rem(&divisor);
        // Reconstruct: dividend == divisor*q + r, and verify sign/magnitude of r.
        let reconstructed = divisor.mul(&q).add(&r);
        assert_eq!(reconstructed.to_string(), dividend.to_string());
        assert!(r.cmp(&divisor).is_lt() || r.is_zero());
    }

    #[test]
    #[should_panic(expected = "division by zero")]
    fn div_by_zero_panics() {
        let _ = b(5).div_rem(&b(0));
    }

    // ---- Negative number arithmetic ----

    #[test]
    fn negative_add_sub_mul() {
        assert_eq!(b(-5).add(&b(3)).to_string(), "-2");
        assert_eq!(b(-5).add(&b(-3)).to_string(), "-8");
        assert_eq!(b(5).sub(&b(-3)).to_string(), "8");
        assert_eq!(b(-5).mul(&b(-3)).to_string(), "15");
        assert_eq!(b(-5).mul(&b(3)).to_string(), "-15");
    }

    #[test]
    fn zero_handling() {
        assert!(BigIntT::zero().is_zero());
        assert_eq!(BigIntT::zero().to_string(), "0");
        assert!(b(5).sub(&b(5)).is_zero());
        assert!(!b(5).sub(&b(5)).is_negative());
        assert_eq!(b(0).mul(&b(12345)).to_string(), "0");
        assert_eq!(b(0).negate().to_string(), "0");
        assert!(!b(0).negate().is_negative());
    }

    // ---- gcd ----

    #[test]
    fn gcd_known_pairs() {
        assert_eq!(gcd(&b(48), &b(18)).to_string(), "6");
        assert_eq!(gcd(&b(17), &b(5)).to_string(), "1"); // coprime
        assert_eq!(gcd(&b(0), &b(5)).to_string(), "5");
        assert_eq!(gcd(&b(5), &b(0)).to_string(), "5");
        assert_eq!(gcd(&b(-48), &b(18)).to_string(), "6");
        assert_eq!(gcd(&b(-48), &b(-18)).to_string(), "6");
    }

    #[test]
    fn gcd_large_values() {
        let x = BigIntT::from_decimal_str("123456789123456789").unwrap();
        let y = BigIntT::from_decimal_str("987654321987654321").unwrap();
        let g = gcd(&x, &y);
        // Both x and y must be exactly divisible by g with zero remainder.
        let (_, rx) = x.div_rem(&g);
        let (_, ry) = y.div_rem(&g);
        assert!(rx.is_zero());
        assert!(ry.is_zero());
    }

    // ---- Round-trip: from_decimal_str(x.to_string()) == x ----

    #[test]
    fn round_trip_various_values() {
        let values = [
            "0",
            "1",
            "-1",
            "42",
            "-42",
            "999999999",
            "1000000000",
            "-1000000000",
            "123456789012345678901234567890",
            "-123456789012345678901234567890",
            "9223372036854775807",
            "-9223372036854775808",
        ];
        for v in values {
            let parsed = BigIntT::from_decimal_str(v).unwrap();
            assert_eq!(parsed.to_string(), v, "round trip for {v}");
        }
    }

    #[test]
    fn from_decimal_str_rejects_malformed() {
        assert!(BigIntT::from_decimal_str("").is_none());
        assert!(BigIntT::from_decimal_str("abc").is_none());
        assert!(BigIntT::from_decimal_str("12a34").is_none());
        assert!(BigIntT::from_decimal_str("-").is_none());
        assert!(BigIntT::from_decimal_str("+").is_none());
    }

    #[test]
    fn from_decimal_str_leading_zeros() {
        assert_eq!(BigIntT::from_decimal_str("007").unwrap().to_string(), "7");
        assert_eq!(BigIntT::from_decimal_str("000").unwrap().to_string(), "0");
        assert_eq!(BigIntT::from_decimal_str("-007").unwrap().to_string(), "-7");
    }

    #[test]
    fn i64_min_round_trips() {
        // i64::MIN negation overflows i64 natively; verify our unsigned_abs
        // workaround in from_i64 produces the exact correct magnitude.
        let v = BigIntT::from_i64(i64::MIN);
        assert_eq!(v.to_string(), i64::MIN.to_string());
    }
}
