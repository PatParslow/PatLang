fn main() {
    let mut v: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < 2_000_000 {
        v.push(i);
        i += 1;
    }
    let mut total: i64 = 0;
    for x in &v {
        total += *x;
    }
    println!("{}", total);
}
