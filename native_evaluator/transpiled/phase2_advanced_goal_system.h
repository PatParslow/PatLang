#ifndef PHASE2_ADVANCED_GOAL_SYSTEM_H
#define PHASE2_ADVANCED_GOAL_SYSTEM_H

#include "transpiled_core_evaluator.h"
#include "transpiled_memory_manager.h"
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Advanced Goal Construct Types
typedef enum {
    GOAL_TYPE_SIMPLE,
    GOAL_TYPE_CONSTRAINT,
    GOAL_TYPE_DEPENDENT,
    GOAL_TYPE_DYNAMIC,
    GOAL_TYPE_BACKTRACKING
} GoalType;

typedef enum {
    CONSTRAINT_TYPE_PRECONDITION,
    CONSTRAINT_TYPE_POSTCONDITION,
    CONSTRAINT_TYPE_INVARIANT,
    CONSTRAINT_TYPE_TEMPORAL,
    CONSTRAINT_TYPE_RESOURCE
} ConstraintType;

typedef enum {
    GOAL_STATUS_PENDING,
    GOAL_STATUS_EVALUATING,
    GOAL_STATUS_SATISFIED,
    GOAL_STATUS_FAILED,
    GOAL_STATUS_BACKTRACKING,
    GOAL_STATUS_CACHED
} GoalStatus;

// Advanced Goal Structures
typedef struct Constraint {
    ConstraintType type;
    ast_node_t* expression;
    char* description;
    double priority;
    bool mandatory;
    MemoryManager* memory_manager;
    struct Constraint* next;
} Constraint;

typedef struct GoalDependency {
    struct AdvancedGoal* target_goal;
    bool required;
    double weight;
    struct GoalDependency* next;
} GoalDependency;

typedef struct AdvancedGoal {
    GoalType type;
    GoalStatus status;
    char* identifier;
    ast_node_t* goal_expression;
    Constraint* preconditions;
    Constraint* postconditions;
    GoalDependency* dependencies;
    PaTLangResult cached_result;
    double evaluation_time;
    size_t evaluation_count;
    double priority;
    MemoryManager* memory_manager;
    struct AdvancedGoal* next;
} AdvancedGoal;

typedef struct ConstraintSolver {
    AdvancedGoal** goal_stack;
    size_t stack_depth;
    size_t max_stack_depth;
    bool backtracking_enabled;
    size_t max_backtrack_depth;
    size_t constraint_violations;
    double solver_timeout;
    MemoryManager* memory_manager;
} ConstraintSolver;

typedef struct GoalEvaluationContext {
    EvaluatorContext* base_context;
    ConstraintSolver* solver;
    AdvancedGoal* current_goal;
    size_t recursion_depth;
    bool constraint_checking_enabled;
    bool caching_enabled;
    bool dependency_resolution_enabled;
    MemoryManager* memory_manager;
} GoalEvaluationContext;

// Advanced Goal Result Structures
typedef struct ConstraintResult {
    bool satisfied;
    bool violated;
    double satisfaction_degree;
    char* violation_reason;
    Constraint* failed_constraint;
    double evaluation_time;
} ConstraintResult;

typedef struct GoalResult {
    bool success;
    bool goal_satisfied;
    PaTLangResult value;
    ConstraintResult constraint_result;
    size_t dependencies_resolved;
    size_t backtrack_steps;
    double total_evaluation_time;
    char* error_message;
    GoalStatus final_status;
} GoalResult;

// Main Advanced Goal System Functions
ConstraintSolver* create_constraint_solver(size_t max_stack_depth, MemoryManager* mm);
void destroy_constraint_solver(ConstraintSolver* solver);

GoalEvaluationContext* create_goal_evaluation_context(EvaluatorContext* base_ctx, MemoryManager* mm);
void destroy_goal_evaluation_context(GoalEvaluationContext* ctx);

// Advanced Goal Creation and Management
AdvancedGoal* create_advanced_goal(GoalType type, const char* identifier, ast_node_t* expression, MemoryManager* mm);
void destroy_advanced_goal(AdvancedGoal* goal);

Constraint* create_constraint(ConstraintType type, ast_node_t* expression, const char* description, MemoryManager* mm);
void destroy_constraint(Constraint* constraint);

// Goal Evaluation Functions
GoalResult evaluate_advanced_goal(AdvancedGoal* goal, GoalEvaluationContext* ctx);
GoalResult evaluate_goal_with_constraints(AdvancedGoal* goal, GoalEvaluationContext* ctx);
GoalResult evaluate_dependent_goal(AdvancedGoal* goal, GoalEvaluationContext* ctx);

// Constraint Solving Functions
ConstraintResult evaluate_constraint(Constraint* constraint, GoalEvaluationContext* ctx);
ConstraintResult validate_preconditions(AdvancedGoal* goal, GoalEvaluationContext* ctx);
ConstraintResult validate_postconditions(AdvancedGoal* goal, PaTLangResult* result, GoalEvaluationContext* ctx);

// Dependency Resolution Functions
bool resolve_goal_dependencies(AdvancedGoal* goal, GoalEvaluationContext* ctx);
bool check_circular_dependencies(AdvancedGoal* goal, GoalEvaluationContext* ctx);
GoalResult evaluate_dependency_chain(AdvancedGoal* root_goal, GoalEvaluationContext* ctx);

// Goal Caching and Optimization
bool cache_goal_result(AdvancedGoal* goal, GoalResult* result, GoalEvaluationContext* ctx);
GoalResult* lookup_cached_goal_result(AdvancedGoal* goal, GoalEvaluationContext* ctx);
void invalidate_goal_cache(AdvancedGoal* goal, GoalEvaluationContext* ctx);

// Backtracking and Alternative Solution Finding
GoalResult backtrack_goal_evaluation(AdvancedGoal* goal, GoalEvaluationContext* ctx);
bool has_alternative_solutions(AdvancedGoal* goal, GoalEvaluationContext* ctx);
GoalResult find_alternative_solution(AdvancedGoal* goal, GoalEvaluationContext* ctx);

// Performance and Statistics Functions
void update_goal_statistics(AdvancedGoal* goal, GoalResult* result);
double calculate_goal_complexity(AdvancedGoal* goal);
size_t count_goal_dependencies(AdvancedGoal* goal);

#ifdef __cplusplus
}
#endif

#endif // PHASE2_ADVANCED_GOAL_SYSTEM_H