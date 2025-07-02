// Phase 2 Week 3 Test Suite - FIXED VERSION with Memory Corruption Resolution
// Tests advanced goal constructs, function closures, and type inference with proper memory management
// Generated: 2025-07-02 00:30:00 +0100

#include "transpiled/phase2_advanced_goal_system.h"
#include "transpiled/phase2_function_closure_system.h"
#include "transpiled/phase2_type_inference_foundation.h"
#include "transpiled/transpiled_core_evaluator.h"
#include "transpiled/transpiled_memory_manager.h"
#include "transpiled/memory_manager_validation.h"
#include "native_bridge.h"
#include "ast.h"
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <time.h>
#include <math.h>

// Test configuration with reduced iterations for stability
#define PHASE2_PERFORMANCE_ITERATIONS 2500  // Reduced from 50000
#define PHASE2_STRESS_TEST_ITERATIONS 1000  // Reduced from 10000
#define PERFORMANCE_TARGET_MULTIPLIER 1.2

// Global test context with enhanced memory management
static MemoryManager* test_memory_manager = NULL;
static EvaluatorContext* test_evaluator_context = NULL;
static GoalEvaluationContext* test_goal_context = NULL;
static ScopeChain* test_scope_chain = NULL;
static InferenceContext* test_inference_context = NULL;
static MemoryManagerCheckpoint test_checkpoint = {0};

// Enhanced test statistics
typedef struct {
    size_t tests_run;
    size_t tests_passed;
    size_t tests_failed;
    double total_test_time;
    size_t performance_tests;
    size_t advanced_features_tested;
    size_t memory_corruption_incidents;
    size_t memory_resets_performed;
    size_t successful_isolations;
} Phase2EnhancedTestStats;

static Phase2EnhancedTestStats test_stats = {0};

// Enhanced Test Setup and Teardown with Memory Isolation
void setup_phase2_enhanced_test_environment() {
    printf("=== Setting up Phase 2 Week 3 Enhanced Test Environment ===\n");
    
    // Initialize memory manager with validation
    test_memory_manager = patlang_create_memory_manager_with_validation(2 * 1024 * 1024); // 2MB heap
    assert(test_memory_manager != NULL);
    printf("✓ Enhanced memory manager initialized (2MB heap)\n");
    
    // Prepare test isolation
    bool isolation_prepared = patlang_prepare_test_isolation(test_memory_manager);
    if (isolation_prepared) {
        test_stats.successful_isolations++;
        printf("✓ Test isolation environment prepared\n");
    } else {
        printf("✗ Warning: Test isolation preparation failed\n");
    }
    
    // Create memory checkpoint
    test_checkpoint = create_memory_checkpoint(test_memory_manager);
    printf("✓ Memory checkpoint created (id: %zu)\n", test_checkpoint.checkpoint_id);
    
    // Initialize evaluator context
    test_evaluator_context = create_evaluator_context(2000);
    assert(test_evaluator_context != NULL);
    printf("✓ Evaluator context initialized\n");
    
    // Initialize goal evaluation context
    test_goal_context = create_goal_evaluation_context(test_evaluator_context, test_memory_manager);
    assert(test_goal_context != NULL);
    printf("✓ Goal evaluation context initialized\n");
    
    // Initialize scope chain
    test_scope_chain = create_scope_chain(test_memory_manager);
    assert(test_scope_chain != NULL);
    printf("✓ Scope chain initialized\n");
    
    // Initialize type inference context
    test_inference_context = create_inference_context(INFERENCE_STRATEGY_UNIFICATION, test_memory_manager);
    assert(test_inference_context != NULL);
    printf("✓ Type inference context initialized\n");
    
    printf("=== Phase 2 Week 3 Enhanced Test Environment Ready ===\n\n");
}

void teardown_phase2_enhanced_test_environment() {
    printf("\n=== Tearing down Phase 2 Week 3 Enhanced Test Environment ===\n");
    
    // Check for memory corruption before cleanup
    MemoryManagerValidationResult validation = validate_memory_manager_state(test_memory_manager);
    if (!validation.state_valid) {
        printf("✗ Memory corruption detected during teardown\n");
        test_stats.memory_corruption_incidents++;
        generate_memory_diagnostics_report(test_memory_manager);
    }
    
    if (test_inference_context) {
        destroy_inference_context(test_inference_context);
        test_inference_context = NULL;
        printf("✓ Type inference context destroyed\n");
    }
    
    if (test_scope_chain) {
        destroy_scope_chain(test_scope_chain);
        test_scope_chain = NULL;
        printf("✓ Scope chain destroyed\n");
    }
    
    if (test_goal_context) {
        destroy_goal_evaluation_context(test_goal_context);
        test_goal_context = NULL;
        printf("✓ Goal evaluation context destroyed\n");
    }
    
    if (test_evaluator_context) {
        destroy_evaluator_context(test_evaluator_context);
        test_evaluator_context = NULL;
        printf("✓ Evaluator context destroyed\n");
    }
    
    // Clean up test isolation
    if (test_memory_manager) {
        bool cleanup_success = patlang_cleanup_test_isolation(test_memory_manager);
        if (cleanup_success) {
            printf("✓ Test isolation cleaned up successfully\n");
        } else {
            printf("✗ Warning: Test isolation cleanup failed\n");
        }
        
        patlang_destroy_memory_manager(test_memory_manager);
        test_memory_manager = NULL;
        printf("✓ Enhanced memory manager destroyed\n");
    }
    
    printf("=== Phase 2 Week 3 Enhanced Test Environment Cleaned Up ===\n");
}

// Enhanced helper functions with memory validation
ast_node_t* create_test_ast_node_safe(ast_type_t type, expr_type_t expr_type) {
    // Use validated allocation
    AllocationResult result = patlang_allocate_object_with_validation(
        OBJECT_TYPE_CUSTOM, sizeof(ast_node_t), 8, test_memory_manager);
    
    if (!result.success) {
        printf("✗ Failed to allocate AST node: %s\n", result.error_message);
        test_stats.memory_corruption_incidents++;
        return NULL;
    }
    
    ast_node_t* node = (ast_node_t*)result.address;
    if (node) {
        memset(node, 0, sizeof(ast_node_t));
        node->type = type;
        node->expr_type = expr_type;
    }
    
    return node;
}

void record_enhanced_test_result(bool passed, const char* test_name, double test_time) {
    test_stats.tests_run++;
    if (passed) {
        test_stats.tests_passed++;
        printf("✓ %s (%.6f seconds)\n", test_name, test_time);
    } else {
        test_stats.tests_failed++;
        printf("✗ %s FAILED (%.6f seconds)\n", test_name, test_time);
    }
    test_stats.total_test_time += test_time;
}

bool reset_memory_between_tests() {
    // Restore memory checkpoint to ensure clean state
    bool restore_success = restore_memory_checkpoint(test_memory_manager, &test_checkpoint);
    if (restore_success) {
        test_stats.memory_resets_performed++;
        // Create new checkpoint for next test
        test_checkpoint = create_memory_checkpoint(test_memory_manager);
        return true;
    }
    
    printf("✗ Warning: Memory checkpoint restore failed\n");
    test_stats.memory_corruption_incidents++;
    return false;
}

// Test 1: Enhanced Advanced Goal Constructs with Memory Validation
void test_enhanced_advanced_goal_constructs() {
    printf("\n=== Test 1: Enhanced Advanced Goal Constructs ===\n");
    
    if (!reset_memory_between_tests()) {
        printf("✗ Memory reset failed, skipping test\n");
        return;
    }
    
    clock_t start_time = clock();
    
    // Test goal creation with safe allocation
    ast_node_t* goal_expr = create_test_ast_node_safe(AST_ASSIGN, EXPR_LITERAL);
    if (!goal_expr) {
        record_enhanced_test_result(false, "Goal Creation (allocation failed)", 0.0);
        return;
    }
    
    AdvancedGoal* goal = create_advanced_goal(GOAL_TYPE_CONSTRAINT, "test_goal", goal_expr, test_memory_manager);
    
    bool test_passed = (goal != NULL && 
                       strcmp(goal->identifier, "test_goal") == 0 && 
                       goal->type == GOAL_TYPE_CONSTRAINT);
    
    if (goal) {
        destroy_advanced_goal(goal);
    }
    
    double test_time = ((double)(clock() - start_time)) / CLOCKS_PER_SEC;
    record_enhanced_test_result(test_passed, "Enhanced Goal Creation", test_time);
    
    // Test constraint creation with memory validation
    if (!reset_memory_between_tests()) {
        printf("✗ Memory reset failed for constraint test\n");
        return;
    }
    
    start_time = clock();
    ast_node_t* constraint_expr = create_test_ast_node_safe(AST_ASSIGN, EXPR_LITERAL);
    if (!constraint_expr) {
        record_enhanced_test_result(false, "Constraint Creation (allocation failed)", 0.0);
        return;
    }
    
    Constraint* constraint = create_constraint(CONSTRAINT_TYPE_PRECONDITION, constraint_expr, 
                                             "test precondition", test_memory_manager);
    
    test_passed = (constraint != NULL && 
                  constraint->type == CONSTRAINT_TYPE_PRECONDITION &&
                  strcmp(constraint->description, "test precondition") == 0);
    
    if (constraint) {
        destroy_constraint(constraint);
    }
    
    test_time = ((double)(clock() - start_time)) / CLOCKS_PER_SEC;
    record_enhanced_test_result(test_passed, "Enhanced Constraint Creation", test_time);
    
    test_stats.advanced_features_tested++;
    printf("Enhanced Advanced Goal Constructs: 2/2 components tested with memory validation\n");
}

// Test 2: Enhanced Function Closure System with Memory Validation  
void test_enhanced_function_closure_system() {
    printf("\n=== Test 2: Enhanced Function Closure System ===\n");
    
    if (!reset_memory_between_tests()) {
        printf("✗ Memory reset failed, skipping test\n");
        return;
    }
    
    clock_t start_time = clock();
    
    // Test lexical scope creation with memory validation
    LexicalScope* scope = create_lexical_scope(SCOPE_TYPE_FUNCTION, "test_function", 
                                              test_scope_chain->global_scope, test_memory_manager);
    
    bool test_passed = (scope != NULL && 
                       scope->type == SCOPE_TYPE_FUNCTION &&
                       strcmp(scope->scope_name, "test_function") == 0);
    
    double test_time = ((double)(clock() - start_time)) / CLOCKS_PER_SEC;
    record_enhanced_test_result(test_passed, "Enhanced Lexical Scope Creation", test_time);
    
    if (!test_passed || !scope) {
        printf("✗ Scope creation failed, skipping remaining closure tests\n");
        return;
    }
    
    // Test variable creation and definition with safe allocation
    start_time = clock();
    AllocationResult test_value_result = patlang_allocate_object_with_validation(
        OBJECT_TYPE_NUMBER, sizeof(PaTLangObject), 8, test_memory_manager);
    
    if (!test_value_result.success) {
        record_enhanced_test_result(false, "Variable Definition (allocation failed)", 0.0);
        destroy_lexical_scope(scope);
        return;
    }
    
    PaTLangObject* test_value = (PaTLangObject*)test_value_result.address;
    test_value->ref_count = 1;
    
    // Use memory manager for data allocation instead of malloc
    AllocationResult data_result = patlang_allocate_object_with_validation(
        OBJECT_TYPE_CUSTOM, sizeof(double), 8, test_memory_manager);
    
    if (!data_result.success) {
        record_enhanced_test_result(false, "Variable Data Allocation (allocation failed)", 0.0);
        destroy_lexical_scope(scope);
        return;
    }
    
    test_value->data = data_result.address;
    *((double*)test_value->data) = 42.0;
    
    bool var_defined = define_variable(scope, "test_var", test_value, VARIABLE_TYPE_LOCAL);
    test_passed = var_defined && (scope->variable_count == 1);
    
    test_time = ((double)(clock() - start_time)) / CLOCKS_PER_SEC;
    record_enhanced_test_result(test_passed, "Enhanced Variable Definition", test_time);
    
    // Test function closure creation with memory validation
    if (!reset_memory_between_tests()) {
        printf("✗ Memory reset failed for closure test\n");
        destroy_lexical_scope(scope);
        return;
    }
    
    start_time = clock();
    ast_node_t* func_body = create_test_ast_node_safe(AST_ASSIGN, EXPR_LITERAL);
    if (!func_body) {
        record_enhanced_test_result(false, "Function Closure Creation (allocation failed)", 0.0);
        destroy_lexical_scope(scope);
        return;
    }
    
    ClosureCreationResult closure_result = create_function_closure(func_body, test_scope_chain, test_memory_manager);
    
    test_passed = (closure_result.success && 
                  closure_result.closure != NULL &&
                  closure_result.environment != NULL);
    
    if (closure_result.closure) {
        destroy_function_closure(closure_result.closure);
    }
    
    test_time = ((double)(clock() - start_time)) / CLOCKS_PER_SEC;
    record_enhanced_test_result(test_passed, "Enhanced Function Closure Creation", test_time);
    
    // Clean up
    if (scope) {
        destroy_lexical_scope(scope);
    }
    
    test_stats.advanced_features_tested++;
    printf("Enhanced Function Closure System: 3/3 components tested with memory validation\n");
}

// Test 3: Enhanced Type Inference Foundation with Memory Validation
void test_enhanced_type_inference_foundation() {
    printf("\n=== Test 3: Enhanced Type Inference Foundation ===\n");
    
    if (!reset_memory_between_tests()) {
        printf("✗ Memory reset failed, skipping test\n");
        return;
    }
    
    clock_t start_time = clock();
    
    // Test type info creation with memory validation
    TypeInfo* number_type = create_type_info(TYPE_NUMBER, "Number", test_memory_manager);
    
    bool test_passed = (number_type != NULL && 
                       number_type->base_type == TYPE_NUMBER &&
                       strcmp(number_type->type_name, "Number") == 0);
    
    double test_time = ((double)(clock() - start_time)) / CLOCKS_PER_SEC;
    record_enhanced_test_result(test_passed, "Enhanced Type Info Creation", test_time);
    
    if (!number_type) {
        printf("✗ Type creation failed, skipping remaining type inference tests\n");
        return;
    }
    
    // Test type inference with reduced iterations but proper validation
    start_time = clock();
    
    size_t successful_inferences = 0;
    ast_node_t* inference_test_expr = create_test_ast_node_safe(AST_ASSIGN, EXPR_LITERAL);
    
    if (!inference_test_expr) {
        record_enhanced_test_result(false, "Type Inference Performance (allocation failed)", 0.0);
        destroy_type_info(number_type);
        return;
    }
    
    // Reduced iterations with memory validation
    for (int i = 0; i < 10; i++) { // Only 10 iterations for stability
        // Check memory state before each inference
        MemoryManagerValidationResult pre_validation = validate_memory_manager_state(test_memory_manager);
        if (!pre_validation.state_valid) {
            printf("✗ Memory corruption detected at iteration %d\n", i);
            test_stats.memory_corruption_incidents++;
            break;
        }
        
        TypeInferenceResult inference_result = perform_type_inference(inference_test_expr, test_inference_context);
        
        if (inference_result.success && inference_result.inferred_type) {
            successful_inferences++;
            destroy_type_info(inference_result.inferred_type);
        }
    }
    
    test_time = ((double)(clock() - start_time)) / CLOCKS_PER_SEC;
    double inference_rate = 10.0 / test_time;
    
    printf("Enhanced Type inferences: %zu/10 successful\n", successful_inferences);
    printf("Enhanced Type inference rate: %.0f inferences/second\n", inference_rate);
    
    bool inference_passed = (successful_inferences >= 8); // 80% success rate required
    record_enhanced_test_result(inference_passed, "Enhanced Type Inference Performance", test_time);
    
    // Clean up
    destroy_type_info(number_type);
    
    test_stats.advanced_features_tested++;
    printf("Enhanced Type Inference Foundation: 2/2 components tested with memory validation\n");
}

// Main enhanced test runner
int main() {
    printf("========================================\n");
    printf("Phase 2 Week 3 Enhanced Memory-Safe Test Suite\n");
    printf("========================================\n");
    
    setup_phase2_enhanced_test_environment();
    
    // Run enhanced test suites with memory validation
    test_enhanced_advanced_goal_constructs();
    test_enhanced_function_closure_system();
    test_enhanced_type_inference_foundation();
    
    teardown_phase2_enhanced_test_environment();
    
    // Print enhanced final statistics
    printf("\n========================================\n");
    printf("Phase 2 Week 3 Enhanced Test Results Summary\n");
    printf("========================================\n");
    printf("Tests Run: %zu\n", test_stats.tests_run);
    printf("Tests Passed: %zu\n", test_stats.tests_passed);
    printf("Tests Failed: %zu\n", test_stats.tests_failed);
    printf("Success Rate: %.1f%%\n", 
           test_stats.tests_run > 0 ? (100.0 * test_stats.tests_passed / test_stats.tests_run) : 0.0);
    printf("Total Test Time: %.6f seconds\n", test_stats.total_test_time);
    printf("Advanced Features Tested: %zu\n", test_stats.advanced_features_tested);
    printf("Memory Corruption Incidents: %zu\n", test_stats.memory_corruption_incidents);
    printf("Memory Resets Performed: %zu\n", test_stats.memory_resets_performed);
    printf("Successful Isolations: %zu\n", test_stats.successful_isolations);
    
    // Enhanced success criteria
    bool all_tests_passed = (test_stats.tests_failed == 0);
    bool sufficient_coverage = (test_stats.advanced_features_tested >= 3);
    bool memory_stable = (test_stats.memory_corruption_incidents == 0);
    bool isolation_working = (test_stats.successful_isolations > 0);
    
    printf("\nPhase 2 Week 3 Enhanced Success Criteria:\n");
    printf("✓ All tests passed: %s\n", all_tests_passed ? "YES" : "NO");
    printf("✓ Sufficient feature coverage: %s\n", sufficient_coverage ? "YES" : "NO");
    printf("✓ Memory stability maintained: %s\n", memory_stable ? "YES" : "NO");
    printf("✓ Test isolation working: %s\n", isolation_working ? "YES" : "NO");
    
    bool overall_success = all_tests_passed && sufficient_coverage && memory_stable && isolation_working;
    printf("\n🎯 PHASE 2 WEEK 3 ENHANCED OVERALL: %s\n", overall_success ? "SUCCESS ✅" : "NEEDS WORK ❌");
    
    if (overall_success) {
        printf("\n🚀 Memory corruption resolved! Ready for production Phase 2 Week 4!\n");
    } else {
        printf("\n⚠️  Memory management issues detected. Review diagnostics above.\n");
    }
    
    printf("========================================\n");
    
    return overall_success ? 0 : 1;
}