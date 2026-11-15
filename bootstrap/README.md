# Bootstrapping v2 from its IR (GitHub #247)

`ir_reader.py` builds a Windows x64 executable from v2's IR
(`docs/spec/ir.md`), using only Python's standard library.
`v2_compiler.ir` is the compiler's own IR, so a machine with Python and
nothing of PatLang's builds the compiler with:

```
py -3 bootstrap/ir_reader.py bootstrap/v2_compiler.ir self_hosting/build/v2.exe
```

`self_hosting/v2/tools/gates.sh` does this when there is no `v2.exe`. Whenever
the compiler's sources or the reader change, the gates also rewrite
`v2_compiler.ir` with `v2.exe ... --ir`, build a compiler from it with the
reader, and check that this compiler builds the compiler byte for byte as
`v2.exe` does.

`ir_wasm.py` builds a WebAssembly module from the same IR (GitHub #248), byte
for byte what `v2.exe SRC OUT.wasm --wasm` writes. The module runs under the
host in `self_hosting/v2/wasm/`, in a browser or in Node. The gates check
that the two writers give the same bytes for the compiler's own module.

The reader takes the IR of a program compiled for it; `docs/spec/ir.md` gives the
form. A reader in another language needs only what that document gives.
