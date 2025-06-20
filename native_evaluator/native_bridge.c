// PaTLang Native Bridge - Phase 1 Implementation
// Provides essential native operations for self-hosting evaluator

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <time.h>
#include <math.h>

#ifdef _WIN32
    #include <windows.h>
#else
    #include <unistd.h>
    #ifndef _POSIX_C_SOURCE
        #define _POSIX_C_SOURCE 199309L
    #endif
#endif

// PaTLang value representation in C
typedef struct {
    uint32_t type_tag;      // Type identifier
    uint32_t ref_count;     // Reference count for GC
    uint64_t data;          // Actual data or pointer
    uint32_t flags;         // Additional flags (gc_mark, etc.)
} PaTLangValue;

// Memory allocation result
typedef struct {
    void* address;
    size_t actual_size;
    int success;
    double allocation_time;
    uint32_t handle;
} AllocationResult;

// Operation result structure
typedef struct {
    int success;
    void* result_data;
    size_t result_size;
    double execution_time;
    int error_code;
    char error_message[256];
} OperationResult;

// Native bridge interface
typedef struct {
    // Memory management
    void* (*allocate)(size_t size);
    void (*deallocate)(void* ptr);
    void* (*reallocate)(void* ptr, size_t new_size);
    
    // System operations
    double (*current_time)(void);
    int (*print_debug)(const char* message);
    
    // Math operations
    double (*math_pow)(double base, double exponent);
    double (*math_sqrt)(double value);
    double (*math_sin)(double value);
    double (*math_cos)(double value);
    
    // String operations
    char* (*string_copy)(const char* source);
    int (*string_compare)(const char* str1, const char* str2);
    char* (*string_concat)(const char* str1, const char* str2);
    
    // Bridge metadata
    uint32_t version;
    uint32_t initialized;
    uint64_t total_allocated;
    uint64_t total_freed;
} NativeBridge;

// Global bridge instance
static NativeBridge g_bridge = {0};

// Forward declarations
static void* bridge_allocate(size_t size);
static void bridge_deallocate(void* ptr);
static void* bridge_reallocate(void* ptr, size_t new_size);
static double bridge_current_time(void);
static int bridge_print_debug(const char* message);
static double bridge_math_pow(double base, double exponent);
static double bridge_math_sqrt(double value);
static double bridge_math_sin(double value);
static double bridge_math_cos(double value);
static char* bridge_string_copy(const char* source);
static int bridge_string_compare(const char* str1, const char* str2);
static char* bridge_string_concat(const char* str1, const char* str2);

// Initialize the native bridge
int patlang_bridge_initialize(void) {
    if (g_bridge.initialized) {
        return 1; // Already initialized
    }
    
    // Set up function pointers
    g_bridge.allocate = bridge_allocate;
    g_bridge.deallocate = bridge_deallocate;
    g_bridge.reallocate = bridge_reallocate;
    g_bridge.current_time = bridge_current_time;
    g_bridge.print_debug = bridge_print_debug;
    g_bridge.math_pow = bridge_math_pow;
    g_bridge.math_sqrt = bridge_math_sqrt;
    g_bridge.math_sin = bridge_math_sin;
    g_bridge.math_cos = bridge_math_cos;
    g_bridge.string_copy = bridge_string_copy;
    g_bridge.string_compare = bridge_string_compare;
    g_bridge.string_concat = bridge_string_concat;
    
    // Initialize metadata
    g_bridge.version = 1;
    g_bridge.initialized = 1;
    g_bridge.total_allocated = 0;
    g_bridge.total_freed = 0;
    
    printf("PaTLang Native Bridge v%u initialized\n", g_bridge.version);
    return 0; // Success
}

// Main entry point for native operations
int patlang_native_call(uint32_t operation_id, void* args, void* result) {
    if (!g_bridge.initialized) {
        return -1; // Bridge not initialized
    }
    
    OperationResult* op_result = (OperationResult*)result;
    clock_t start_time = clock();
    
    int status = 0;
    
    switch (operation_id) {
        case 0x1000: // Memory allocation
            status = handle_memory_allocation(args, op_result);
            break;
        case 0x1001: // Memory deallocation  
            status = handle_memory_deallocation(args, op_result);
            break;
        case 0x1002: // Memory reallocation
            status = handle_memory_reallocation(args, op_result);
            break;
        case 0x2000: // Time operations
            status = handle_time_operation(args, op_result);
            break;
        case 0x3000: // Debug output
            status = handle_debug_operation(args, op_result);
            break;
        case 0x4000: // Math operations
            status = handle_math_operation(args, op_result);
            break;
        case 0x5000: // String operations
            status = handle_string_operation(args, op_result);
            break;
        default:
            op_result->success = 0;
            op_result->error_code = -2;
            snprintf(op_result->error_message, sizeof(op_result->error_message), 
                    "Unknown operation ID: 0x%X", operation_id);
            status = -2;
    }
    
    clock_t end_time = clock();
    op_result->execution_time = ((double)(end_time - start_time)) / CLOCKS_PER_SEC;
    
    return status;
}

// Memory allocation handler
int handle_memory_allocation(void* args, OperationResult* result) {
    struct {
        size_t size;
        uint32_t alignment;
        uint32_t type_id;
    } *alloc_args = args;
    
    if (alloc_args->size == 0) {
        result->success = 0;
        result->error_code = -3;
        strcpy(result->error_message, "Cannot allocate zero bytes");
        return -3;
    }
    
    // Allocate memory with alignment consideration
    size_t actual_size = alloc_args->size;
    if (alloc_args->alignment > 1) {
        actual_size = ((alloc_args->size + alloc_args->alignment - 1) / alloc_args->alignment) * alloc_args->alignment;
    }
    
    void* ptr = g_bridge.allocate(actual_size);
    
    if (ptr != NULL) {
        // Initialize memory to zero
        memset(ptr, 0, actual_size);
        
        // Update statistics
        g_bridge.total_allocated += actual_size;
        
        // Prepare result
        AllocationResult* alloc_result = malloc(sizeof(AllocationResult));
        alloc_result->address = ptr;
        alloc_result->actual_size = actual_size;
        alloc_result->success = 1;
        alloc_result->allocation_time = result->execution_time;
        alloc_result->handle = (uint32_t)(uintptr_t)ptr; // Simple handle
        
        result->success = 1;
        result->result_data = alloc_result;
        result->result_size = sizeof(AllocationResult);
        result->error_code = 0;
        
        #ifdef PATLANG_DEBUG_MEMORY
        printf("Allocated %zu bytes at %p (requested: %zu, type: %u)\n", 
               actual_size, ptr, alloc_args->size, alloc_args->type_id);
        #endif
        
        return 0;
    } else {
        result->success = 0;
        result->error_code = -4;
        strcpy(result->error_message, "Memory allocation failed");
        return -4;
    }
}

// Memory deallocation handler
int handle_memory_deallocation(void* args, OperationResult* result) {
    struct {
        void* address;
        size_t size; // For statistics
    } *dealloc_args = args;
    
    if (dealloc_args->address == NULL) {
        result->success = 1; // Deallocating NULL is a no-op
        result->error_code = 0;
        return 0;
    }
    
    g_bridge.deallocate(dealloc_args->address);
    g_bridge.total_freed += dealloc_args->size;
    
    #ifdef PATLANG_DEBUG_MEMORY
    printf("Deallocated memory at %p (size: %zu)\n", 
           dealloc_args->address, dealloc_args->size);
    #endif
    
    result->success = 1;
    result->error_code = 0;
    return 0;
}

// Time operation handler
int handle_time_operation(void* args, OperationResult* result) {
    struct {
        uint32_t operation_type; // 0=current_time, 1=sleep, etc.
        double value;
    } *time_args = args;
    
    switch (time_args->operation_type) {
        case 0: { // Current time
            double current = g_bridge.current_time();
            double* time_result = malloc(sizeof(double));
            *time_result = current;
            
            result->success = 1;
            result->result_data = time_result;
            result->result_size = sizeof(double);
            result->error_code = 0;
            return 0;
        }
        default:
            result->success = 0;
            result->error_code = -5;
            snprintf(result->error_message, sizeof(result->error_message),
                    "Unknown time operation: %u", time_args->operation_type);
            return -5;
    }
}

// Debug operation handler
int handle_debug_operation(void* args, OperationResult* result) {
    struct {
        const char* message;
        uint32_t message_length;
    } *debug_args = args;
    
    int print_result = g_bridge.print_debug(debug_args->message);
    
    result->success = (print_result >= 0) ? 1 : 0;
    result->error_code = (print_result >= 0) ? 0 : print_result;
    
    if (print_result < 0) {
        strcpy(result->error_message, "Debug print failed");
    }
    
    return (print_result >= 0) ? 0 : print_result;
}

// Math operation handler
int handle_math_operation(void* args, OperationResult* result) {
    struct {
        uint32_t operation_type; // 0=pow, 1=sqrt, 2=sin, 3=cos
        double operand1;
        double operand2; // Used for operations requiring two operands
    } *math_args = args;
    
    double math_result;
    int success = 1;
    
    switch (math_args->operation_type) {
        case 0: // Power
            math_result = g_bridge.math_pow(math_args->operand1, math_args->operand2);
            break;
        case 1: // Square root
            if (math_args->operand1 < 0) {
                success = 0;
                strcpy(result->error_message, "Square root of negative number");
            } else {
                math_result = g_bridge.math_sqrt(math_args->operand1);
            }
            break;
        case 2: // Sine
            math_result = g_bridge.math_sin(math_args->operand1);
            break;
        case 3: // Cosine
            math_result = g_bridge.math_cos(math_args->operand1);
            break;
        default:
            success = 0;
            snprintf(result->error_message, sizeof(result->error_message),
                    "Unknown math operation: %u", math_args->operation_type);
    }
    
    if (success) {
        double* result_data = malloc(sizeof(double));
        *result_data = math_result;
        
        result->success = 1;
        result->result_data = result_data;
        result->result_size = sizeof(double);
        result->error_code = 0;
        return 0;
    } else {
        result->success = 0;
        result->error_code = -6;
        return -6;
    }
}

// String operation handler
int handle_string_operation(void* args, OperationResult* result) {
    struct {
        uint32_t operation_type; // 0=copy, 1=compare, 2=concat
        const char* string1;
        const char* string2; // Used for operations requiring two strings
        size_t string1_length;
        size_t string2_length;
    } *string_args = args;
    
    switch (string_args->operation_type) {
        case 0: { // String copy
            char* copied = g_bridge.string_copy(string_args->string1);
            if (copied) {
                result->success = 1;
                result->result_data = copied;
                result->result_size = strlen(copied) + 1;
                result->error_code = 0;
                return 0;
            } else {
                result->success = 0;
                result->error_code = -7;
                strcpy(result->error_message, "String copy failed");
                return -7;
            }
        }
        case 1: { // String compare
            int cmp_result = g_bridge.string_compare(string_args->string1, string_args->string2);
            int* result_data = malloc(sizeof(int));
            *result_data = cmp_result;
            
            result->success = 1;
            result->result_data = result_data;
            result->result_size = sizeof(int);
            result->error_code = 0;
            return 0;
        }
        case 2: { // String concatenate
            char* concatenated = g_bridge.string_concat(string_args->string1, string_args->string2);
            if (concatenated) {
                result->success = 1;
                result->result_data = concatenated;
                result->result_size = strlen(concatenated) + 1;
                result->error_code = 0;
                return 0;
            } else {
                result->success = 0;
                result->error_code = -8;
                strcpy(result->error_message, "String concatenation failed");
                return -8;
            }
        }
        default:
            result->success = 0;
            result->error_code = -9;
            snprintf(result->error_message, sizeof(result->error_message),
                    "Unknown string operation: %u", string_args->operation_type);
            return -9;
    }
}

// Implementation of bridge functions
static void* bridge_allocate(size_t size) {
    return malloc(size);
}

static void bridge_deallocate(void* ptr) {
    free(ptr);
}

static void* bridge_reallocate(void* ptr, size_t new_size) {
    return realloc(ptr, new_size);
}

static double bridge_current_time(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_REALTIME, &ts) == 0) {
        return (double)ts.tv_sec + (double)ts.tv_nsec / 1000000000.0;
    } else {
        // Fallback to less precise time
        return (double)clock() / CLOCKS_PER_SEC;
    }
}

static int bridge_print_debug(const char* message) {
    if (message == NULL) {
        return -1;
    }
    
    printf("[PaTLang Debug]: %s\n", message);
    fflush(stdout);
    return 0;
}

static double bridge_math_pow(double base, double exponent) {
    return pow(base, exponent);
}

static double bridge_math_sqrt(double value) {
    return sqrt(value);
}

static double bridge_math_sin(double value) {
    return sin(value);
}

static double bridge_math_cos(double value) {
    return cos(value);
}

static char* bridge_string_copy(const char* source) {
    if (source == NULL) {
        return NULL;
    }
    
    size_t length = strlen(source);
    char* copy = malloc(length + 1);
    if (copy) {
        strcpy(copy, source);
    }
    return copy;
}

static int bridge_string_compare(const char* str1, const char* str2) {
    if (str1 == NULL && str2 == NULL) {
        return 0;
    }
    if (str1 == NULL) {
        return -1;
    }
    if (str2 == NULL) {
        return 1;
    }
    
    return strcmp(str1, str2);
}

static char* bridge_string_concat(const char* str1, const char* str2) {
    if (str1 == NULL || str2 == NULL) {
        return NULL;
    }
    
    size_t len1 = strlen(str1);
    size_t len2 = strlen(str2);
    char* result = malloc(len1 + len2 + 1);
    
    if (result) {
        strcpy(result, str1);
        strcat(result, str2);
    }
    
    return result;
}

// Bridge statistics and debugging
void patlang_bridge_get_stats(void* stats_buffer, size_t buffer_size) {
    struct {
        uint64_t total_allocated;
        uint64_t total_freed;
        uint64_t current_usage;
        uint32_t version;
        uint32_t initialized;
    } stats;
    
    stats.total_allocated = g_bridge.total_allocated;
    stats.total_freed = g_bridge.total_freed;
    stats.current_usage = g_bridge.total_allocated - g_bridge.total_freed;
    stats.version = g_bridge.version;
    stats.initialized = g_bridge.initialized;
    
    if (buffer_size >= sizeof(stats)) {
        memcpy(stats_buffer, &stats, sizeof(stats));
    }
}

// Bridge cleanup
void patlang_bridge_cleanup(void) {
    if (g_bridge.initialized) {
        printf("PaTLang Native Bridge cleanup - Memory usage: allocated=%llu, freed=%llu, current=%llu\n",
               g_bridge.total_allocated, g_bridge.total_freed, 
               g_bridge.total_allocated - g_bridge.total_freed);
        
        g_bridge.initialized = 0;
    }
}