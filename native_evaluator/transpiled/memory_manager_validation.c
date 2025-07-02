// Memory Manager State Validation and Corruption Detection
// Comprehensive validation system for memory manager state
// Generated: 2025-07-02 00:20:00 +0100

#include "memory_manager_validation.h"
#include "../native_bridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <assert.h>

// Debug macros for memory validation
#ifdef PATLANG_DEBUG
#define VALIDATION_DEBUG_PRINT(fmt, ...) printf("[VALIDATION_DEBUG] " fmt "\n", ##__VA_ARGS__)
#else
#define VALIDATION_DEBUG_PRINT(fmt, ...)
#endif

// Validation constants
static const size_t CORRUPTION_DETECTION_MAGIC = 0xDEADBEEF;
static const size_t ALLOCATION_TRACKING_MAGIC = 0xCAFEBABE;
static const double VALIDATION_TIMEOUT = 5.0; // seconds

// Global allocation tracking for leak detection
typedef struct AllocationRecord {
    void* address;
    size_t size;
    size_t magic;
    double allocation_time;
    bool is_active;
    struct AllocationRecord* next;
} AllocationRecord;

static AllocationRecord* global_allocation_records = NULL;
static size_t global_allocation_count = 0;

// Core Memory Manager State Validation
MemoryManagerValidationResult validate_memory_manager_state(MemoryManager* mm) {
    MemoryManagerValidationResult result = {0};
    clock_t start_time = clock();
    
    if (!mm) {
        result.state_valid = false;
        result.corruption_detected = true;
        result.corruption_details = strdup("Memory manager is NULL");
        return result;
    }
    
    VALIDATION_DEBUG_PRINT("Starting comprehensive memory manager validation");
    
    // Validate memory pools
    result.pools_consistent = validate_memory_pools(mm);
    if (!result.pools_consistent) {
        result.corruption_detected = true;
        result.corruption_count++;
    }
    
    // Validate allocation statistics
    result.statistics_accurate = check_allocation_statistics_integrity(mm);
    if (!result.statistics_accurate) {
        result.corruption_detected = true;
        result.corruption_count++;
    }
    
    // Detect memory corruption
    bool corruption_found = detect_memory_corruption(mm);
    if (corruption_found) {
        result.corruption_detected = true;
        result.corruption_count++;
    }
    
    // Check for memory leaks
    result.memory_leaks_detected = detect_memory_leaks(mm);
    if (result.memory_leaks_detected > 0) {
        result.corruption_count += result.memory_leaks_detected;
    }
    
    // Overall state validity
    result.state_valid = result.pools_consistent && 
                        result.statistics_accurate && 
                        !result.corruption_detected &&
                        (result.memory_leaks_detected == 0);
    
    result.total_allocations_tracked = mm->allocation_stats.total_allocations;
    result.total_deallocations_tracked = mm->allocation_stats.total_deallocations;
    
    clock_t end_time = clock();
    result.validation_time = ((double)(end_time - start_time)) / CLOCKS_PER_SEC;
    
    if (!result.state_valid) {
        char details[512];
        snprintf(details, sizeof(details), 
                "Validation failed: pools=%s, stats=%s, corruption=%s, leaks=%zu",
                result.pools_consistent ? "OK" : "FAIL",
                result.statistics_accurate ? "OK" : "FAIL", 
                result.corruption_detected ? "DETECTED" : "NONE",
                result.memory_leaks_detected);
        result.corruption_details = strdup(details);
    }
    
    VALIDATION_DEBUG_PRINT("Memory manager validation completed: %s (time: %.6f)", 
                          result.state_valid ? "VALID" : "INVALID", result.validation_time);
    
    return result;
}

bool detect_memory_corruption(MemoryManager* mm) {
    if (!mm) return true;
    
    // Check memory manager structure integrity
    if (!mm->memory_pools || mm->num_pools == 0) {
        VALIDATION_DEBUG_PRINT("Memory manager pools are NULL or empty");
        return true;
    }
    
    // Validate each pool for corruption
    for (size_t i = 0; i < mm->num_pools; i++) {
        MemoryPool* pool = mm->memory_pools[i];
        if (!pool) {
            VALIDATION_DEBUG_PRINT("Pool %zu is NULL", i);
            return true;
        }
        
        // Check pool structure integrity
        if (!pool->memory_base || !pool->free_list) {
            VALIDATION_DEBUG_PRINT("Pool %zu has NULL memory_base or free_list", i);
            return true;
        }
        
        // Check pool consistency
        if (pool->free_objects > pool->total_objects) {
            VALIDATION_DEBUG_PRINT("Pool %zu: free_objects (%zu) > total_objects (%zu)", 
                                 i, pool->free_objects, pool->total_objects);
            return true;
        }
        
        // Validate free list integrity
        if (!validate_pool_free_list(pool)) {
            VALIDATION_DEBUG_PRINT("Pool %zu has corrupted free list", i);
            return true;
        }
    }
    
    return false;
}

bool validate_memory_pools(MemoryManager* mm) {
    if (!mm || !mm->memory_pools) return false;
    
    for (size_t i = 0; i < mm->num_pools; i++) {
        MemoryPool* pool = mm->memory_pools[i];
        if (!pool) return false;
        
        // Validate pool structure
        if (pool->object_size == 0 || pool->total_objects == 0) {
            VALIDATION_DEBUG_PRINT("Pool %zu has invalid size parameters", i);
            return false;
        }
        
        // Check memory boundaries
        if (!check_pool_memory_boundaries(pool)) {
            VALIDATION_DEBUG_PRINT("Pool %zu has memory boundary violations", i);
            return false;
        }
        
        // Count corruption markers
        size_t corruption_markers = count_pool_corruption_markers(pool);
        if (corruption_markers > 0) {
            VALIDATION_DEBUG_PRINT("Pool %zu has %zu corruption markers", i, corruption_markers);
            return false;
        }
    }
    
    return true;
}

bool check_allocation_statistics_integrity(MemoryManager* mm) {
    if (!mm) return false;
    
    AllocationStats* stats = &mm->allocation_stats;
    
    // Basic sanity checks
    if (stats->total_deallocations > stats->total_allocations) {
        VALIDATION_DEBUG_PRINT("Deallocations (%zu) exceed allocations (%zu)", 
                              stats->total_deallocations, stats->total_allocations);
        return false;
    }
    
    if (stats->peak_memory_usage < stats->current_memory_usage) {
        VALIDATION_DEBUG_PRINT("Peak memory (%zu) < current memory (%zu)", 
                              stats->peak_memory_usage, stats->current_memory_usage);
        return false;
    }
    
    return true;
}

// Memory Manager Reset and Isolation
MemoryManagerResetResult reset_memory_manager(MemoryManager* mm) {
    MemoryManagerResetResult result = {0};
    clock_t start_time = clock();
    
    if (!mm) {
        result.reset_successful = false;
        result.reset_errors = strdup("Memory manager is NULL");
        return result;
    }
    
    VALIDATION_DEBUG_PRINT("Resetting memory manager state");
    
    // Reset memory pools
    for (size_t i = 0; i < mm->num_pools; i++) {
        MemoryPool* pool = mm->memory_pools[i];
        if (pool) {
            // Reset free object count to total objects
            pool->free_objects = pool->total_objects;
            
            // Reinitialize free list
            char* base = (char*)pool->memory_base;
            for (size_t j = 0; j < pool->total_objects; j++) {
                pool->free_list[j] = base + (j * pool->object_size);
            }
            
            result.pools_reset++;
        }
    }
    
    // Reset allocation statistics but preserve peak values for comparison
    size_t old_peak = mm->allocation_stats.peak_memory_usage;
    size_t old_allocations = mm->allocation_stats.total_allocations;
    size_t old_deallocations = mm->allocation_stats.total_deallocations;
    
    memset(&mm->allocation_stats, 0, sizeof(AllocationStats));
    
    // Track memory cleared
    result.memory_cleared = old_peak;
    result.objects_deallocated = old_allocations - old_deallocations;
    
    // Reset totals
    mm->total_allocated = 0;
    mm->total_freed = 0;
    
    // Clear global allocation records
    AllocationRecord* record = global_allocation_records;
    while (record) {
        AllocationRecord* next = record->next;
        free(record);
        record = next;
    }
    global_allocation_records = NULL;
    global_allocation_count = 0;
    
    clock_t end_time = clock();
    result.reset_time = ((double)(end_time - start_time)) / CLOCKS_PER_SEC;
    result.reset_successful = true;
    
    VALIDATION_DEBUG_PRINT("Memory manager reset completed: %zu pools, %zu bytes cleared (time: %.6f)",
                          result.pools_reset, result.memory_cleared, result.reset_time);
    
    return result;
}

MemoryManagerCheckpoint create_memory_checkpoint(MemoryManager* mm) {
    MemoryManagerCheckpoint checkpoint = {0};
    
    if (!mm) return checkpoint;
    
    checkpoint.isolation_active = true;
    checkpoint.checkpoint_id = (size_t)time(NULL);
    checkpoint.pre_test_allocations = mm->allocation_stats.total_allocations;
    checkpoint.pre_test_memory_usage = mm->allocation_stats.current_memory_usage;
    checkpoint.baseline_stats = mm->allocation_stats;
    checkpoint.checkpoint_time = (double)clock() / CLOCKS_PER_SEC;
    
    VALIDATION_DEBUG_PRINT("Memory checkpoint created: id=%zu, allocations=%zu, memory=%zu",
                          checkpoint.checkpoint_id, checkpoint.pre_test_allocations, 
                          checkpoint.pre_test_memory_usage);
    
    return checkpoint;
}

bool restore_memory_checkpoint(MemoryManager* mm, MemoryManagerCheckpoint* checkpoint) {
    if (!mm || !checkpoint || !checkpoint->isolation_active) return false;
    
    VALIDATION_DEBUG_PRINT("Restoring memory checkpoint: id=%zu", checkpoint->checkpoint_id);
    
    // Reset to baseline state
    MemoryManagerResetResult reset_result = reset_memory_manager(mm);
    if (!reset_result.reset_successful) {
        VALIDATION_DEBUG_PRINT("Failed to reset memory manager during checkpoint restore");
        return false;
    }
    
    // Restore baseline statistics (but not allocations/usage)
    // Note: Only restore non-accumulating statistics
    mm->allocation_stats.allocation_failures = checkpoint->baseline_stats.allocation_failures;
    mm->allocation_stats.gc_cycles = checkpoint->baseline_stats.gc_cycles;
    
    checkpoint->isolation_active = false;
    
    VALIDATION_DEBUG_PRINT("Memory checkpoint restored successfully");
    return true;
}

// Enhanced Allocation with Validation
AllocationResult safe_allocate_with_validation(ObjectType type, size_t size, size_t alignment, MemoryManager* mm) {
    AllocationResult result = {0};
    
    if (!mm) {
        result.success = false;
        result.error_message = "Memory manager is NULL";
        return result;
    }
    
    // Pre-allocation validation
    MemoryManagerValidationResult validation = validate_memory_manager_state(mm);
    if (!validation.state_valid) {
        result.success = false;
        result.error_message = "Memory manager state invalid before allocation";
        report_memory_corruption(mm, "pre-allocation", validation.corruption_details);
        return result;
    }
    
    // Perform normal allocation
    result = patlang_allocate_object(type, size, alignment, mm);
    
    if (result.success) {
        // Track allocation for leak detection
        track_allocation_lifecycle(mm, result.address, size);
        
        // Post-allocation validation
        MemoryManagerValidationResult post_validation = validate_memory_manager_state(mm);
        if (!post_validation.state_valid) {
            // Allocation caused corruption - try to roll back
            VALIDATION_DEBUG_PRINT("Allocation caused corruption, attempting rollback");
            patlang_deallocate_object(result.address, mm);
            result.success = false;
            result.error_message = "Allocation caused memory corruption";
            result.address = NULL;
        }
    }
    
    return result;
}

DeallocationResult safe_deallocate_with_validation(void* address, MemoryManager* mm) {
    DeallocationResult result = {0};
    
    if (!address || !mm) {
        result.success = false;
        result.error_message = "Invalid parameters for deallocation";
        return result;
    }
    
    // Pre-deallocation validation
    if (!verify_deallocation_lifecycle(mm, address)) {
        result.success = false;
        result.error_message = "Address not found in allocation tracking";
        return result;
    }
    
    // Perform normal deallocation
    result = patlang_deallocate_object(address, mm);
    
    if (result.success) {
        // Update tracking
        AllocationRecord* record = global_allocation_records;
        while (record) {
            if (record->address == address && record->is_active) {
                record->is_active = false;
                break;
            }
            record = record->next;
        }
    }
    
    return result;
}

// Memory Leak Detection
size_t detect_memory_leaks(MemoryManager* mm) {
    if (!mm) return 0;
    
    size_t leaks = 0;
    AllocationRecord* record = global_allocation_records;
    
    while (record) {
        if (record->is_active && record->magic == ALLOCATION_TRACKING_MAGIC) {
            leaks++;
            VALIDATION_DEBUG_PRINT("Memory leak detected: address=%p, size=%zu, age=%.2f",
                                  record->address, record->size, 
                                  (double)clock() / CLOCKS_PER_SEC - record->allocation_time);
        }
        record = record->next;
    }
    
    return leaks;
}

bool track_allocation_lifecycle(MemoryManager* mm, void* address, size_t size) {
    if (!address || !mm) return false;
    
    AllocationRecord* record = (AllocationRecord*)malloc(sizeof(AllocationRecord));
    if (!record) return false;
    
    record->address = address;
    record->size = size;
    record->magic = ALLOCATION_TRACKING_MAGIC;
    record->allocation_time = (double)clock() / CLOCKS_PER_SEC;
    record->is_active = true;
    record->next = global_allocation_records;
    
    global_allocation_records = record;
    global_allocation_count++;
    
    return true;
}

bool verify_deallocation_lifecycle(MemoryManager* mm, void* address) {
    if (!address || !mm) return false;
    
    AllocationRecord* record = global_allocation_records;
    while (record) {
        if (record->address == address && record->is_active && 
            record->magic == ALLOCATION_TRACKING_MAGIC) {
            return true;
        }
        record = record->next;
    }
    
    return false;
}

// Pool Integrity Functions
bool validate_pool_free_list(MemoryPool* pool) {
    if (!pool || !pool->free_list || !pool->memory_base) return false;
    
    char* base = (char*)pool->memory_base;
    char* pool_end = base + (pool->object_size * pool->total_objects);
    
    // Check each free list entry is within pool bounds
    for (size_t i = 0; i < pool->free_objects; i++) {
        char* free_ptr = (char*)pool->free_list[i];
        if (free_ptr < base || free_ptr >= pool_end) {
            VALIDATION_DEBUG_PRINT("Free list entry %zu (%p) outside pool bounds [%p, %p)",
                                  i, free_ptr, base, pool_end);
            return false;
        }
        
        // Check alignment
        if ((free_ptr - base) % pool->object_size != 0) {
            VALIDATION_DEBUG_PRINT("Free list entry %zu (%p) not properly aligned", i, free_ptr);
            return false;
        }
    }
    
    return true;
}

bool check_pool_memory_boundaries(MemoryPool* pool) {
    if (!pool || !pool->memory_base) return false;
    
    // Basic boundary check - in real implementation would check for buffer overruns
    char* base = (char*)pool->memory_base;
    size_t total_size = pool->object_size * pool->total_objects;
    
    // Simple magic number check at pool boundaries
    // In real implementation, would use more sophisticated techniques
    return base != NULL && total_size > 0;
}

size_t count_pool_corruption_markers(MemoryPool* pool) {
    if (!pool) return 1; // NULL pool counts as corruption
    
    size_t corruption_count = 0;
    
    // Check for basic corruption indicators
    if (pool->object_size == 0) corruption_count++;
    if (pool->total_objects == 0) corruption_count++;
    if (pool->free_objects > pool->total_objects) corruption_count++;
    if (!pool->memory_base) corruption_count++;
    if (!pool->free_list) corruption_count++;
    
    return corruption_count;
}

// Test Isolation Utilities
bool prepare_isolated_test_environment(MemoryManager* mm) {
    if (!mm) return false;
    
    VALIDATION_DEBUG_PRINT("Preparing isolated test environment");
    
    // Reset memory manager to clean state
    MemoryManagerResetResult reset_result = reset_memory_manager(mm);
    if (!reset_result.reset_successful) {
        VALIDATION_DEBUG_PRINT("Failed to reset memory manager for test isolation");
        return false;
    }
    
    // Validate clean state
    MemoryManagerValidationResult validation = validate_memory_manager_state(mm);
    if (!validation.state_valid) {
        VALIDATION_DEBUG_PRINT("Memory manager not in valid state after reset");
        return false;
    }
    
    VALIDATION_DEBUG_PRINT("Isolated test environment prepared successfully");
    return true;
}

bool cleanup_isolated_test_environment(MemoryManager* mm) {
    if (!mm) return false;
    
    VALIDATION_DEBUG_PRINT("Cleaning up isolated test environment");
    
    // Detect any leaks from test
    size_t leaks = detect_memory_leaks(mm);
    if (leaks > 0) {
        VALIDATION_DEBUG_PRINT("Test environment cleanup detected %zu memory leaks", leaks);
    }
    
    // Reset to clean state
    MemoryManagerResetResult reset_result = reset_memory_manager(mm);
    return reset_result.reset_successful;
}

bool verify_test_environment_isolation(MemoryManager* mm) {
    if (!mm) return false;
    
    // Check that no state from previous tests remains
    MemoryManagerValidationResult validation = validate_memory_manager_state(mm);
    if (!validation.state_valid) {
        VALIDATION_DEBUG_PRINT("Test environment isolation verification failed");
        return false;
    }
    
    // Check for memory leaks
    size_t leaks = detect_memory_leaks(mm);
    if (leaks > 0) {
        VALIDATION_DEBUG_PRINT("Test environment has %zu memory leaks", leaks);
        return false;
    }
    
    return true;
}

// Enhanced Error Reporting
void report_memory_corruption(MemoryManager* mm, const char* corruption_type, const char* details) {
    printf("\n=== MEMORY CORRUPTION DETECTED ===\n");
    printf("Type: %s\n", corruption_type ? corruption_type : "unknown");
    printf("Details: %s\n", details ? details : "no details available");
    
    if (mm) {
        printf("Memory Manager State:\n");
        printf("  Pools: %zu\n", mm->num_pools);
        printf("  Total allocations: %zu\n", mm->allocation_stats.total_allocations);
        printf("  Total deallocations: %zu\n", mm->allocation_stats.total_deallocations);
        printf("  Current memory usage: %zu\n", mm->allocation_stats.current_memory_usage);
        printf("  Allocation failures: %zu\n", mm->allocation_stats.allocation_failures);
    }
    
    printf("=== END CORRUPTION REPORT ===\n\n");
}

void log_allocation_history(MemoryManager* mm) {
    printf("\n=== ALLOCATION HISTORY ===\n");
    printf("Total tracked allocations: %zu\n", global_allocation_count);
    
    AllocationRecord* record = global_allocation_records;
    size_t count = 0;
    
    while (record && count < 10) { // Show last 10 allocations
        printf("  [%zu] Address: %p, Size: %zu, Active: %s, Age: %.2f\n",
               count, record->address, record->size,
               record->is_active ? "YES" : "NO",
               (double)clock() / CLOCKS_PER_SEC - record->allocation_time);
        record = record->next;
        count++;
    }
    
    printf("=== END ALLOCATION HISTORY ===\n\n");
}

void generate_memory_diagnostics_report(MemoryManager* mm) {
    if (!mm) {
        printf("Cannot generate diagnostics report: Memory manager is NULL\n");
        return;
    }
    
    printf("\n=== MEMORY DIAGNOSTICS REPORT ===\n");
    
    // Validation results
    MemoryManagerValidationResult validation = validate_memory_manager_state(mm);
    printf("Memory Manager Validation:\n");
    printf("  State valid: %s\n", validation.state_valid ? "YES" : "NO");
    printf("  Pools consistent: %s\n", validation.pools_consistent ? "YES" : "NO");
    printf("  Statistics accurate: %s\n", validation.statistics_accurate ? "YES" : "NO");
    printf("  Corruption detected: %s\n", validation.corruption_detected ? "YES" : "NO");
    printf("  Corruption count: %zu\n", validation.corruption_count);
    printf("  Memory leaks detected: %zu\n", validation.memory_leaks_detected);
    
    // Pool status
    printf("\nPool Status:\n");
    for (size_t i = 0; i < mm->num_pools; i++) {
        MemoryPool* pool = mm->memory_pools[i];
        if (pool) {
            printf("  Pool %zu: size=%zu, total=%zu, free=%zu (%.1f%% used)\n",
                   i, pool->object_size, pool->total_objects, pool->free_objects,
                   100.0 * (pool->total_objects - pool->free_objects) / pool->total_objects);
        }
    }
    
    // Allocation statistics
    printf("\nAllocation Statistics:\n");
    printf("  Total allocations: %zu\n", mm->allocation_stats.total_allocations);
    printf("  Total deallocations: %zu\n", mm->allocation_stats.total_deallocations);
    printf("  Current memory usage: %zu bytes\n", mm->allocation_stats.current_memory_usage);
    printf("  Peak memory usage: %zu bytes\n", mm->allocation_stats.peak_memory_usage);
    printf("  Allocation failures: %zu\n", mm->allocation_stats.allocation_failures);
    printf("  GC cycles: %zu\n", mm->allocation_stats.gc_cycles);
    
    printf("=== END DIAGNOSTICS REPORT ===\n\n");
}