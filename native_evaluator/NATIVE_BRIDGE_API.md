# Native Bridge API

This document describes the minimal runtime API for the Patlang native bridge, targeting Windows. All system elements are stubs and documented for further development.

---

## Memory Management API

### `void* nb_allocate(size_t size)`
Allocates a memory block of the given size using `malloc`.

- **Parameters:**
  `size` — Number of bytes to allocate.
- **Returns:**
  Pointer to allocated memory, or `NULL` if allocation fails or size is zero.
- **Errors:**
  Returns `NULL` if allocation fails or size is zero.

### `void nb_deallocate(void* ptr)`
Deallocates a previously allocated memory block using `free`.

- **Parameters:**
  `ptr` — Pointer to memory to deallocate.
- **Usage:**
  Does nothing if `ptr` is `NULL`.

### `void nb_gc_collect(void)`
No-op. No garbage collector is implemented.

---

## File I/O API

### `void* nb_file_open(const char* path, const char* mode)`
Opens a file using `fopen`.

- **Parameters:**
  `path` — Path to the file.
  `mode` — File access mode string ("r", "w", etc.).
- **Returns:**
  File handle (opaque pointer), or `NULL` on error.
- **Errors:**
  Returns `NULL` if `path` or `mode` is `NULL`, or if the file cannot be opened.

### `int nb_file_read(void* handle, void* buffer, size_t size)`
Reads data from a file using `fread`.

- **Parameters:**
  `handle` — File handle from `nb_file_open`.
  `buffer` — Buffer to read data into.
  `size` — Number of bytes to read.
- **Returns:**
  Number of bytes read, or `-1` on error.
- **Errors:**
  Returns `-1` if `handle` or `buffer` is `NULL`, `size` is zero, or a read error occurs.

### `int nb_file_write(void* handle, const void* buffer, size_t size)`
Writes data to a file using `fwrite`.

- **Parameters:**
  `handle` — File handle from `nb_file_open`.
  `buffer` — Buffer containing data to write.
  `size` — Number of bytes to write.
- **Returns:**
  Number of bytes written, or `-1` on error.
- **Errors:**
  Returns `-1` if `handle` or `buffer` is `NULL`, `size` is zero, or a write error occurs.

### `int nb_file_close(void* handle)`
Closes an open file using `fclose`.

- **Parameters:**
  `handle` — File handle to close.
- **Returns:**
  `0` on success, `-1` on error.
- **Errors:**
  Returns `-1` if `handle` is `NULL` or if closing fails.

---

## System Operation API

### `int nb_system_call(const char* command)`
Executes a system command.

- **Parameters:**  
  `command` — Command string to execute.
- **Returns:**  
  Status code, or `-1` (stub).

### `int nb_get_env(const char* key, char* value, size_t value_size)`
Retrieves an environment variable.

- **Parameters:**  
  `key` — Name of the environment variable.  
  `value` — Buffer to store the value.  
  `value_size` — Size of the buffer.
- **Returns:**  
  `0` on success, `-1` (stub).

---

## Notes

- All functions are stubs and do not provide actual logic.
- Each function is documented in the header and implementation files.
- This API is intended as a foundation for further Patlang runtime development.
---

## Testing the Native Bridge

A test suite is provided in [`native_bridge_test.c`](native_bridge_test.c:1) to validate all memory management and file I/O functions.

### Building the Tests (Windows)

1. Open a terminal in the `native_evaluator` directory.
2. Compile the test suite using a C compiler (e.g., MSVC or MinGW):

**MSVC (Developer Command Prompt):**
```sh
cl /Fe:native_bridge_test.exe native_bridge_test.c native_bridge.c
```

**MinGW (or similar GCC):**
```sh
gcc -o native_bridge_test.exe native_bridge_test.c native_bridge.c
```

### Running the Tests

```sh
native_bridge_test.exe
```

The test runner will print the results, including the number of passed and failed assertions.
