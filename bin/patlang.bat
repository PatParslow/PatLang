@echo off
REM PaTLang Native CLI - Windows Batch Version (No Ruby Required!)
REM Uses local IR caching (like Python .pyc files)

setlocal enabledelayedexpansion

if "%1"=="" (
    echo PaTLang - Native Backend
    echo Usage: patlang.bat ^<file.patlang^>
    exit /b 0
)

set FILE=%1
set SCRIPT_DIR=%~dp0
set ROOT=%SCRIPT_DIR%..

REM Check if file exists
if not exist "%FILE%" (
    echo ERROR: File not found: %FILE%
    exit /b 1
)

REM Paths
set IR_GEN=%ROOT%\tools\compiler\ir_generator.exe
set RUNTIME=%ROOT%\tools\compiler\pat_runtime.exe

REM Check dependencies
if not exist "%IR_GEN%" (
    echo ERROR: IR generator not found: %IR_GEN%
    echo Build with: clang -O2 -o tools\compiler\ir_generator.exe tools\compiler\ir_generator_v2.c
    exit /b 1
)

if not exist "%RUNTIME%" (
    echo ERROR: Native runtime not compiled: %RUNTIME%
    echo Build with: clang -O2 -o tools\compiler\pat_runtime.exe tools\compiler\runtime.c
    exit /b 1
)

REM Generate IR filename from source (e.g., hello.pat -> hello.ir) in same directory
for %%A in ("%FILE%") do set IR_FILE=%%~dpA%%~nA.ir

REM Generate IR using C generator (always, will update if source changed)
"%IR_GEN%" "%FILE%" "%IR_FILE%"

if errorlevel 1 (
    echo ERROR: Failed to generate IR
    exit /b 1
)

if not exist "%IR_FILE%" (
    echo ERROR: Failed to generate IR - no output file
    exit /b 1
)

REM Execute native runtime
"%RUNTIME%" "%IR_FILE%"

exit /b 0