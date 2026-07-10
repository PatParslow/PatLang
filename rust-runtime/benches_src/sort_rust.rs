// Manual quicksort (not slice::sort_unstable) so both languages run the
// same algorithm -- this is an algorithm-implementation comparison, not a
// "Rust's std library is fast" comparison.
fn quicksort(v: &mut Vec<i64>, lo: i64, hi: i64) {
    if lo >= hi {
        return;
    }
    let pivot = v[hi as usize];
    let mut i = lo - 1;
    let mut j = lo;
    while j < hi {
        if v[j as usize] < pivot {
            i += 1;
            v.swap(i as usize, j as usize);
        }
        j += 1;
    }
    v.swap((i + 1) as usize, hi as usize);
    let p = i + 1;
    quicksort(v, lo, p - 1);
    quicksort(v, p + 1, hi);
}

fn main() {
    let n: i64 = 50000;
    let mut v: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < n {
        // Deterministic pseudo-shuffle (Knuth multiplicative hash), so both
        // languages sort identical data without needing true randomness.
        let val = (i.wrapping_mul(2654435761)) % 1_000_000;
        v.push(val);
        i += 1;
    }
    quicksort(&mut v, 0, n - 1);
    println!("{} {}", v[0], v[(n - 1) as usize]);
}
