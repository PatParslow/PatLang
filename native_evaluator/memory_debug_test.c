// Memory debugging test to identify the specific free() issue
#include "transpiled/phase2_advanced_goal_system.h"
#include "transpiled/transpiled_memory_manager.h"
#include <stdio.h>
#include <stdlib.h>

int main() {
    printf("=== Memory Debug Test ===\n");
    
    // Initialize memory manager
    MemoryManager* mm = patlang_create_memory_manager(1024 * 1024);
    if (!mm) {
        printf("Failed to create memory manager\n");
        return 1;
    }
    
    printf("✓ Memory manager created\n");
    
    // Create a constraint (this should work)
    printf("Creating constraint...\n");
    Constraint* constraint = create_constraint(CONSTRAINT_TYPE_PRECONDITION, NULL, 
                                             "test constraint", mm);
    
    if (constraint) {
        printf("✓ Constraint created successfully\n");
        printf("  Description address: %p\n", constraint->description);
        printf("  Constraint address: %p\n", constraint);
        
        // This is where the crash happens
        printf("Destroying constraint...\n");
        destroy_constraint(constraint);  // This should crash with "free(): invalid pointer"
        printf("✓ Constraint destroyed\n");
    } else {
        printf("✗ Failed to create constraint\n");
    }
    
    patlang_destroy_memory_manager(mm);
    printf("=== Memory Debug Test Complete ===\n");
    
    return 0;
}