#ifndef TRANSPILED_MEMORY_MANAGER_H
#define TRANSPILED_MEMORY_MANAGER_H

#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Memory management types and structures - transpiled from PaTLang

// Object types for memory management
typedef enum {
    OBJECT_TYPE_NUMBER,
    OBJECT_TYPE_STRING,
    OBJECT_TYPE_BOOLEAN,
    OBJECT_TYPE_ARRAY,
    OBJECT_TYPE_FUNCTION,
    OBJECT_TYPE_CUSTOM
} ObjectType;

// Memory pool allocation strategies
typedef enum {
    POOL_STRATEGY_FREE_LIST,
    POOL_STRATEGY_BITMAP,
    POOL_STRATEGY_STACK
} PoolStrategy;

// Garbage collection types
typedef enum {
    GC_TYPE_MINOR,
    GC_TYPE_MAJOR,
    GC_TYPE_FULL
} GCType;

// Memory pool structure
typedef struct {
    size_t pool_id;
    size_t object_size;
    size_t total_objects;
    size_t free_objects;
    PoolStrategy allocation_strategy;
    void* memory_base;
    void** free_list;
    double creation_time;
} MemoryPool;

// Allocation statistics
typedef struct {
    size_t total_allocations;
    size_t total_deallocations;
    size_t current_memory_usage;
    size_t peak_memory_usage;
    size_t gc_cycles;
    size_t allocation_failures;
} AllocationStats;

// Memory manager structure
typedef struct {
    MemoryPool** memory_pools;
    size_t num_pools;
    AllocationStats allocation_stats;
    size_t gc_threshold;
    size_t total_allocated;
    size_t total_freed;
    bool auto_gc_enabled;
} MemoryManager;

// Allocation result structure
typedef struct {
    bool success;
    void* address;
    size_t actual_size;
    double allocation_time;
    size_t pool_id;
    int ref_count;
    bool tracked;
    bool heap_allocated;
    bool native_allocated;
    char* error_message;
} AllocationResult;

// Deallocation result structure
typedef struct {
    bool success;
    bool deallocated;
    bool ref_count_decremented;
    int new_ref_count;
    size_t memory_freed;
    char* error_message;
} DeallocationResult;

// Garbage collection result structure
typedef struct {
    bool success;
    size_t memory_freed;
    size_t objects_collected;
    bool gc_completed;
    double gc_time;
    GCType gc_type;
    char* error_message;
} GCResult;

// Memory statistics structure
typedef struct {
    AllocationStats allocation_stats;
    size_t total_memory_used;
    size_t peak_memory_used;
    double gc_efficiency;
    double fragmentation_ratio;
    size_t pool_count;
    bool valid;
} MemoryStatistics;

// Memory integrity validation result
typedef struct {
    bool integrity_check_passed;
    bool corruption_detected;
    bool heap_valid;
    bool pools_valid;
    bool ref_counts_valid;
    bool gc_metadata_valid;
} MemoryIntegrityResult;

// Main memory manager functions
MemoryManager* patlang_create_memory_manager(size_t initial_heap_size);
void patlang_destroy_memory_manager(MemoryManager* mm);

// Memory pool management functions
MemoryPool* patlang_create_memory_pool(size_t object_size, size_t initial_count);
void patlang_destroy_memory_pool(MemoryPool* pool);

// Object allocation and deallocation functions
AllocationResult patlang_allocate_object(ObjectType type, size_t size, size_t alignment, MemoryManager* mm);
AllocationResult patlang_allocate_from_pool(ObjectType type, size_t size, size_t alignment, MemoryManager* mm);
AllocationResult patlang_allocate_medium_object(ObjectType type, size_t size, size_t alignment, MemoryManager* mm);
AllocationResult patlang_allocate_large_object(ObjectType type, size_t size, size_t alignment, MemoryManager* mm);
DeallocationResult patlang_deallocate_object(void* address, MemoryManager* mm);

// Garbage collection functions
GCResult patlang_trigger_gc(GCType gc_type, MemoryManager* mm);
GCResult patlang_perform_minor_gc(MemoryManager* mm);
GCResult patlang_perform_major_gc(MemoryManager* mm);
GCResult patlang_perform_full_gc(MemoryManager* mm);

// Memory statistics and debugging functions
MemoryStatistics patlang_get_memory_statistics(MemoryManager* mm);
MemoryIntegrityResult patlang_validate_memory_integrity(MemoryManager* mm);

#ifdef __cplusplus
}
#endif

// Enhanced Memory Manager Functions with Validation
MemoryManager* patlang_create_memory_manager_with_validation(size_t initial_heap_size);
bool patlang_reset_memory_manager_state(MemoryManager* mm);
AllocationResult patlang_allocate_object_with_validation(ObjectType type, size_t size, size_t alignment, MemoryManager* mm);
bool patlang_prepare_test_isolation(MemoryManager* mm);
bool patlang_cleanup_test_isolation(MemoryManager* mm);

#endif // TRANSPILED_MEMORY_MANAGER_H