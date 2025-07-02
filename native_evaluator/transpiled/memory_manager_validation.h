#ifndef MEMORY_MANAGER_VALIDATION_H
#define MEMORY_MANAGER_VALIDATION_H

#include "transpiled_memory_manager.h"
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Memory Manager State Validation and Corruption Detection
typedef struct {
    bool state_valid;
    bool pools_consistent;
    bool statistics_accurate;
    bool corruption_detected;
    size_t corruption_count;
    char* corruption_details;
    size_t memory_leaks_detected;
    size_t total_allocations_tracked;
    size_t total_deallocations_tracked;
    double validation_time;
} MemoryManagerValidationResult;

typedef struct {
    bool reset_successful;
    size_t pools_reset;
    size_t memory_cleared;
    size_t objects_deallocated;
    double reset_time;
    char* reset_errors;
} MemoryManagerResetResult;

typedef struct {
    bool isolation_active;
    size_t checkpoint_id;
    size_t pre_test_allocations;
    size_t pre_test_memory_usage;
    AllocationStats baseline_stats;
    double checkpoint_time;
} MemoryManagerCheckpoint;

// Core validation functions
MemoryManagerValidationResult validate_memory_manager_state(MemoryManager* mm);
bool detect_memory_corruption(MemoryManager* mm);
bool validate_memory_pools(MemoryManager* mm);
bool check_allocation_statistics_integrity(MemoryManager* mm);

// Memory manager reset and isolation
MemoryManagerResetResult reset_memory_manager(MemoryManager* mm);
MemoryManagerCheckpoint create_memory_checkpoint(MemoryManager* mm);
bool restore_memory_checkpoint(MemoryManager* mm, MemoryManagerCheckpoint* checkpoint);

// Enhanced allocation with corruption detection
AllocationResult safe_allocate_with_validation(ObjectType type, size_t size, size_t alignment, MemoryManager* mm);
DeallocationResult safe_deallocate_with_validation(void* address, MemoryManager* mm);

// Memory leak detection
size_t detect_memory_leaks(MemoryManager* mm);
bool track_allocation_lifecycle(MemoryManager* mm, void* address, size_t size);
bool verify_deallocation_lifecycle(MemoryManager* mm, void* address);

// Pool integrity functions
bool validate_pool_free_list(MemoryPool* pool);
bool check_pool_memory_boundaries(MemoryPool* pool);
size_t count_pool_corruption_markers(MemoryPool* pool);

// Test isolation utilities
bool prepare_isolated_test_environment(MemoryManager* mm);
bool cleanup_isolated_test_environment(MemoryManager* mm);
bool verify_test_environment_isolation(MemoryManager* mm);

// Enhanced error reporting
void report_memory_corruption(MemoryManager* mm, const char* corruption_type, const char* details);
void log_allocation_history(MemoryManager* mm);
void generate_memory_diagnostics_report(MemoryManager* mm);

#ifdef __cplusplus
}
#endif

#endif // MEMORY_MANAGER_VALIDATION_H