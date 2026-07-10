@echo off
echo Setting up clean patlang-selfhost project at \patlang-selfhost

REM Create root directory and main structure
mkdir \patlang-selfhost
mkdir \patlang-selfhost\bin
mkdir \patlang-selfhost\patlang-core
mkdir \patlang-selfhost\patlang-core\lexer
mkdir \patlang-selfhost\patlang-core\parser
mkdir \patlang-selfhost\patlang-core\evaluator
mkdir \patlang-selfhost\ruby-host
mkdir \patlang-selfhost\native_evaluator
mkdir \patlang-selfhost\docs
mkdir \patlang-selfhost\examples

REM Copy patlang-selfhost directory (complete)
echo Copying patlang-selfhost directory...
xcopy /E /I /Y "e:\patlang\patlang-selfhost" "\patlang-selfhost\patlang-selfhost"

REM Copy bin files
echo Copying bin files...
copy "e:\patlang\bin\patlang" "\patlang-selfhost\bin\patlang"
copy "e:\patlang\bin\patlang.patlang" "\patlang-selfhost\bin\patlang.patlang"

REM Copy minimal patlang-core files
echo Copying patlang-core files...
copy "e:\patlang\patlang-core\exceptions.rb" "\patlang-selfhost\patlang-core\exceptions.rb"
xcopy /E /I /Y "e:\patlang\patlang-core\lexer" "\patlang-selfhost\patlang-core\lexer"
xcopy /E /I /Y "e:\patlang\patlang-core\parser" "\patlang-selfhost\patlang-core\parser"
xcopy /E /I /Y "e:\patlang\patlang-core\evaluator" "\patlang-selfhost\patlang-core\evaluator"

REM Copy ruby-host files
echo Copying ruby-host files...
xcopy /E /I /Y "e:\patlang\ruby-host" "\patlang-selfhost\ruby-host"

REM Copy native_evaluator bridge
echo Copying native_evaluator bridge...
copy "e:\patlang\native_evaluator\ruby_bridge.rb" "\patlang-selfhost\native_evaluator\ruby_bridge.rb"

REM Copy documentation
echo Copying documentation...
xcopy /E /I /Y "e:\patlang\docs" "\patlang-selfhost\docs"
copy "e:\patlang\*.md" "\patlang-selfhost\"
copy "e:\patlang\TEAM_EXECUTION_PLAN.md" "\patlang-selfhost\"
copy "e:\patlang\getting-started.md" "\patlang-selfhost\"
copy "e:\patlang\patlang-selfhost\TEAM_EXECUTION_PLAN.md" "\patlang-selfhost\"

REM Copy examples
echo Copying examples...
xcopy /E /I /Y "e:\patlang\examples" "\patlang-selfhost\examples"

REM Create demo directory with showcase files
mkdir \patlang-selfhost\demo
echo Creating showcase file for demo...
echo # PaTLang Integration Showcase > \patlang-selfhost\demo\showcase.patlang
echo include "../src/stdlib/io.patlang" >> \patlang-selfhost\demo\showcase.patlang
echo include "../src/stdlib/fs.patlang" >> \patlang-selfhost\demo\showcase.patlang
echo. >> \patlang-selfhost\demo\showcase.patlang
echo # Basic IO Demo >> \patlang-selfhost\demo\showcase.patlang
echo IO.puts("PaTLang Self-Hosting Demo") >> \patlang-selfhost\demo\showcase.patlang
echo. >> \patlang-selfhost\demo\showcase.patlang
echo # FS Operations >> \patlang-selfhost\demo\showcase.patlang
echo FS.write("demo_output.txt", "Hello from PaTLang!") >> \patlang-selfhost\demo\showcase.patlang
echo content = FS.read("demo_output.txt") >> \patlang-selfhost\demo\showcase.patlang
echo IO.puts("File content: " + content) >> \patlang-selfhost\demo\showcase.patlang
echo. >> \patlang-selfhost\demo\showcase.patlang
echo # Function Definition and Usage >> \patlang-selfhost\demo\showcase.patlang
echo make function greet(name) { >> \patlang-selfhost\demo\showcase.patlang
echo   return "Hello, " + name + "!" >> \patlang-selfhost\demo\showcase.patlang
echo } >> \patlang-selfhost\demo\showcase.patlang
echo. >> \patlang-selfhost\demo\showcase.patlang
echo message = greet("PaTLang User") >> \patlang-selfhost\demo\showcase.patlang
echo IO.puts(message) >> \patlang-selfhost\demo\showcase.patlang

REM Create a README file
echo Creating README file...
echo # Clean PaTLang Self-Hosting Project > \patlang-selfhost\README.md
echo. >> \patlang-selfhost\README.md
echo This is a minimal clean project containing only the essential components >> \patlang-selfhost\README.md
echo needed for the PaTLang self-hosting implementation. >> \patlang-selfhost\README.md
echo. >> \patlang-selfhost\README.md
echo ## Project Documentation >> \patlang-selfhost\README.md
echo. >> \patlang-selfhost\README.md
echo The project includes comprehensive documentation in the docs/ directory >> \patlang-selfhost\README.md
echo as well as key architectural and design markdown files at the root level. >> \patlang-selfhost\README.md
echo. >> \patlang-selfhost\README.md
echo ## Running the project >> \patlang-selfhost\README.md
echo. >> \patlang-selfhost\README.md
echo ```bash >> \patlang-selfhost\README.md
echo cd \patlang-selfhost >> \patlang-selfhost\README.md
echo ruby bin/patlang patlang-selfhost/tests/integration_suite.patlang >> \patlang-selfhost\README.md
echo ``` >> \patlang-selfhost\README.md

REM Create useful scripts
echo Creating helper scripts...
echo @echo off > \patlang-selfhost\run_tests.bat
echo echo Running integration test suite... >> \patlang-selfhost\run_tests.bat
echo ruby bin/patlang patlang-selfhost/tests/integration_suite.patlang >> \patlang-selfhost\run_tests.bat

echo @echo off > \patlang-selfhost\run_demo.bat
echo echo Running demo files... >> \patlang-selfhost\run_demo.bat
echo ruby bin/patlang demo/showcase.patlang >> \patlang-selfhost\run_demo.bat

REM Create additional helper file to document the clean project structure
echo # PaTLang Self-Hosting Project Structure > \patlang-selfhost\PROJECT_STRUCTURE.md
echo. >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo This file provides an overview of the clean project structure. >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo. >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo ## Directory Structure >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo. >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo - `bin/` - Runner scripts and bootstrapper >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo - `docs/` - Documentation for the project >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo - `patlang-selfhost/` - Self-hosting implementation >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo   - `contracts/` - Contract definitions >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo   - `src/` - Source code written in PaTLang >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo   - `tests/` - Test suite >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo - `patlang-core/` - Ruby bootstrap for PaTLang >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo - `ruby-host/` - Ruby host interface >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo - `native_evaluator/` - Native code integration >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo. >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo ## Key Files >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo. >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo - `bin/patlang` - Main runner script >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo - `patlang-selfhost/src/compiler.patlang` - Self-hosted compiler >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo - `patlang-selfhost/src/interpreter.patlang` - Self-hosted interpreter >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo - `patlang-selfhost/src/lexer.patlang` - Self-hosted lexer >> \patlang-selfhost\PROJECT_STRUCTURE.md
echo - `patlang-selfhost/src/parser.patlang` - Self-hosted parser >> \patlang-selfhost\PROJECT_STRUCTURE.md

REM Create quick start guide
echo Creating quickstart guide...
echo # PaTLang Quick Start Guide > \patlang-selfhost\QUICKSTART.md
echo. >> \patlang-selfhost\QUICKSTART.md
echo This guide will help you get started with PaTLang in your new clean environment. >> \patlang-selfhost\QUICKSTART.md
echo. >> \patlang-selfhost\QUICKSTART.md
echo ## Running the provided scripts >> \patlang-selfhost\QUICKSTART.md
echo. >> \patlang-selfhost\QUICKSTART.md
echo 1. **Run the test suite:** >> \patlang-selfhost\QUICKSTART.md
echo    ```bash >> \patlang-selfhost\QUICKSTART.md
echo    run_tests.bat >> \patlang-selfhost\QUICKSTART.md
echo    ``` >> \patlang-selfhost\QUICKSTART.md
echo. >> \patlang-selfhost\QUICKSTART.md
echo 2. **Run the demo showcase:** >> \patlang-selfhost\QUICKSTART.md
echo    ```bash >> \patlang-selfhost\QUICKSTART.md
echo    run_demo.bat >> \patlang-selfhost\QUICKSTART.md
echo    ``` >> \patlang-selfhost\QUICKSTART.md
echo. >> \patlang-selfhost\QUICKSTART.md
echo ## Creating your own PaTLang file >> \patlang-selfhost\QUICKSTART.md
echo. >> \patlang-selfhost\QUICKSTART.md
echo 1. Create a new file `hello.patlang` with the following content: >> \patlang-selfhost\QUICKSTART.md
echo    ```patlang >> \patlang-selfhost\QUICKSTART.md
echo    include "patlang-selfhost/src/stdlib/io.patlang" >> \patlang-selfhost\QUICKSTART.md
echo. >> \patlang-selfhost\QUICKSTART.md
echo    IO.puts("Hello, PaTLang World!") >> \patlang-selfhost\QUICKSTART.md
echo    ``` >> \patlang-selfhost\QUICKSTART.md
echo. >> \patlang-selfhost\QUICKSTART.md
echo 2. Run your file: >> \patlang-selfhost\QUICKSTART.md
echo    ```bash >> \patlang-selfhost\QUICKSTART.md
echo    ruby bin/patlang hello.patlang >> \patlang-selfhost\QUICKSTART.md
echo    ``` >> \patlang-selfhost\QUICKSTART.md
echo. >> \patlang-selfhost\QUICKSTART.md
echo ## Further Resources >> \patlang-selfhost\QUICKSTART.md
echo. >> \patlang-selfhost\QUICKSTART.md
echo - Check the `docs/` directory for comprehensive documentation >> \patlang-selfhost\QUICKSTART.md
echo - Look at `examples/` for more code examples >> \patlang-selfhost\QUICKSTART.md
echo - Explore `patlang-selfhost/src/stdlib/` for available libraries >> \patlang-selfhost\QUICKSTART.md

echo Setup complete! The clean project is now available at \patlang-selfhost
echo.
echo To run tests: \patlang-selfhost\run_tests.bat
echo To run demos: \patlang-selfhost\run_demo.bat
echo.
echo Documentation:
echo - Check \patlang-selfhost\QUICKSTART.md to get started
echo - See \patlang-selfhost\PROJECT_STRUCTURE.md for project overview
