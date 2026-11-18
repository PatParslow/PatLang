# PatLang demo programs

Seven programs, one per group of paradigms and one that combines them all.

| File | Paradigms |
|---|---|
| 01_imperative_and_functional.patlang | imperative, functional, pattern matching, exact numbers |
| 02_objects_and_events.patlang | classes, inheritance, traits, operator methods, events |
| 03_logic_and_goals.patlang | rules, stores, contracts as facts, planning, goals |
| 04_concurrency.patlang | parallel_map, threads, fibres, budgeted blocks, worlds |
| 05_files_and_vfs.patlang | virtual file system, real files |
| 06_networking_and_signals.patlang | TCP request/response, signals |
| 07_bakery_all_paradigms.patlang | all of the above in one program |

## Running them

From the repository root (demos 6 and 7 include
`../self_hosting/lib/signals.patlang`):

    self_hosting/build/v2_interp.exe demos/01_imperative_and_functional.patlang
    self_hosting/build/v2.exe demos/01_imperative_and_functional.patlang demo1.exe

Demo 5 writes and removes `demo5_out/` in the current directory. Demos 6 and 7
open loopback TCP ports chosen by the system.

## How they were checked

The `demos` suite of the gates (`self_hosting/tools/run_demos.patlang`) runs
each one interpreted and compiled, on Windows with real files and Winsock, and
compares both with `expected/NAME.txt`. Demo 6's and demo 7's output does not
depend on timing; demo 4's "needed more than one 2 ms slice" line assumes the
loop takes longer than 2 ms.

## Helpers the demos define

The demos define `text_lines`, `starts_with` and `ends_with` themselves:
`split_lines` and its neighbours belong to `self_hosting/lib/includes.patlang`,
not to the runtime, and neither engine has them unless a program includes
that file.

Logic variables are values made by `logic_var("Who")`. In `rule` and `fact`
declarations a bare capitalised name is one; a string is always a constant.
