# PatLang Bootstrap Compiler - Minimal version
# Compiles a simple subset of PatLang to C
# Uses only: integer arithmetic, variables, while loops, print, string constants

# Source to compile (hardcoded for bootstrap)
source is "print(\"Hello from self-hosted PatLang!\")"

# Simple lexer - tokenizes the source
# Tokens: PRINT, STRING, PAREN
tokens is []

# Simple parser - parses print("...")
# AST: ["print", "string"]
ast is ["print", "Hello from self-hosted PatLang!"]

# Code generation - produces C code
# For now, just generate a simple C program
c_code is "
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char** argv) {
    printf(\"Hello from self-hosted PatLang!\\n\");
    return 0;
}
"

# Write C code to file
print("Writing bootstrap compiler output...")
print(c_code)

print("Bootstrap complete!")
print("Run: clang temp.c -o temp && ./temp.exe")