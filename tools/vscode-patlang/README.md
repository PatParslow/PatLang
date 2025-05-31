# Patlang Language Support for VSCode

This extension provides syntax highlighting for the Patlang programming language in Visual Studio Code.

## Features

- **Syntax Highlighting**: Full syntax highlighting for Patlang code
- **Auto-closing Pairs**: Automatic closing of brackets, quotes, and parentheses
- **Comment Support**: Line comment support with `#`
- **Indentation Rules**: Smart indentation for Patlang constructs

## Supported File Extensions

- `.pat`
- `.patlang`

## Syntax Elements

The extension highlights:

- **Keywords**: `make`, `a`, `called`, `if`, `then`, `else`, `while`, `for`, etc.
- **Types**: `number`, `text`, `time`, `email`, `list`, `template`, etc.
- **Operators**: `=`, `+`, `-`, `*`, `/`, `==`, `!=`, `<`, `>`, etc.
- **Literals**: Numbers, strings, booleans (`true`, `false`)
- **Comments**: Line comments starting with `#`

## Installation

### From VSIX (Recommended)

1. Download the `.vsix` file from releases
2. Open VSCode
3. Go to Extensions view (`Ctrl+Shift+X`)
4. Click the `...` menu and select "Install from VSIX..."
5. Select the downloaded `.vsix` file

### Manual Installation

1. Copy the `tools/vscode-patlang` folder to your VSCode extensions directory:
   - **Windows**: `%USERPROFILE%\.vscode\extensions\`
   - **macOS**: `~/.vscode/extensions/`
   - **Linux**: `~/.vscode/extensions/`

2. Restart VSCode

## Sample Patlang Code

```patlang
# Variable assignment and arithmetic
x = 42
y = 3.14
result = x + y * 2

# Control flow (future v0.3.0)
if result > 40 then
  emit success with result
else
  emit error with "Value too low"
end

# Functions (future v0.4.0)
make a function called calculate_sum {
  calculate_sum takes:
    numbers - list of number
  calculate_sum returns:
    numbers.reduce(|acc, n| acc + n, 0)
}
```

## Building the Extension

To build a `.vsix` package:

```bash
# Install vsce (VSCode Extension Manager)
npm install -g vsce

# Navigate to the extension directory
cd tools/vscode-patlang

# Package the extension
vsce package
```

This creates a `patlang-syntax-0.2.0.vsix` file that can be installed in VSCode.

## Contributing

Contributions to improve syntax highlighting are welcome! Please submit issues and pull requests to the main Patlang repository.

## License

This extension is part of the Patlang project and follows the same license terms.
