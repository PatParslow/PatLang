#include "native_bridge.h"
#include <stddef.h>
#include <stdio.h>
#include <sys/types.h>
#include <string.h>
#if defined(_WIN32)
#include <sys/stat.h>
#define NB_STAT_STRUCT struct _stat
#define NB_STAT_FUNC _stat
#else
#include <sys/stat.h>
#define NB_STAT_STRUCT struct stat
#define NB_STAT_FUNC stat
#endif

#include "compat.h"
// Memory management stubs
#include <stdbool.h>

#define NB_MAX_PTRS 4096
static void* nb_ptrs[NB_MAX_PTRS];
static size_t nb_ptr_count = 0;

void* nb_allocate(size_t size) {
    if (size == 0) return NULL;
    void* ptr = malloc(size);
    if (ptr && nb_ptr_count < NB_MAX_PTRS) {
        nb_ptrs[nb_ptr_count++] = ptr;
    }
    return ptr;
}

static bool nb_is_tracked_ptr(void* ptr, size_t* idx_out) {
    for (size_t i = 0; i < nb_ptr_count; ++i) {
        if (nb_ptrs[i] == ptr) {
            if (idx_out) *idx_out = i;
            return true;
        }
    }
    return false;
}

void nb_deallocate(void* ptr) {
    if (!ptr) return;
    size_t idx;
    if (nb_is_tracked_ptr(ptr, &idx)) {
        free(ptr);
        // Remove from tracking array
        nb_ptrs[idx] = nb_ptrs[--nb_ptr_count];
        nb_ptrs[nb_ptr_count] = NULL;
    }
    // else: ignore double free
}

void nb_gc_collect(void) {
    // No-op: No garbage collector implemented.
}

/* ============================
 * Event/Callback System Implementation
 * ============================
 */

#include <string.h>

#define NB_MAX_EVENTS 32
typedef struct {
    char name[64];
    nb_event_callback_t callback;
    void* user_data;
} nb_event_slot;

static nb_event_slot nb_events[NB_MAX_EVENTS];

int nb_event_register(const char* event_name, nb_event_callback_t callback, void* user_data) {
    if (!event_name || !callback) return -1;
    // Check if already registered
    for (int i = 0; i < NB_MAX_EVENTS; ++i) {
        if (nb_events[i].callback && strcmp(nb_events[i].name, event_name) == 0) {
            // Overwrite existing
            nb_events[i].callback = callback;
            nb_events[i].user_data = user_data;
            return 0;
        }
    }
    // Find empty slot
    for (int i = 0; i < NB_MAX_EVENTS; ++i) {
        if (!nb_events[i].callback) {
            strncpy(nb_events[i].name, event_name, sizeof(nb_events[i].name) - 1);
            nb_events[i].name[sizeof(nb_events[i].name) - 1] = '\0';
            nb_events[i].callback = callback;
            nb_events[i].user_data = user_data;
            return 0;
        }
    }
    return -1; // No slots available
}

int nb_event_unregister(const char* event_name) {
    if (!event_name) return -1;
    for (int i = 0; i < NB_MAX_EVENTS; ++i) {
        if (nb_events[i].callback && strcmp(nb_events[i].name, event_name) == 0) {
            nb_events[i].callback = NULL;
            nb_events[i].user_data = NULL;
            nb_events[i].name[0] = '\0';
            return 0;
        }
    }
    return -1;
}

void nb_event_dispatch(const char* event_name) {
    if (!event_name) return;
    for (int i = 0; i < NB_MAX_EVENTS; ++i) {
        if (nb_events[i].callback && strcmp(nb_events[i].name, event_name) == 0) {
            nb_events[i].callback(event_name, nb_events[i].user_data);
            return;
        }
    }
}

/* ============================
 * File I/O stub implementations
 * ============================
 */

/**
 * @brief Opens a file (stub).
 * @param path Path to the file.
 * @param mode File access mode string.
 * @return NULL (not implemented).
 */
void* nb_file_open(const char* path, const char* mode) {
    if (!path || !mode) return NULL;
    FILE* f = fopen(path, mode);
    return (void*)f;
}

/**
 * @brief Reads data from a file (stub).
 * @param handle File handle.
 * @param buffer Buffer to read into.
 * @param size Number of bytes to read.
 * @return -1 (not implemented).
 */
int nb_file_read(void* handle, void* buffer, size_t size) {
    if (!handle || !buffer || size == 0) return -1;
    size_t n = fread(buffer, 1, size, (FILE*)handle);
    if (n == 0 && ferror((FILE*)handle)) return -1;
    return (int)n;
}

/**
 * @brief Writes data to a file (stub).
 * @param handle File handle.
 * @param buffer Buffer to write from.
 * @param size Number of bytes to write.
 * @return -1 (not implemented).
 */
int nb_file_write(void* handle, const void* buffer, size_t size) {
    if (!handle || !buffer || size == 0) return -1;
    size_t n = fwrite(buffer, 1, size, (FILE*)handle);
    if (n == 0 && ferror((FILE*)handle)) return -1;
    return (int)n;
}

/**
 * @brief Closes a file (stub).
 * @param handle File handle.
 * @return -1 (not implemented).
 */
int nb_file_close(void* handle) {
    if (!handle) return -1;
    int res = fclose((FILE*)handle);
    return (res == 0) ? 0 : -1;
}
 // Seek in file
int nb_file_seek(void* handle, long offset, int whence) {
    if (!handle) return -1;
    int res = fseek((FILE*)handle, offset, whence);
    return (res == 0) ? 0 : -1;
}

// Delete file
/* ============================
 * Module Loading Implementation
 * ============================
 */

#if defined(_WIN32)
#include <windows.h>
#else
#include <dlfcn.h>
#endif

void* nb_module_load(const char* path) {
    if (!path) return NULL;
#if defined(_WIN32)
    HMODULE h = LoadLibraryA(path);
    return (void*)h;
#else
    void* handle = dlopen(path, RTLD_LAZY);
    return handle;
#endif
}

int nb_module_unload(void* handle) {
    if (!handle) return -1;
#if defined(_WIN32)
    return (FreeLibrary((HMODULE)handle) != 0) ? 0 : -1;
#else
    return (dlclose(handle) == 0) ? 0 : -1;
#endif
}

void* nb_module_symbol(void* handle, const char* symbol) {
    if (!handle || !symbol) return NULL;
#if defined(_WIN32)
    return (void*)GetProcAddress((HMODULE)handle, symbol);
#else
    return dlsym(handle, symbol);
#endif
}
int nb_file_delete(const char* path) {
    if (!path) return -1;
    int res = remove(path);
    return (res == 0) ? 0 : -1;
}

int nb_file_stat(const char* path, nb_file_info* info) {
    if (!path || !info) return -1;
    NB_STAT_STRUCT st;
    if (NB_STAT_FUNC(path, &st) != 0) return -1;
    info->size = (long long)st.st_size;
#if defined(_WIN32)
    info->mtime = (long long)st.st_mtime;
    info->is_dir = (st.st_mode & _S_IFDIR) ? 1 : 0;
#else
    info->mtime = (long long)st.st_mtime;
    info->is_dir = S_ISDIR(st.st_mode) ? 1 : 0;
#endif
    return 0;
}

// ============================
// Message Queue Implementation
// ============================
#include "native_bridge.h"
#if defined(_WIN32)
// Windows: Not implemented
struct nb_mq_handle {};
nb_mq_handle* nb_mq_create(const char* name, size_t max_msg, size_t msg_size) { (void)name; (void)max_msg; (void)msg_size; return NULL; }
int nb_mq_send(nb_mq_handle* handle, const void* msg, size_t msg_len) { (void)handle; (void)msg; (void)msg_len; return -1; }
int nb_mq_receive(nb_mq_handle* handle, void* buffer, size_t buffer_len) { (void)handle; (void)buffer; (void)buffer_len; return -1; }
int nb_mq_destroy(nb_mq_handle* handle) { (void)handle; return -1; }
#else
#include <mqueue.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>

struct nb_mq_handle {
    mqd_t mqd;
    size_t msg_size;
    char* name;
};

nb_mq_handle* nb_mq_create(const char* name, size_t max_msg, size_t msg_size) {
    struct mq_attr attr;
    attr.mq_flags = 0;
    attr.mq_maxmsg = max_msg;
    attr.mq_msgsize = msg_size;
    attr.mq_curmsgs = 0;
    mqd_t mqd;
    char* mq_name = NULL;
    if (name && name[0]) {
        // POSIX requires names to start with '/'
        size_t nlen = strlen(name);
        mq_name = (char*)malloc(nlen + 2);
        mq_name[0] = '/';
        strcpy(mq_name + 1, name);
        mqd = mq_open(mq_name, O_CREAT | O_RDWR, 0600, &attr);
        if (mqd == (mqd_t)-1) { free(mq_name); return NULL; }
    } else {
        // Anonymous: use O_TMPFILE if available, else fallback to random name
        mq_name = NULL;
        mqd = mq_open("/tmp_nb_mq", O_CREAT | O_RDWR, 0600, &attr);
        if (mqd == (mqd_t)-1) return NULL;
    }
    nb_mq_handle* h = (nb_mq_handle*)malloc(sizeof(nb_mq_handle));
    h->mqd = mqd;
    h->msg_size = msg_size;
    h->name = mq_name;
    return h;
}

int nb_mq_send(nb_mq_handle* handle, const void* msg, size_t msg_len) {
    if (!handle || !msg || msg_len > handle->msg_size) return -1;
    int res = mq_send(handle->mqd, (const char*)msg, msg_len, 0);
    return (res == 0) ? 0 : -1;
}

int nb_mq_receive(nb_mq_handle* handle, void* buffer, size_t buffer_len) {
    if (!handle || !buffer || buffer_len < handle->msg_size) return -1;
    ssize_t n = mq_receive(handle->mqd, (char*)buffer, handle->msg_size, NULL);
    return (n >= 0) ? (int)n : -1;
}

int nb_mq_destroy(nb_mq_handle* handle) {
    if (!handle) return -1;
    int res = mq_close(handle->mqd);
    if (handle->name) {
        mq_unlink(handle->name);
        free(handle->name);
    }
    free(handle);
    return (res == 0) ? 0 : -1;
}
#endif

// System operation stubs
#if defined(_WIN32)
int nb_system_call(const char* command __attribute__((unused))) {
    // Stub: system call not implemented on Windows
    return -1;
}
#else
#include <stdlib.h>
int nb_system_call(const char* command) {
    if (!command) return -1;
    int ret = system(command);
    return (ret == -1) ? -1 : 0;
}
#endif

/* ============================
 * Directory Operation Implementations
 * ============================
 */

#include <string.h>
#if defined(_WIN32)
#include <windows.h>
#else
#include <dirent.h>
#include <errno.h>
#include <unistd.h>
#endif

#include <sys/stat.h>
#include <stdint.h>
#include "native_bridge.h"

// Helper for freeing nb_dir_entry array
static void nb_free_dir_entries(nb_dir_entry* entries, size_t count) {
    if (!entries) return;
    for (size_t i = 0; i < count; ++i) {
        free(entries[i].name);
    }
    free(entries);
}

int nb_dir_list(const char* path, nb_dir_entry** entries, size_t* count) {
    if (!path || !entries || !count) return -1;
    *entries = NULL;
    *count = 0;
#if defined(_WIN32)
    WIN32_FIND_DATAA ffd;
    char search_path[MAX_PATH];
    snprintf(search_path, sizeof(search_path), "%s\\*", path);
    HANDLE hFind = FindFirstFileA(search_path, &ffd);
    if (hFind == INVALID_HANDLE_VALUE) return -1;
    size_t cap = 16;
    nb_dir_entry* arr = (nb_dir_entry*)malloc(cap * sizeof(nb_dir_entry));
    size_t n = 0;
    do {
        if (strcmp(ffd.cFileName, ".") == 0 || strcmp(ffd.cFileName, "..") == 0) continue;
        if (n == cap) {
            cap *= 2;
            nb_dir_entry* tmp = (nb_dir_entry*)realloc(arr, cap * sizeof(nb_dir_entry));
            if (!tmp) { nb_free_dir_entries(arr, n); FindClose(hFind); return -1; }
            arr = tmp;
        }
        arr[n].name = strdup(ffd.cFileName);
        arr[n].is_dir = (ffd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ? 1 : 0;
        n++;
    } while (FindNextFileA(hFind, &ffd) != 0);
    FindClose(hFind);
    *entries = arr;
    *count = n;
    return 0;
#else
    DIR* dir = opendir(path);
    if (!dir) return -1;
    size_t cap = 16;
    nb_dir_entry* arr = (nb_dir_entry*)malloc(cap * sizeof(nb_dir_entry));
    size_t n = 0;
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) continue;
        if (n == cap) {
            cap *= 2;
            nb_dir_entry* tmp = (nb_dir_entry*)realloc(arr, cap * sizeof(nb_dir_entry));
            if (!tmp) { nb_free_dir_entries(arr, n); closedir(dir); return -1; }
            arr = tmp;
        }
        arr[n].name = strdup(entry->d_name);
        arr[n].is_dir = 0;
#if defined(_DIRENT_HAVE_D_TYPE)
        // Use d_type if available and reliable, otherwise fallback to stat
        if (
    #ifdef DT_DIR
            entry->d_type == DT_DIR
    #else
            0
    #endif
        ) {
            arr[n].is_dir = 1;
        } else if (
    #ifdef DT_UNKNOWN
            entry->d_type == DT_UNKNOWN ||
    #endif
            1 // Always check with stat if not DT_DIR
        ) {
            char fullpath[4096];
            snprintf(fullpath, sizeof(fullpath), "%s/%s", path, entry->d_name);
            struct stat st;
            if (stat(fullpath, &st) == 0) {
                arr[n].is_dir = S_ISDIR(st.st_mode) ? 1 : 0;
            } else {
                arr[n].is_dir = 0; // Could not stat, treat as file
            }
        }
#else
        // If _DIRENT_HAVE_D_TYPE is not defined, always use stat
        {
            char fullpath[4096];
            snprintf(fullpath, sizeof(fullpath), "%s/%s", path, entry->d_name);
            struct stat st;
            if (stat(fullpath, &st) == 0) {
                arr[n].is_dir = S_ISDIR(st.st_mode) ? 1 : 0;
            } else {
                arr[n].is_dir = 0; // Could not stat, treat as file
            }
        }
#endif
        n++;
    }
    closedir(dir);
    *entries = arr;
    *count = n;
    return 0;
#endif
}

int nb_dir_create(const char* path) {
    if (!path) return -1;
#if defined(_WIN32)
    return CreateDirectoryA(path, NULL) ? 0 : -1;
#else
    return mkdir(path, 0777) == 0 ? 0 : -1;
#endif
}

int nb_dir_remove(const char* path) {
    if (!path) return -1;
#if defined(_WIN32)
    return RemoveDirectoryA(path) ? 0 : -1;
#else
    return rmdir(path) == 0 ? 0 : -1;
#endif
}

int nb_dir_exists(const char* path) {
    if (!path) return -1;
#if defined(_WIN32)
    DWORD attr = GetFileAttributesA(path);
    if (attr == INVALID_FILE_ATTRIBUTES) return 0;
    return (attr & FILE_ATTRIBUTE_DIRECTORY) ? 1 : 0;
#else
    struct stat st;
    if (stat(path, &st) != 0) return 0;
    return S_ISDIR(st.st_mode) ? 1 : 0;
#endif
}

// ============================
// System Operation Primitives
// ============================

#include <string.h>
#include <time.h>
#if defined(_WIN32)
#include <windows.h>
#include <process.h>
#else
#include <unistd.h>
#include <sys/wait.h>
#endif

int nb_get_env(const char* key, char* value, size_t value_size) {
    if (!key || !value || value_size == 0) return -1;
#if defined(_WIN32)
    DWORD len = GetEnvironmentVariableA(key, value, (DWORD)value_size);
    if (len == 0 || len >= value_size) return -1;
    return 0;
#else
    const char* env = getenv(key);
    if (!env) return -1;
    strncpy(value, env, value_size - 1);
    value[value_size - 1] = '\0';
    return 0;
#endif
}

int nb_get_pid(void) {
#if defined(_WIN32)
    return (int)_getpid();
#else
    return (int)getpid();
#endif
}

double nb_time(void) {
#if defined(_WIN32)
    FILETIME ft;
    GetSystemTimeAsFileTime(&ft);
    ULARGE_INTEGER ull;
    ull.LowPart = ft.dwLowDateTime;
    ull.HighPart = ft.dwHighDateTime;
    // Windows FILETIME is 100-nanosecond intervals since Jan 1, 1601
    // Convert to seconds since Unix epoch
    const ULONGLONG EPOCH_DIFF = 11644473600ULL;
    double seconds = (double)(ull.QuadPart / 10000000ULL) - (double)EPOCH_DIFF;
    return seconds;
#else
    return (double)time(NULL);
#endif
}

double nb_clock(void) {
    return ((double)clock()) / CLOCKS_PER_SEC;
}

int nb_spawn(const char* path, char* const argv[]) {
    if (!path || !argv) return -1;
#if defined(_WIN32)
    // Windows: use _spawnvp, returns pid or -1
    int pid = _spawnvp(_P_NOWAIT, path, argv);
    return pid < 0 ? -1 : pid;
#else
    pid_t pid = fork();
    if (pid < 0) return -1;
    if (pid == 0) {
        execvp(path, argv);
        _exit(127);
    }
    return (int)pid;
#endif
}

int nb_waitpid(int pid, int* status) {
#if defined(_WIN32)
    // Not implemented on Windows
    (void)pid; (void)status;
    return -1;
#else
    int st = 0;
    pid_t ret = waitpid((pid_t)pid, &st, 0);
    if (ret < 0) return -1;
    if (status) *status = st;
    return 0;
#endif
}
