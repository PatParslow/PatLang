/*
 * native_dir_test.c
 * Test suite for directory primitives.
 *
 * Usage:
 *   ./native_dir_test [--json]
 *   --json   Output test results as JSON (pass/fail counts and failed test names)
 *   If --json is not specified, output is unchanged.
 */
#include <stdio.h>
#include <assert.h>

// Stub declarations for directory primitives
#include <sys/stat.h>
static int native_mkdir(const char *path) { return mkdir(path, 0777); }
#include <sys/stat.h>
int native_dir_exists(const char *path) {
    struct stat st;
    if (stat(path, &st) == 0 && S_ISDIR(st.st_mode)) return 1;
    return 0;
}
#include <dirent.h>
#include <string.h>
int native_listdir(const char *path, char *buf, size_t buflen) {
    DIR *d = opendir(path);
    if (!d) return -1;
    struct dirent *entry;
    size_t used = 0;
    while ((entry = readdir(d)) != NULL) {
        size_t len = strlen(entry->d_name);
        if (used + len + 2 > buflen) break;
        strcpy(buf + used, entry->d_name);
        used += len;
        buf[used++] = '\n';
    }
    if (used < buflen) buf[used] = '\0';
    closedir(d);
    return 0;
}

#include <errno.h>
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

void test_mkdir() {
    int res = native_mkdir("testdir");
    if (res != 0 && errno == EEXIST) res = 0;
    TEST_CASE("test_mkdir", res == 0 && "native_mkdir should return 0 on success or EEXIST");
}

void test_dir_exists() {
    int exists = native_dir_exists("testdir");
    TEST_CASE("test_dir_exists", exists == 1 && "native_dir_exists should return 1 if directory exists");
}

void test_listdir() {
    char buf[256] = {0};
    int res = native_listdir("testdir", buf, sizeof(buf));
    TEST_CASE("test_listdir", res == 0 && "native_listdir should return 0 on success");
    // Optionally check buf contents in future
}

int main(int argc, char** argv) {
    if (argc > 1 && strcmp(argv[1], "--json") == 0) {
        json_mode = 1;
    }
    passes = 0;
    failures = 0;
    failed_count = 0;

    test_mkdir();
    test_dir_exists();
    test_listdir();

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
        if (!json_mode) printf("All directory primitive tests ran (expected to fail).\n");
    }
    return failures ? 1 : 0;
}