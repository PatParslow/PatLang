# Setup Clean PaTLang Self-Hosting Project
# PowerShell script to copy only essential files to a new location

$sourceDir = "E:\patlang"
$targetDir = "C:\patlang-selfhost"

# Create the target directory structure
Write-Host "Creating directory structure at $targetDir..."
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
New-Item -ItemType Directory -Force -Path "$targetDir\bin" | Out-Null
New-Item -ItemType Directory -Force -Path "$targetDir\patlang-core\lexer" | Out-Null
New-Item -ItemType Directory -Force -Path "$targetDir\patlang-core\parser" | Out-Null
New-Item -ItemType Directory -Force -Path "$targetDir\patlang-core\evaluator" | Out-Null
New-Item -ItemType Directory -Force -Path "$targetDir\ruby-host" | Out-Null
New-Item -ItemType Directory -Force -Path "$targetDir\native_evaluator" | Out-Null

# Copy patlang-selfhost directory (complete)
Write-Host "Copying patlang-selfhost directory..."
Copy-Item -Path "$sourceDir\patlang-selfhost" -Destination "$targetDir" -Recurse -Force

# Copy bin files
Write-Host "Copying bin files..."
Copy-Item -Path "$sourceDir\bin\patlang" -Destination "$targetDir\bin\patlang" -Force
Copy-Item -Path "$sourceDir\bin\patlang.patlang" -Destination "$targetDir\bin\patlang.patlang" -Force

# Copy minimal patlang-core files
Write-Host "Copying patlang-core files..."
Copy-Item -Path "$sourceDir\patlang-core\exceptions.rb" -Destination "$targetDir\patlang-core\exceptions.rb" -Force
Copy-Item -Path "$sourceDir\patlang-core\lexer\*" -Destination "$targetDir\patlang-core\lexer\" -Recurse -Force
Copy-Item -Path "$sourceDir\patlang-core\parser\*" -Destination "$targetDir\patlang-core\parser\" -Recurse -Force
Copy-Item -Path "$sourceDir\patlang-core\evaluator\*" -Destination "$targetDir\patlang-core\evaluator\" -Recurse -Force

# Copy ruby-host files
Write-Host "Copying ruby-host files..."
Copy-Item -Path "$sourceDir\ruby-host\*" -Destination "$targetDir\ruby-host\" -Recurse -Force

# Copy native_evaluator bridge
Write-Host "Copying native_evaluator bridge..."
Copy-Item -Path "$sourceDir\native_evaluator\ruby_bridge.rb" -Destination "$targetDir\native_evaluator\ruby_bridge.rb" -Force

# Create a README file
Write-Host "Creating README file..."
@"
# Clean PaTLang Self-Hosting Project

This is a minimal clean project containing only the essential components
needed for the PaTLang self-hosting implementation.

## Running the project

```bash
cd $targetDir
ruby bin/patlang patlang-selfhost/tests/integration_suite.patlang
```

## Project Structure

- `bin/` - Main runner scripts
- `patlang-selfhost/` - Self-hosting implementation
  - `contracts/` - Contract definitions
  - `src/` - Source code for self-hosted implementation
  - `tests/` - Test suite
- `patlang-core/` - Minimal Ruby core components
- `ruby-host/` - Ruby host integration
- `native_evaluator/` - Native support bridge
"@ | Out-File -FilePath "$targetDir\README.md" -Encoding utf8

# Create a simple test script
Write-Host "Creating test script..."
@"
@echo off
ruby bin/patlang patlang-selfhost/tests/integration_suite.patlang
"@ | Out-File -FilePath "$targetDir\run_tests.bat" -Encoding utf8

Write-Host "Setup complete! The clean project is now available at $targetDir"
Write-Host "To run tests, navigate to $targetDir and execute run_tests.bat"
