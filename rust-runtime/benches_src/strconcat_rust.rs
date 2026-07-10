// Idiomatic Rust: String::push_str is the natural way to build a large
// string incrementally (amortized O(1) append via a growable buffer). This
// is a deliberately asymmetric comparison against PatLang's `+` (PatLang has
// no mutable string-builder primitive, only repeated concatenation) -- the
// point is to measure each language's actual idiomatic path, not force an
// artificial apples-to-apples on a primitive PatLang doesn't have.
fn main() {
    let mut s = String::new();
    let mut i: i64 = 0;
    while i < 400_000 {
        s.push_str("x");
        i += 1;
    }
    println!("{}", s.len());
}
