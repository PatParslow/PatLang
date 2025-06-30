# define _POSIX_C_SOURCE 200809L
/*
 * cli_test.c
 * Integration tests for CLI pipeline: argument parsing, file loading, mode selection.
 * Does not test actual parsing or execution logic.
 *
 * Usage:
 *   ./cli_test [--json]
 *     --json   Output test results in JSON format (pass/fail counts and failed test details).
 *     Standard output remains developer-friendly unless --json is specified.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "cli_common.h"
#include "loader.h"

#define MAX_FAILS 128
static const char* fail_msg[MAX_FAILS];
static int fail_line[MAX_FAILS];
static const char* fail_file[MAX_FAILS];
static int fail_detail_count = 0;

#define ASSERT(cond, msg) \
    do { \
        if (!(cond)) { \
            printf("[FAIL] %s:%d: %s\n", __FILE__, __LINE__, msg); \
            if (fail_detail_count < MAX_FAILS) { \
                fail_msg[fail_detail_count] = msg; \
                fail_line[fail_detail_count] = __LINE__; \
                fail_file[fail_detail_count] = __FILE__; \
                fail_detail_count++; \
            } \
            failures++; \
        } else { \
            passes++; \
        } \
    } while (0)

static int passes = 0;
static int failures = 0;
static int json_mode = 0;

// Helper: Write a mock .pat file
void write_mock_pat(const char* path, const char* content) {
    FILE* f = fopen(path, "w");
    if (f) {
        fputs(content, f);
        fclose(f);
    }
}

/*
 * Helper: Run the real patlang binary as a subprocess, capturing stdout.
 * Returns exit code of the process. Output is written to buf (buflen).
 */
int run_patlang_and_capture(const char* mode, const char* filename, char* buf, size_t buflen) {
    char cmd[512];
    if (mode && strcmp(mode, "compile") == 0) {
        snprintf(cmd, sizeof(cmd), "./patlang -c %s", filename);
    } else {
        snprintf(cmd, sizeof(cmd), "./patlang %s", filename);
    }
    FILE* fp = popen(cmd, "r");
    if (!fp) return -1;
    size_t n = fread(buf, 1, buflen - 1, fp);
    buf[n] = 0;
    int status = pclose(fp);
    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    }
    return -1;
}


// --- Arithmetic and String Evaluation Integration Tests ---
void test_arithmetic_and_string_eval() {
   if (!json_mode) printf("Running arithmetic and string evaluation tests...\n");
   const char* fname = "test_patlang_eval.pat";
   // Test arithmetic
   write_mock_pat(fname, "print 1+2\nx = 3*4\nprint x\n");
   char buf[512] = {0};
   int ret = run_patlang_and_capture(NULL, fname, buf, sizeof(buf));
   if (!json_mode) printf("[DEBUG] Captured output:\n%s\n", buf);
   ASSERT(strstr(buf, "3\n"), "Arithmetic print 1+2 should output 3");
   ASSERT(strstr(buf, "x = 12"), "Assignment x = 3*4 should output x = 12");
   // Test string
   write_mock_pat(fname, "print \"hello\"\ny = \"a\" \nprint y\n");
   memset(buf, 0, sizeof(buf));
   ret = run_patlang_and_capture(NULL, fname, buf, sizeof(buf));
   if (!json_mode) printf("[DEBUG] Captured output:\n%s\n", buf);
   ASSERT(strstr(buf, "hello\n"), "String print should output hello");
   ASSERT(strstr(buf, "y = a"), "Assignment y = \"a\" should output y = a");
   // Test compound expression
   write_mock_pat(fname, "a = 2\nb = 5\nprint a + b * 3\n");
   memset(buf, 0, sizeof(buf));
   ret = run_patlang_and_capture(NULL, fname, buf, sizeof(buf));
   if (!json_mode) printf("[DEBUG] Captured output:\n%s\n", buf);
   ASSERT(strstr(buf, "17\n"), "Compound expression print a + b * 3 should output 17");
   // Clean up
   unlink(fname);
}

/* --- Debugging Helper for Test Output --- */
void print_test_debug(const char* test_name, const char* pat_src, const char* expected, const char* actual, int passed) {
    if (!json_mode) {
        printf("----\n[Test] %s\n", test_name);
        printf("[Patlang Source]:\n%s\n", pat_src);
        if (!passed) {
            printf("[Expected Output]: %s\n", expected);
        }
        printf("[Actual Output]:\n%s\n", actual);
        if (!passed) {
            // print the FAIL in red
            printf("\033[31m[RESULT]: FAIL\033[0m\n");
        } else {
            // print the PASS in green
            printf("\033[32m[RESULT]: PASS\033[0m\n");
        }
        printf("----\n");
    }
}

// --- Program Flow Tests ---
void test_program_flow() {
    if (!json_mode) printf("Running program flow tests...\n");
    char buf[512] = {0};
    const char* fname = "testdir/flow_test.pat";

    // if/then
    const char* src_if = "x = 5\nif x > 3 then print \"gt3\"\nif x < 3 then print \"lt3\"\n";
    write_mock_pat(fname, src_if);
    memset(buf, 0, sizeof(buf));
    run_patlang_and_capture(NULL, fname, buf, sizeof(buf));
    int pass1 = strstr(buf, "gt3") != NULL;
    print_test_debug("if/then true branch", src_if, "Should print gt3", buf, pass1);
    ASSERT(pass1, "if/then true branch should print gt3");
    int pass2 = strstr(buf, "lt3") == NULL;
    print_test_debug("if/then false branch", src_if, "Should not print lt3", buf, pass2);
    ASSERT(pass2, "if/then false branch should not print lt3");

    // while
    const char* src_while = "i = 0\nwhile i < 3 do\n  print i\n  i = i + 1\nend\n";
    write_mock_pat(fname, src_while);
    memset(buf, 0, sizeof(buf));
    run_patlang_and_capture(NULL, fname, buf, sizeof(buf));
    int pass3 = strstr(buf, "0\n") && strstr(buf, "1\n") && strstr(buf, "2\n");
    print_test_debug("while loop", src_while, "Should print 0 1 2", buf, pass3);
    ASSERT(pass3, "while loop should print 0 1 2");

    // for
    const char* src_for = "for j = 1 to 3 do\n  print j\nend\n";
    write_mock_pat(fname, src_for);
    memset(buf, 0, sizeof(buf));
    run_patlang_and_capture(NULL, fname, buf, sizeof(buf));
    int pass4 = strstr(buf, "1\n") && strstr(buf, "2\n") && strstr(buf, "3\n");
    print_test_debug("for loop", src_for, "Should print 1 2 3", buf, pass4);
    ASSERT(pass4, "for loop should print 1 2 3");

    // case statement
    const char* src_case = "v = 2\ncase v\n  when 1 then print \"one\"\n  when 2 then print \"two\"\n  else print \"other\"\nend\n";
    write_mock_pat(fname, src_case);
    memset(buf, 0, sizeof(buf));
    run_patlang_and_capture(NULL, fname, buf, sizeof(buf));
    int pass5 = strstr(buf, "two") != NULL;
    print_test_debug("case statement", src_case, "Should print two", buf, pass5);
    ASSERT(pass5, "case statement should print two");
}

/* --- Error Handling Tests --- */
void test_error_handling() {
    if (!json_mode) printf("Running error handling tests...\n");
    char buf[512] = {0};
    const char* fname = "testdir/error_test.pat";
    int ret;

    // Invalid syntax
    const char* src_invalid = "x = \nprint x\n";
    write_mock_pat(fname, src_invalid);
    memset(buf, 0, sizeof(buf));
    ret = run_patlang_and_capture(NULL, fname, buf, sizeof(buf));
    int pass1 = (ret != 0);
    print_test_debug("invalid syntax", src_invalid, "Should return nonzero exit code and mention syntax error", buf, pass1 && (strstr(buf, "syntax") || strstr(buf, "error")));
    ASSERT(pass1, "Invalid syntax should return nonzero exit code");
    ASSERT(strstr(buf, "syntax") || strstr(buf, "error"), "Should mention syntax error");

    // Division by zero
    const char* src_div0 = "a = 1/0\nprint a\n";
    write_mock_pat(fname, src_div0);
    memset(buf, 0, sizeof(buf));
    ret = run_patlang_and_capture(NULL, fname, buf, sizeof(buf));
    int pass2 = (ret != 0);
    print_test_debug("division by zero", src_div0, "Should return nonzero exit code and mention division by zero", buf, pass2 && (strstr(buf, "zero") || strstr(buf, "division")));
    ASSERT(pass2, "Division by zero should return nonzero exit code");
    ASSERT(strstr(buf, "zero") || strstr(buf, "division"), "Should mention division by zero");

    // Undefined variable
    const char* src_undef = "print y\n";
    write_mock_pat(fname, src_undef);
    memset(buf, 0, sizeof(buf));
    ret = run_patlang_and_capture(NULL, fname, buf, sizeof(buf));
    int pass3 = (ret != 0);
    print_test_debug("undefined variable", src_undef, "Should return nonzero exit code and mention undefined variable", buf, pass3 && (strstr(buf, "undefined") || strstr(buf, "not defined")));
    ASSERT(pass3, "Undefined variable should return nonzero exit code");
    ASSERT(strstr(buf, "undefined") || strstr(buf, "not defined"), "Should mention undefined variable");
}



// Test: Interpret mode with valid .pat file
void test_interpret_mode() {
    if (!json_mode) printf("Test: Interpret mode with valid .pat file\n");
    const char* fname = "testdir/mock1.pat";
    write_mock_pat(fname, "// mock content\n");
    char out[256] = {0};
    int ret = run_patlang_and_capture(NULL, fname, out, sizeof(out));
    ASSERT(ret == 0, "Interpret mode should return 0");
    ASSERT(strstr(out, "Interpret mode selected") != NULL, "Should print interpret mode message");
    ASSERT(strstr(out, fname) != NULL, "Should print file name");
}

// Test: Compile mode with valid .pat file
void test_compile_mode() {
    if (!json_mode) printf("Test: Compile mode with valid .pat file\n");
    const char* fname = "testdir/mock2.pat";
    write_mock_pat(fname, "// mock content\n");
    char out[256] = {0};
    int ret = run_patlang_and_capture("compile", fname, out, sizeof(out));
    ASSERT(ret == 0, "Compile mode should return 0");
    ASSERT(strstr(out, "Compile mode selected") != NULL, "Should print compile mode message");
    ASSERT(strstr(out, fname) != NULL, "Should print file name");
}

// Test: Invalid extension
/* test_invalid_extension removed: extension check no longer enforced */

// Test: Invalid argument count
void test_invalid_args() {
    if (!json_mode) printf("Test: Invalid argument count\n");
    // Try running patlang with no arguments, capture stderr via shell redirection
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "./patlang 2>cli_test_stderr.txt");
    int ret = system(cmd);
    char err[256] = {0};
    FILE* ferr = fopen("cli_test_stderr.txt", "r");
    if (ferr) {
        fread(err, 1, sizeof(err) - 1, ferr);
        fclose(ferr);
    }
    if (!json_mode) printf("Captured stderr: %s\n", err);
    ASSERT(ret != 0, "Should return error for invalid arg count");
    ASSERT(strstr(err, "Invalid arguments") != NULL, "Should mention invalid arguments error");
    unlink("cli_test_stderr.txt");
}

int main_test() {
    test_arithmetic_and_string_eval();
    // Ensure testdir exists
    system("mkdir -p testdir");
    test_program_flow();
    test_error_handling();
    test_interpret_mode();
    test_compile_mode();
    test_invalid_args();
    if (!json_mode) printf("[SUMMARY] Passed: %d, Failed: %d\n", passes, failures);
    return failures == 0 ? 0 : 1;
}

int main(int argc, char** argv) {
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--json") == 0) {
            json_mode = 1;
        }
    }
    int ret = main_test();
    if (json_mode) {
        printf("{\n");
        printf("  \"passed\": %d,\n", passes);
        printf("  \"failed\": %d,\n", failures);
        printf("  \"failures\": [\n");
        for (int i = 0; i < fail_detail_count; ++i) {
            printf("    {\"file\": \"%s\", \"line\": %d, \"message\": \"%s\"}%s\n",
                fail_file[i], fail_line[i], fail_msg[i],
                (i + 1 < fail_detail_count) ? "," : "");
        }
        printf("  ]\n}\n");
    }
    return ret;
}