# Rust Patlang Runtime

## Test Coverage

To generate a code coverage report for the Rust Patlang runtime, use [cargo-tarpaulin](https://github.com/xd009642/tarpaulin):

```sh
cargo install cargo-tarpaulin
cargo tarpaulin --bin tests_runner --out Html
```

This will run all `.patlang` tests and produce a coverage report in `tarpaulin-report.html`.