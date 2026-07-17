@echo off
setlocal enabledelayedexpansion

set FILE=%1
set ROOT=%~dp0..

set IR_GEN=%ROOT%\tools\compiler\ir_generator.exe
set RUNTIME=%ROOT%\tools\compiler\pat_runtime.exe
set TEMP_IR=%TEMP%\test_ir.ir

echo Generating IR...
"%IR_GEN%" "%FILE%" "%TEMP_IR%"
echo IR Generated, running runtime...
"%RUNTIME%" "%TEMP_IR%"
echo Done
