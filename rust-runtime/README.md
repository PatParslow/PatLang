# Rust Patlang Runtime

## Test Coverage

To generate a code coverage report for the Rust Patlang runtime, use [cargo-tarpaulin](https://github.com/xd009642/tarpaulin):

```sh
cargo install cargo-tarpaulin
cargo tarpaulin --bin tests_runner --out Html
```

This will run all `.patlang` tests and produce a coverage report in `tarpaulin-report.html`.

## Branch coverage with cargo-llvm-cov

For more accurate branch coverage, use cargo-llvm-cov:

```bash
cargo install cargo-llvm-cov
cargo llvm-cov --workspace --branch --html --open
```

Aliases are provided in Cargo.toml:

```bash
cargo cov        # generates lcov.info
cargo cov-html   # generates and opens HTML coverage report
```