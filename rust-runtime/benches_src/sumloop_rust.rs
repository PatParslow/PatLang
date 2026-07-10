fn main() {
    let mut total: i64 = 0;
    let mut i: i64 = 1;
    while i <= 25_000_000 {
        total += i;
        i += 1;
    }
    println!("{}", total);
}
