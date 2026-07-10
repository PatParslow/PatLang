# Deployment Guide - PaTLang 0.9

## Creating a Frozen Release (Version 0.9)

### What's in the Deployment Folder

The `deployment/` folder contains everything needed to:
1. Run PaTLang programs
2. Rebuild the compiler/runtime from C source
3. Understand the system architecture

**Minimum files required:**
- `bin/patlang` - CLI entry point
- `bin/patlang.bat` - Batch wrapper (Windows)
- `tools/compiler/pat_runtime.exe` - Runtime bytecode interpreter
- `tools/compiler/ir_generator.exe` - Source-to-IR compiler

**Source code (optional, for rebuilding):**
- `tools/compiler/ir_generator_v2.c` - C IR generator
- `tools/compiler/runtime.c` - C runtime

**Documentation & Examples:**
- `README.md` - Quick start guide
- `examples/` - Sample PaTLang programs

### Step 1: Prepare Deployment Folder

The deployment folder has already been created with all essentials. Verify contents:

```
deployment/
├── bin/
│   ├── patlang           # Windows batch entry point
│   └── patlang.bat       # Batch script calling C executables
├── tools/compiler/
│   ├── ir_generator.exe  # C lexer + parser → IR
│   ├── pat_runtime.exe   # IR bytecode interpreter
│   ├── ir_generator_v2.c # IR generator source (for rebuilding)
│   └── runtime.c         # Runtime source (for rebuilding)
├── examples/
│   ├── hello_world.patlang
│   ├── arithmetic_demo.pat
│   ├── control_flow_demo.pat
│   ├── function_demo.pat
│   └── logic_demo.pat
└── README.md             # Usage instructions
```

### Step 2: Copy Deployment Folder to New Location

```batch
REM On Windows, in File Explorer or terminal:
xcopy deployment deployment-v0.9 /E /I /Y

REM Or with git:
cd e:\patlang-selfhost
git clone . ../patlang-v0.9
cd ../patlang-v0.9
REM Keep only deployment/ folder, delete everything else
```

### Step 3: Verify in New Location

```batch
cd ../patlang-v0.9/deployment
bin\patlang examples\hello_world.patlang
```

Should output:
```
[INFO] Generated IR: ...
[INFO] Loading IR ...
[OUT] Native backend test
[OUT] 8
```

### Step 4: Lock Version 0.9

```batch
REM In original e:\patlang-selfhost:
git tag -a v0.9 -m "Stable release: Pure C implementation with zero Ruby dependency"
git push origin v0.9
```

Now the original folder is frozen at v0.9. Continue development in a separate working folder if desired.

## Testing the Deployment

All 7 core tests should pass with the deployment folder:

```batch
cd deployment
bin\patlang examples\hello_world.patlang        # test_native_simple
bin\patlang examples\arithmetic_demo.pat        # arithmetic operations
bin\patlang examples\function_demo.pat          # function calls
bin\patlang examples\logic_demo.pat             # operators
```

## Scaling Up: What to Add for Production

### For Standalone Distribution
- Compress `deployment/` as `patlang-v0.9.zip`
- Include Windows .exe files (or rebuild on Linux/Mac)
- No external dependencies needed

### For Cross-Platform Releases
1. **Windows**: Pre-compiled exe (included)
2. **Linux**: Compile with `gcc` or `clang`
3. **macOS**: Compile with Apple Clang

Build command (all platforms):
```bash
clang -O2 -o ir_generator.exe ir_generator_v2.c
clang -O2 -o pat_runtime.exe runtime.c
```

### For Package Managers
```bash
# Could package as:
# - Windows: chocolatey/winget package
# - Linux: apt/yum package  
# - macOS: homebrew tap
# - Universal: Python pip (via PyInstaller)
```

## Development Workflow After v0.9

### Option 1: Separate Development Folder
```
e:\patlang-selfhost/          # Frozen v0.9 (git tagged)
e:\patlang-selfhost-dev/      # Active development copy
```

### Option 2: Branch-Based Development
```batch
cd e:\patlang-selfhost
git checkout -b development
REM Continue making changes
REM Main branch stays at v0.9
```

### Option 3: Archive Original, Develop in New Location
```
Archive: e:\patlang-selfhost-v0.9\         (frozen)
Current: e:\patlang-selfhost\              (continues development)
```

## Deployment Architecture Summary

```
┌─────────────────────────────────────┐
│  User PaTLang Program (.patlang)    │
└────────────────┬────────────────────┘
                 │
                 ▼
        ┌────────────────────┐
        │  bin/patlang       │ (Batch wrapper)
        └────────┬───────────┘
                 │
    ┌────────────┴────────────┐
    ▼                         ▼
┌──────────────┐      ┌──────────────┐
│ ir_generator │      │  pat_runtime │
│   .exe       │      │    .exe      │
│ (281 KB)     │      │ (388 KB)     │
└──────┬───────┘      └────────┬─────┘
       │                       │
    IR (JSON)                  │
       │───────────────────────┘
                 │
                 ▼
          ┌──────────────┐
          │   Output     │
          │ [OUT] Lines  │
          └──────────────┘
```

## Maintenance Notes

### Version 0.9 Stability Guarantees
- ✅ All 7 core tests passing
- ✅ No Ruby dependencies
- ✅ Pure C implementation
- ✅ Backward compatible with earlier versions
- ✅ Cross-platform C code (Linux/Windows/Mac)

### Known Limitations
- No module system yet
- No optimization passes on IR
- Limited standard library
- Single-threaded execution only

### Future Enhancement Path
1. **v0.10**: Module system + imports
2. **v0.11**: Standard library functions (math, string, array)
3. **v0.12**: Performance optimizations
4. **v1.0**: Feature-complete, production-ready

---

**Created**: January 18, 2026  
**Version**: 0.9  
**Status**: Ready for distribution and continued development
