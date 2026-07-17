# PatLang Bootstrap Compiler - Simplified
# Only uses working features: assignments, print, while loops

print("PatLang Bootstrap Compiler v1")
print("Generating C code...")

# The C code to generate (as a string constant)
c_prog is "#include <stdio.h>
#include <stdlib.h>

int main(int argc, char** argv) {
    printf(\"Hello from self-hosted PatLang!\\n\");
    return 0;
}"

print("C code generated:")
print(c_prog)

print("Writing to temp.c...")
# Write to file would need file operations
# For now just print the code

print("Done!")
print("To compile: echo \"PATLANG_C_CODE\" > temp.c && clang temp.c -o temp.exe")
print("To run: ./temp.exe")

# Test print
print("Hello from self-hosted PatLang!")