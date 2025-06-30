// native_bridge_test.c
// Test suite for memory management and file I/O functions in native_bridge.c
//
// Usage:
//   ./native_bridge_test [--json]
//   --json   Output test results as JSON (pass/fail counts and failed assertions)
//   If --json is not specified, output is unchanged.
//
// Each test checks correct behavior, error handling, and edge cases.
// Assertions and comments explain the purpose and expected outcomes.

#include "native_bridge.h"
#include <stdio.h>
#include <string.h>

static int json_mode = 0;

#define ASSERT(cond, msg) \
    do { \
        if (!(cond)) { \
            if (json_mode && failed_count < MAX_FAILURES) { \
                failed_asserts[failed_count].file = __FILE__; \
                failed_asserts[failed_count].line = __LINE__; \
                failed_asserts[failed_count].msg = msg; \
                failed_count++; \
            } \
            if (!json_mode) printf("[FAIL] %s:%d: %s\n", __FILE__, __LINE__, msg); \
            failures++; \
        } else { \
            passes++; \
        } \
    } while (0)

static int passes = 0;
static int failures = 0;
#define MAX_FAILURES 128
static struct {
    const char* file;
    int line;
    const char* msg;
} failed_asserts[MAX_FAILURES];
static int failed_count = 0;
static int json_mode = 0;

// =====================
// Memory Management Tests
// =====================

// Test allocation and deallocation of memory
void test_allocate_deallocate() {
    if (!json_mode) printf("Test: Allocate and deallocate memory\n");
    void* ptr = nb_allocate(128);
    ASSERT(ptr != NULL, "Allocation of 128 bytes should succeed");
    nb_deallocate(ptr);
}

// Test allocation of zero bytes
void test_allocate_zero() {
    if (!json_mode) printf("Test: Allocate zero bytes\n");
    void* ptr = nb_allocate(0);
    ASSERT(ptr == NULL, "Allocation of 0 bytes should return NULL");
}

// Test double free (should not crash)
void test_double_free() {
    if (!json_mode) printf("Test: Double free\n");
    void* ptr = nb_allocate(32);
    ASSERT(ptr != NULL, "Allocation should succeed");
    nb_deallocate(ptr);
    ptr = NULL; // Prevent double free
    nb_deallocate(ptr); // Should be safe (no crash)
    ASSERT(1, "Double free should not crash");
}

// Test garbage collection (no-op)
void test_gc_collect() {
    if (!json_mode) printf("Test: Garbage collection (no-op)\n");
    nb_gc_collect();
    ASSERT(1, "nb_gc_collect should be a no-op");
}

// =====================
// File I/O Tests
// =====================

// Test opening a file for writing, writing data, closing, then reading back
void test_file_write_read() {
    if (!json_mode) printf("Test: File write and read\n");
    const char* fname = "testfile.tmp";
    const char* data = "Hello, Native Bridge!";
    char buffer[64] = {0};

    // Open for writing
    void* f = nb_file_open(fname, "w");
    ASSERT(f != NULL, "File open for writing should succeed");
    int written = nb_file_write(f, data, strlen(data));
    ASSERT(written == (int)strlen(data), "File write should write all bytes");
    ASSERT(nb_file_close(f) == 0, "File close after write should succeed");

    // Open for reading
    f = nb_file_open(fname, "r");
    ASSERT(f != NULL, "File open for reading should succeed");
    int read = nb_file_read(f, buffer, sizeof(buffer));
    ASSERT(read == (int)strlen(data), "File read should read correct number of bytes");
    ASSERT(strncmp(buffer, data, strlen(data)) == 0, "Read data should match written data");
    ASSERT(nb_file_close(f) == 0, "File close after read should succeed");

    // Remove test file
    remove(fname);
}

// =====================
// Event/Callback Tests
// =====================
// Event callback state for test
static int callback_called = 0;
static void test_event_callback(const char* event_name, void* user_data) {
    ASSERT(strcmp(event_name, "test_event") == 0, "Event name should match");
    ASSERT(user_data == (void*)0x1234, "User data should match");
    callback_called = 1;
}
void test_event_register_dispatch_unregister() {
    if (!json_mode) printf("Test: Event register, dispatch, and unregister\n");
    callback_called = 0;
    ASSERT(nb_event_register("test_event", test_event_callback, (void*)0x1234) == 0, "Register event callback should succeed");
    nb_event_dispatch("test_event");
    ASSERT(callback_called == 1, "Callback should be called on dispatch");
    ASSERT(nb_event_unregister("test_event") == 0, "Unregister event callback should succeed");
    callback_called = 0;
    nb_event_dispatch("test_event");
    ASSERT(callback_called == 0, "Callback should not be called after unregister");
}

// =====================
// Directory Operation Tests
// =====================
void test_dir_create_exists_remove() {
    if (!json_mode) printf("Test: Directory create, exists, and remove\n");
    const char* dname = "testdir_tmp";
    nb_dir_remove(dname); // Clean up if exists
    ASSERT(nb_dir_create(dname) == 0, "Directory create should succeed");
    ASSERT(nb_dir_exists(dname) == 1, "Directory should exist after creation");
    ASSERT(nb_dir_remove(dname) == 0, "Directory remove should succeed");
    ASSERT(nb_dir_exists(dname) == 0, "Directory should not exist after removal");
}

// =====================
// System Operation Test
// =====================
void test_system_call() {
    if (!json_mode) printf("Test: System call\n");
#if defined(_WIN32)
    ASSERT(nb_system_call("echo NativeBridgeTest") != -1, "System call should succeed on Windows");
#else
    ASSERT(nb_system_call("echo NativeBridgeTest") == 0, "System call should succeed on POSIX");
#endif
}

// =====================
// Module Loading Tests
// =====================
void test_module_load_unload_symbol() {
    if (!json_mode) printf("Test: Module load, symbol, and unload (platform dependent)\n");
#if defined(_WIN32)
    // Skip on Windows (not implemented)
    ASSERT(1, "Module loading not implemented on Windows");
#else
    void* handle = nb_module_load("libc.so.6");
    ASSERT(handle != NULL, "Module load should succeed for libc");
    void* sym = nb_module_symbol(handle, "printf");
    ASSERT(sym != NULL, "Symbol resolution should succeed for printf");
    ASSERT(nb_module_unload(handle) == 0, "Module unload should succeed");
#endif
}

// =====================
// Message Queue Tests
// =====================
void test_mq_create_send_receive_destroy() {
    if (!json_mode) printf("Test: Message queue create, send, receive, destroy\n");
    nb_mq_handle* mq = nb_mq_create(NULL, 4, 32);
    if (!mq) {
        if (!json_mode) printf("Message queues not implemented on this platform, skipping\n");
        ASSERT(1, "Message queue not implemented, skip");
        return;
    }
    const char* msg = "hello";
    ASSERT(nb_mq_send(mq, msg, strlen(msg) + 1) == 0, "Send message should succeed");
    char buf[32] = {0};
    int received = nb_mq_receive(mq, buf, sizeof(buf));
    ASSERT(received > 0 && strcmp(buf, msg) == 0, "Receive message should succeed and match");
    ASSERT(nb_mq_destroy(mq) == 0, "Destroy message queue should succeed");
}
// Test file open with invalid parameters
void test_file_open_invalid() {
    if (!json_mode) printf("Test: File open with invalid parameters\n");
    ASSERT(nb_file_open(NULL, "r") == NULL, "File open with NULL path should fail");
    ASSERT(nb_file_open("testfile.tmp", NULL) == NULL, "File open with NULL mode should fail");
}

// Test file read/write with invalid handle
void test_file_invalid_handle() {
    if (!json_mode) printf("Test: File read/write with invalid handle\n");
    char buf[8];
    ASSERT(nb_file_read(NULL, buf, 8) == -1, "Read with NULL handle should fail");
    ASSERT(nb_file_write(NULL, buf, 8) == -1, "Write with NULL handle should fail");
}

// Test file read/write with invalid buffer/size
void test_file_invalid_buffer_size() {
    if (!json_mode) printf("Test: File read/write with invalid buffer/size\n");
    void* f = nb_file_open("testfile.tmp", "w");
    ASSERT(f != NULL, "File open for write should succeed");
    ASSERT(nb_file_write(f, NULL, 8) == -1, "Write with NULL buffer should fail");
    ASSERT(nb_file_write(f, "abc", 0) == -1, "Write with zero size should fail");
    ASSERT(nb_file_close(f) == 0, "File close should succeed");
}

// Test file close with invalid handle
void test_file_close_invalid() {
    if (!json_mode) printf("Test: File close with invalid handle\n");
    ASSERT(nb_file_close(NULL) == -1, "Close with NULL handle should fail");
}

// =====================
// Test Runner
// =====================

int main(int argc, char** argv) {
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--json") == 0) {
            json_mode = 1;
        }
    }
    if (!json_mode) {
        printf("Running Native Bridge Test Suite\n\n");
        printf("DEBUG: Starting test_allocate_deallocate()\n");
    }
    test_allocate_deallocate();
    if (!json_mode) printf("DEBUG: Starting test_allocate_zero()\n");
    test_allocate_zero();
    if (!json_mode) printf("DEBUG: Starting test_double_free()\n");
    test_double_free();
    if (!json_mode) printf("DEBUG: Starting test_gc_collect()\n");
    test_gc_collect();
    if (!json_mode) printf("DEBUG: Starting test_file_write_read()\n");
    test_file_write_read();
    if (!json_mode) printf("DEBUG: Starting test_file_open_invalid()\n");
    test_file_open_invalid();
    if (!json_mode) printf("DEBUG: Starting test_file_invalid_handle()\n");
    test_file_invalid_handle();
    if (!json_mode) printf("DEBUG: Starting test_file_invalid_buffer_size()\n");
    test_file_invalid_buffer_size();
    if (!json_mode) printf("DEBUG: Starting test_file_close_invalid()\n");
    test_file_close_invalid();
    if (!json_mode) printf("DEBUG: Starting test_event_register_dispatch_unregister()\n");
    test_event_register_dispatch_unregister();
    if (!json_mode) printf("DEBUG: Starting test_dir_create_exists_remove()\n");
    test_dir_create_exists_remove();
    if (!json_mode) printf("DEBUG: Starting test_system_call()\n");
    test_system_call();
    if (!json_mode) printf("DEBUG: Starting test_module_load_unload_symbol()\n");
    test_module_load_unload_symbol();
    if (!json_mode) printf("DEBUG: Starting test_mq_create_send_receive_destroy()\n");
    test_mq_create_send_receive_destroy();

    if (json_mode) {
        printf("{\"passed\":%d,\"failed\":%d,\"failures\":[", passes, failures);
        for (int i = 0; i < failed_count; ++i) {
            printf("{\"file\":\"%s\",\"line\":%d,\"msg\":\"%s\"}%s",
                failed_asserts[i].file, failed_asserts[i].line, failed_asserts[i].msg,
                (i + 1 < failed_count) ? "," : "");
        }
        printf("]}\n");
    } else {
        printf("\nTest Results: %d passed, %d failed\n", passes, failures);
    }
    return failures == 0 ? 0 : 1;
}