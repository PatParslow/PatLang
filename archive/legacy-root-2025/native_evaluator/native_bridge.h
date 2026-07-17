#ifndef NATIVE_BRIDGE_H
#define NATIVE_BRIDGE_H

#include <stddef.h>
#include <stdlib.h>
#ifdef __cplusplus
extern "C" {
#endif

/**
 * @section Memory Management API
 *
 * Provides basic memory allocation, deallocation, and garbage collection stubs.
 */

/**
 * @brief Allocates a memory block of the given size.
 * @param size Number of bytes to allocate.
 * @return Pointer to allocated memory, or NULL on allocation failure.
 *
 * Allocates memory using malloc. Returns NULL if allocation fails or size is zero.
 */
void* nb_allocate(size_t size);

/**
 * @brief Deallocates a previously allocated memory block.
 * @param ptr Pointer to memory to deallocate.
 *
 * Frees memory allocated by nb_allocate. Does nothing if ptr is NULL.
 */
void  nb_deallocate(void* ptr);

/**
 * @brief Triggers garbage collection (no-op).
 *
 * No garbage collector is implemented; this is a no-op.
 */
void  nb_gc_collect(void);

/**
 * @section Event/Callback System API
 *
 * Provides primitives for registering, unregistering, and dispatching event callbacks.
 */

/**
 * @brief Event callback function type.
 * @param event_name Name of the event (null-terminated string).
 * @param user_data User data pointer passed during registration.
 */
typedef void (*nb_event_callback_t)(const char* event_name, void* user_data);

/**
 * @brief Registers a callback for a named event.
 * @param event_name Name of the event (null-terminated string).
 * @param callback Callback function to invoke when the event is dispatched.
 * @param user_data Pointer to user data to pass to the callback.
 * @return 0 on success, -1 on error (e.g., no slots available).
 *
 * Registers a callback for the given event name. Only one callback per event name is allowed.
 */
int nb_event_register(const char* event_name, nb_event_callback_t callback, void* user_data);

/**
 * @brief Unregisters a callback for a named event.
 * @param event_name Name of the event (null-terminated string).
 * @return 0 on success, -1 if not found.
 *
 * Removes the callback associated with the given event name.
 */
int nb_event_unregister(const char* event_name);

/**
 * @brief Dispatches an event by name.
 * @param event_name Name of the event (null-terminated string).
 *
 * Invokes the registered callback for the given event name, if any.
 */
void nb_event_dispatch(const char* event_name);

/**
 * @section File I/O API
 *
 * Provides stubs for basic file operations on Windows.
 */

/**
 * @brief Opens a file.
 * @param path Path to the file.
 * @param mode File access mode string ("r", "w", etc.).
 * @return File handle (opaque pointer), or NULL on error.
 *
 * Opens a file using fopen. Returns NULL if path or mode is NULL, or if fopen fails.
 */
void* nb_file_open(const char* path, const char* mode);

/**
 * @brief Reads data from a file.
 * @param handle File handle returned by nb_file_open.
 * @param buffer Buffer to read data into.
 * @param size Number of bytes to read.
 * @return Number of bytes read, or -1 on error.
 *
 * Reads up to size bytes from the file. Returns number of bytes read, or -1 if handle/buffer is NULL, size is zero, or a read error occurs.
 */
int nb_file_read(void* handle, void* buffer, size_t size);

/**
 * @brief Writes data to a file.
 * @param handle File handle returned by nb_file_open.
 * @param buffer Buffer containing data to write.
 * @param size Number of bytes to write.
 * @return Number of bytes written, or -1 on error.
 *
 * Writes up to size bytes to the file. Returns number of bytes written, or -1 if handle/buffer is NULL, size is zero, or a write error occurs.
 */
int nb_file_write(void* handle, const void* buffer, size_t size);

/**
 * @brief Closes an open file.
 * @param handle File handle to close.
 * @return 0 on success, -1 if not implemented.
 */
int nb_file_close(void* handle);

/**
 * @brief Seeks to a position in an open file.
 * @param handle File handle returned by nb_file_open.
 * @param offset Offset in bytes.
 * @param whence SEEK_SET, SEEK_CUR, or SEEK_END.
 * @return 0 on success, -1 on error.
 */
int nb_file_seek(void* handle, long offset, int whence);

/**
 * @brief Deletes a file.
 * @param path Path to the file.
 * @return 0 on success, -1 on error.
 */
int nb_file_delete(const char* path);

/**
 * @brief File information structure for nb_file_stat.
 */
typedef struct nb_file_info {
    long long size;
    long long mtime;
    int is_dir;
} nb_file_info;

/**
 * @brief Gets file information (stat).
 * @param path Path to the file.
 * @param info Pointer to nb_file_info struct to fill.
 * @return 0 on success, -1 on error.
 */
int nb_file_stat(const char* path, nb_file_info* info);

/**
 * @section Message Queue API
 *
 * Provides primitives for creating, sending to, receiving from, and destroying message queues.
 * Uses POSIX message queues on Linux/WSL, stubs on Windows.
 */

/**
 * @brief Opaque handle for a message queue.
 */
typedef struct nb_mq_handle nb_mq_handle;

/**
 * @brief Creates a new message queue.
 * @param name Optional name (NULL for unnamed/anonymous).
 * @param max_msg Maximum number of messages in the queue.
 * @param msg_size Maximum size of each message (bytes).
 * @return Pointer to message queue handle, or NULL on error.
 *
 * On POSIX, creates a new message queue. On Windows, returns NULL (not implemented).
 */
nb_mq_handle* nb_mq_create(const char* name, size_t max_msg, size_t msg_size);

/**
 * @brief Sends a message to the queue.
 * @param handle Message queue handle.
 * @param msg Pointer to message data.
 * @param msg_len Length of message in bytes.
 * @return 0 on success, -1 on error.
 */
int nb_mq_send(nb_mq_handle* handle, const void* msg, size_t msg_len);

/**
 * @brief Receives a message from the queue.
 * @param handle Message queue handle.
 * @param buffer Buffer to receive message.
 * @param buffer_len Size of buffer in bytes.
 * @return Number of bytes received, or -1 on error.
 */
int nb_mq_receive(nb_mq_handle* handle, void* buffer, size_t buffer_len);

/**
 * @brief Destroys a message queue and releases resources.
 * @param handle Message queue handle.
 * @return 0 on success, -1 on error.
 */
int nb_mq_destroy(nb_mq_handle* handle);

/**
 * @brief Directory entry structure for nb_dir_list.
 */
typedef struct nb_dir_entry {
    char* name;        /**< Entry name (file or directory) */
    int   is_dir;      /**< 1 if directory, 0 if file */
} nb_dir_entry;

/**
 * @section Directory Operation API
 *
 * Provides primitives for directory listing, creation, removal, and existence checking.
 */

 /**
 * @section Module Loading API
 *
 * Provides primitives for dynamic loading/unloading of shared libraries and symbol resolution.
 * Cross-platform: uses dlopen/dlsym/dlclose on POSIX, LoadLibrary/GetProcAddress/FreeLibrary on Windows.
 */

/**
 * @brief Loads a dynamic module (shared library).
 * @param path Path to the shared library file.
 * @return Module handle (opaque pointer), or NULL on error.
 *
 * Loads a shared library at the given path. Returns a handle for use with nb_module_symbol and nb_module_unload.
 */
void* nb_module_load(const char* path);

/**
 * @brief Unloads a previously loaded module.
 * @param handle Module handle returned by nb_module_load.
 * @return 0 on success, -1 on error.
 *
 * Unloads the shared library and releases associated resources.
 */
int nb_module_unload(void* handle);

/**
 * @brief Resolves a symbol in a loaded module.
 * @param handle Module handle returned by nb_module_load.
 * @param symbol Name of the symbol to resolve.
 * @return Pointer to the symbol, or NULL if not found.
 *
 * Returns a pointer to the requested symbol in the loaded module.
 */
void* nb_module_symbol(void* handle, const char* symbol);


/**
 * @brief Lists the contents of a directory.
 * @param path Path to the directory.
 * @param entries Output pointer to array of nb_dir_entry (allocated, must be freed by caller).
 * @param count Output pointer to number of entries.
 * @return 0 on success, -1 on error.
 *
 * Allocates an array of nb_dir_entry. Caller must free each entry's name and the array itself.
 */
int nb_dir_list(const char* path, nb_dir_entry** entries, size_t* count);

/**
 * @brief Creates a directory.
 * @param path Path to the directory.
 * @return 0 on success, -1 on error.
 */
int nb_dir_create(const char* path);

/**
 * @brief Removes a directory.
 * @param path Path to the directory.
 * @return 0 on success, -1 on error.
 */
int nb_dir_remove(const char* path);

/**
 * @brief Checks if a directory exists.
 * @param path Path to the directory.
 * @return 1 if exists and is directory, 0 if not, -1 on error.
 */
int nb_dir_exists(const char* path);

/**
 * @section System Operation API
 *
 * Provides stubs for system-level operations.
 */

/**
 * @brief Executes a system command.
 * @param command Command string to execute.
 * @return Status code, or -1 if not implemented.
 */
int   nb_system_call(const char* command);

/**
 * @brief Retrieves an environment variable.
 * @param key Name of the environment variable.
 * @param value Buffer to store the value.
 * @param value_size Size of the buffer.
 * @return 0 on success, -1 if not implemented.
 */
int   nb_get_env(const char* key, char* value, size_t value_size);

/**
 * @brief Retrieves the current process ID.
 * @return Process ID as an integer, or -1 if not implemented.
 */
int   nb_get_pid(void);

/**
 * @brief Gets the current system time in seconds since the epoch.
 * @return Time in seconds as a double, or -1.0 if not implemented.
 */
double nb_time(void);

/**
 * @brief Gets the processor time consumed by the program (seconds).
 * @return Processor time as a double, or -1.0 if not implemented.
 */
double nb_clock(void);

/**
 * @brief Spawns a new process.
 * @param path Path to the executable.
 * @param argv Null-terminated array of argument strings (argv[0] is program name).
 * @return Process ID of the spawned process, or -1 on error.
 */
int nb_spawn(const char* path, char* const argv[]);

/**
 * @brief Waits for a process to change state.
 * @param pid Process ID to wait for.
 * @param status Output pointer for exit status.
 * @return 0 on success, -1 on error.
 */
int nb_waitpid(int pid, int* status);
#ifdef __cplusplus
}
#endif

#endif // NATIVE_BRIDGE_H