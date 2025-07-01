/*
 * native_fileio_test.c
 * Test suite for file I/O primitives.
 *
 * Usage:
 *   ./native_fileio_test [--json]
 *   --json   Output test results as JSON (pass/fail counts and failed test names)
 *   If --json is not specified, output is unchanged.
 */
// Add string.h for strcmp
#include <stdio.h>
#include <assert.h>
#include <string.h>

// Stub declarations for file I/O primitives
#include <fcntl.h>
#include <unistd.h>
static int native_open(const char *filename, int flags) { return open(filename, flags, 0644); }
#include <unistd.h>
int native_read(int fd, void *buf, size_t count) { return read(fd, buf, count); }
#include <unistd.h>
int native_write(int fd, const void *buf, size_t count) { return write(fd, buf, count); }
int native_close(int fd) { return close(fd); }

static int passes = 0;
static int failures = 0;
#define MAX_FAILED_TESTS 16
static const char* failed_tests[MAX_FAILED_TESTS];
static int failed_count = 0;
static int json_mode = 0;

#define TEST_CASE(name, expr) \
    do { \
        if (expr) { \
            passes++; \
        } else { \
            if (failed_count < MAX_FAILED_TESTS) failed_tests[failed_count++] = name; \
            failures++; \
        } \
    } while (0)

void test_open() {
    FILE *f = fopen("testfile.txt", "w");
    if (f) fclose(f);
    int fd = native_open("testfile.txt", 0);
    TEST_CASE("test_open", fd >= 0 && "native_open should return a valid file descriptor");
    native_close(fd);
}

void test_read() {
    FILE *f = fopen("testfile.txt", "w");
    fputs("abcdef", f);
    fclose(f);

    int fd = native_open("testfile.txt", 0);
    TEST_CASE("test_read_open", fd >= 0 && "native_open should return a valid file descriptor");

    char buf[10] = {0};
    int bytes = native_read(fd, buf, sizeof(buf));
    TEST_CASE("test_read", bytes >= 0 && "native_read should return number of bytes read");
    native_close(fd);
}

void test_write() {
    int fd = native_open("testfile.txt", 2); // O_RDWR
    TEST_CASE("test_write_open", fd >= 0 && "native_open should return a valid file descriptor");

    const char *msg = "hello";
    int bytes = native_write(fd, msg, 5);
    TEST_CASE("test_write", bytes == 5 && "native_write should write 5 bytes");

    native_close(fd);
}

void test_close() {
    int fd = native_open("testfile.txt", 0);
    TEST_CASE("test_close_open", fd >= 0 && "native_open should return a valid file descriptor");
    int result = native_close(fd);
    TEST_CASE("test_close", result == 0 && "native_close should return 0 on success");
}

int main(int argc, char** argv) {
    if (argc > 1 && strcmp(argv[1], "--json") == 0) {
        json_mode = 1;
    }
    passes = 0;
    failures = 0;
    failed_count = 0;

    test_open();
    test_read();
    test_write();
    test_close();

    if (json_mode) {
        printf("{\"passes\":%d,\"failures\":%d", passes, failures);
        if (failures > 0) {
            printf(",\"failed_tests\":[");
            for (int i = 0; i < failed_count; ++i) {
                printf("\"%s\"%s", failed_tests[i], (i == failed_count - 1) ? "" : ",");
            }
            printf("]");
        }
        printf("}\n");
    } else {
        if (!json_mode) printf("All file I/O primitive tests ran (expected to fail).\n");
    }
    return failures ? 1 : 0;
}