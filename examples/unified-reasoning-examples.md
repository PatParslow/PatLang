# Unified Reasoning Examples

## Overview

This document provides concrete examples demonstrating how Patlang's unified reasoning systems (Type Inference, Goal-Oriented Programming, and Logic Programming) work together in practical programming scenarios. Each example shows the synergy between paradigms and their integration with the existing object-oriented foundation.

## Example 1: Smart Form Validation

### Problem Statement

Create a user registration form that validates input using type constraints, business logic rules, and goal-oriented error recovery.

### Implementation

```patlang
# Type definitions for user data
constrain User :: Object {
  username :: String where length >= 3 and length <= 20,
  email :: String where matches /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
  age :: Number where age >= 13 and age <= 120,
  password :: String where length >= 8
}

# Logic rules for business validation
rule valid_username(Username) if
  Username matches /^[a-zA-Z0-9_]+$/ and
  not_exists ?- reserved_username(Username)

rule strong_password(Password) if
  Password matches /[A-Z]/ and          # Has uppercase
  Password matches /[a-z]/ and          # Has lowercase  
  Password matches /[0-9]/ and          # Has number
  Password matches /[!@#$%^&*]/ and     # Has special char
  length(Password) >= 8

rule eligible_user(User) if
  valid_username(User.username) and
  User.age >= 13 and
  strong_password(User.password)

# Reserved usernames fact base
fact reserved_username("admin")
fact reserved_username("root")
fact reserved_username("system")

# Goal for user registration with error recovery
goal register_user(form_data) {
  precondition: form_data :: Object
  postcondition: result :: User and eligible_user(result)
  
  strategy: validate_and_register
  failure_handler: provide_helpful_errors
}

# Main registration function
function process_registration(form_input) {
  # Enable all reasoning systems
  enable_reasoning_mode()
  
  try {
    # Goal pursuit with automatic type validation
    user = pursue register_user(form_input)
    
    # Success: user meets all constraints
    return {
      success: true,
      user: user,
      message: "Registration successful!"
    }
    
  } catch ValidationError(violations) {
    # Goal failed: provide specific error guidance
    return {
      success: false,
      errors: violations,
      suggestions: generate_suggestions(violations)
    }
  }
}

# Goal strategy implementation
strategy validate_and_register(goal, context) {
  form_data = goal.arguments[0]
  
  # Step 1: Type validation with constraint checking
  try {
    typed_user = form_data as User
  } catch TypeConstraintViolation(field, constraint, value) {
    fail ValidationError([{
      field: field,
      message: "Invalid #{field}: #{constraint} violation",
      value: value
    }])
  }
  
  # Step 2: Business logic validation
  violations = []
  
  if not query ?- valid_username(typed_user.username) then
    violations.push({
      field: "username",
      message: "Username invalid or reserved",
      suggestions: ["Try a different username", "Use only letters, numbers, and underscores"]
    })
  end
  
  if not query ?- strong_password(typed_user.password) then
    violations.push({
      field: "password", 
      message: "Password not strong enough",
      suggestions: ["Add uppercase letters", "Add numbers", "Add special characters"]
    })
  end
  
  if violations.length > 0 then
    fail ValidationError(violations)
  end
  
  # Step 3: Final eligibility check
  if query ?- eligible_user(typed_user) then
    # Assert user registration facts
    assert_fact(registered_user(typed_user.username))
    assert_fact(user_email(typed_user.username, typed_user.email))
    
    return typed_user
  else
    fail ValidationError([{
      field: "general",
      message: "User not eligible for registration"
    }])
  end
}

# Usage example
input_data = {
  username: "john_doe",
  email: "john@example.com", 
  age: 25,
  password: "weakpass"
}

result = process_registration(input_data)
if result.success then
  print "Welcome, #{result.user.username}!"
else
  for error in result.errors do
    print "Error in #{error.field}: #{error.message}"
    for suggestion in error.suggestions do
      print "  Suggestion: #{suggestion}"
    end
  end
end
```

### Key Features Demonstrated

1. **Type Constraints**: Structural validation with range and pattern constraints
2. **Logic Rules**: Business logic expressed as declarative rules
3. **Goal-Oriented Recovery**: Intelligent error handling with suggestions
4. **Cross-Paradigm Integration**: Types guide logic, goals coordinate overall flow

## Example 2: Database Query Optimization

### Problem Statement

Create a query optimizer that uses type information to optimize database queries, logic programming to explore optimization strategies, and goals to achieve performance targets.

### Implementation

```patlang
# Type system for database schema
constrain Table :: Object {
  name :: String,
  columns :: List(Column),
  indexes :: List(Index),
  row_count :: Number
}

constrain Column :: Object {
  name :: String,
  type :: DataType,
  nullable :: Boolean,
  indexed :: Boolean
}

constrain Query :: Object {
  select_fields :: List(String),
  from_table :: String,
  where_conditions :: List(Condition),
  joins :: List(Join),
  order_by :: List(OrderClause)
}

# Database schema facts
fact table("users", 1000000)  # 1M rows
fact table("orders", 5000000) # 5M rows  
fact table("products", 10000) # 10K rows

fact column("users", "id", :integer, false, true)     # Primary key
fact column("users", "email", :string, false, true)   # Indexed
fact column("users", "name", :string, false, false)   # Not indexed

fact column("orders", "id", :integer, false, true)
fact column("orders", "user_id", :integer, false, true) # Foreign key
fact column("orders", "total", :decimal, false, false)

fact index("users", "idx_users_email", ["email"])
fact index("orders", "idx_orders_user_id", ["user_id"])

# Logic rules for query optimization
rule can_use_index(Table, Column) if
  column(Table, Column, _, _, true)

rule small_table(Table) if
  table(Table, RowCount) and
  RowCount < 100000

rule expensive_join(Table1, Table2) if
  table(Table1, Count1) and
  table(Table2, Count2) and
  Count1 * Count2 > 10000000

rule optimal_join_order(LeftTable, RightTable) if
  table(LeftTable, LeftCount) and
  table(RightTable, RightCount) and
  LeftCount <= RightCount

# Query optimization strategies
rule index_scan_better_than_table_scan(Table, Column, Selectivity) if
  can_use_index(Table, Column) and
  Selectivity < 0.1

rule hash_join_better_than_nested_loop(Table1, Table2) if
  small_table(Table1) and
  not small_table(Table2)

# Goals for query optimization
goal optimize_query(original_query) {
  precondition: original_query :: Query
  postcondition: result.estimated_cost < original_query.estimated_cost
  
  strategy: multi_strategy_optimization
  timeout: 5000ms
}

goal minimize_query_cost(query_plan) {
  precondition: query_plan :: QueryPlan
  postcondition: result.cost == minimum_possible_cost(query_plan)
  
  strategy: cost_based_optimization
}

# Query optimizer implementation
function optimize_database_query(sql_query) {
  # Parse and type the query
  parsed_query = parse_sql(sql_query) as Query
  
  # Pursue optimization goal
  optimized_plan = pursue optimize_query(parsed_query)
  
  if optimized_plan.success then
    return {
      original_cost: parsed_query.estimated_cost,
      optimized_cost: optimized_plan.result.estimated_cost,
      improvement: calculate_improvement(parsed_query, optimized_plan.result),
      execution_plan: optimized_plan.result
    }
  else
    return {
      error: "Could not optimize query",
      reason: optimized_plan.failure_reason
    }
  end
}

# Multi-strategy optimization
strategy multi_strategy_optimization(goal, context) {
  original_query = goal.arguments[0]
  best_plan = original_query
  
  # Strategy 1: Index optimization
  choice_point {
    index_optimized = pursue optimize_indexes(original_query)
    if index_optimized.success and 
       index_optimized.result.cost < best_plan.cost then
      best_plan = index_optimized.result
    end
  } backtrack_on_failure
  
  # Strategy 2: Join reordering
  choice_point {
    join_optimized = pursue optimize_join_order(best_plan)
    if join_optimized.success and
       join_optimized.result.cost < best_plan.cost then
      best_plan = join_optimized.result
    end
  } backtrack_on_failure
  
  # Strategy 3: Predicate pushdown
  choice_point {
    predicate_optimized = pursue optimize_predicates(best_plan)
    if predicate_optimized.success and
       predicate_optimized.result.cost < best_plan.cost then
      best_plan = predicate_optimized.result
    end
  } backtrack_on_failure
  
  return best_plan
}

# Index optimization goal
goal optimize_indexes(query) {
  strategy: {
    optimized_conditions = []
    
    for condition in query.where_conditions do
      # Use logic system to check if index can be used
      if query ?- can_use_index(condition.table, condition.column) then
        selectivity = estimate_selectivity(condition)
        
        if query ?- index_scan_better_than_table_scan(
          condition.table, condition.column, selectivity) then
          
          optimized_conditions.push(
            condition.with_index_hint(true)
          )
        else
          optimized_conditions.push(condition)
        end
      else
        optimized_conditions.push(condition)
      end
    end
    
    return query.with_conditions(optimized_conditions)
  }
}

# Join optimization goal  
goal optimize_join_order(query) {
  strategy: {
    if query.joins.length <= 1 then
      return query  # No optimization needed
    end
    
    # Find optimal join order using logic rules
    tables = extract_tables(query)
    optimal_order = []
    
    remaining_tables = tables
    while remaining_tables.length > 0 do
      best_next = nil
      
      for table in remaining_tables do
        if optimal_order.empty or 
           query ?- optimal_join_order(optimal_order.last, table) then
          best_next = table
          break
        end
      end
      
      optimal_order.push(best_next || remaining_tables.first)
      remaining_tables = remaining_tables - [optimal_order.last]
    end
    
    return query.with_join_order(optimal_order)
  }
}

# Usage example
sql = """
  SELECT u.name, COUNT(o.id) as order_count
  FROM users u
  JOIN orders o ON u.id = o.user_id  
  WHERE u.email LIKE '%@gmail.com'
  GROUP BY u.name
  ORDER BY order_count DESC
"""

optimization_result = optimize_database_query(sql)

print "Original estimated cost: #{optimization_result.original_cost}"
print "Optimized estimated cost: #{optimization_result.optimized_cost}"
print "Performance improvement: #{optimization_result.improvement}%"
print "Execution plan: #{optimization_result.execution_plan}"
```

### Key Features Demonstrated

1. **Type-Guided Optimization**: Schema types inform optimization decisions
2. **Logic-Based Rules**: Database optimization heuristics as logic rules
3. **Goal-Oriented Search**: Multiple optimization strategies with backtracking
4. **Performance Measurement**: Quantitative optimization with cost models

## Example 3: Configuration Management System

### Problem Statement

Build a configuration management system that validates configuration files using type constraints, applies business rules through logic programming, and uses goals to resolve configuration conflicts automatically.

### Implementation

```patlang
# Configuration type system
constrain Config :: Object {
  services :: Map(String, ServiceConfig),
  global_settings :: GlobalSettings,
  environment :: Environment
}

constrain ServiceConfig :: Object {
  name :: String,
  version :: String where matches /^\d+\.\d+\.\d+$/,
  port :: Number where port > 1024 and port < 65536,
  dependencies :: List(String),
  resources :: ResourceRequirements
}

constrain ResourceRequirements :: Object {
  memory :: String where matches /^\d+[MG]B$/,
  cpu :: Number where cpu > 0 and cpu <= 16,
  disk :: String where matches /^\d+[MG]B$/
}

# Environment and constraint facts
fact environment("development")
fact environment("staging") 
fact environment("production")

fact port_range("development", 3000, 4000)
fact port_range("staging", 5000, 6000)
fact port_range("production", 8000, 9000)

fact max_memory("development", "4GB")
fact max_memory("staging", "8GB")
fact max_memory("production", "32GB")

# Configuration validation rules
rule valid_port_for_environment(Service, Port, Environment) if
  service_config(Service, port: Port) and
  port_range(Environment, MinPort, MaxPort) and
  Port >= MinPort and Port <= MaxPort

rule compatible_versions(Service1, Service2) if
  service_config(Service1, version: V1) and
  service_config(Service2, version: V2) and
  version_compatible(V1, V2)

rule no_port_conflicts(Service1, Service2) if
  Service1 != Service2 and
  service_config(Service1, port: Port1) and
  service_config(Service2, port: Port2) and
  Port1 != Port2

rule dependency_satisfied(Service, Dependency) if
  service_config(Service, dependencies: Deps) and
  member(Dependency, Deps) and
  service_exists(Dependency)

rule valid_resource_allocation(Service, Environment) if
  service_config(Service, resources: Resources) and
  max_memory(Environment, MaxMem) and
  memory_within_limit(Resources.memory, MaxMem)

# Goals for configuration management
goal validate_configuration(config) {
  precondition: config :: Config
  postcondition: all_constraints_satisfied(result)
  
  strategy: comprehensive_validation
  failure_handler: generate_validation_report
}

goal resolve_port_conflicts(config) {
  precondition: has_port_conflicts(config)
  postcondition: not has_port_conflicts(result)
  
  strategy: intelligent_port_assignment
}

goal satisfy_dependencies(config) {
  precondition: has_dependency_issues(config)
  postcondition: all_dependencies_satisfied(result)
  
  strategy: dependency_resolution
}

# Configuration manager
function manage_configuration(config_file, target_environment) {
  # Load and parse configuration
  raw_config = load_config_file(config_file)
  
  try {
    # Type validation
    typed_config = raw_config as Config
    
    # Set environment context
    assert_fact(current_environment(target_environment))
    
    # Validate configuration comprehensively
    validation_result = pursue validate_configuration(typed_config)
    
    if validation_result.success then
      return {
        status: "valid",
        config: validation_result.result,
        message: "Configuration is valid for #{target_environment}"
      }
    else
      # Attempt automatic conflict resolution
      resolved_config = pursue resolve_configuration_issues(typed_config)
      
      if resolved_config.success then
        return {
          status: "resolved",
          config: resolved_config.result,
          changes: resolved_config.changes_made,
          message: "Configuration issues automatically resolved"
        }
      else
        return {
          status: "invalid",
          errors: validation_result.errors,
          suggestions: generate_resolution_suggestions(validation_result.errors)
        }
      end
    end
    
  } catch TypeConstraintViolation(field, constraint, value) {
    return {
      status: "type_error",
      field: field,
      error: "#{field} = #{value} violates constraint: #{constraint}",
      suggestion: suggest_type_fix(field, constraint, value)
    }
  }
}

# Comprehensive validation strategy
strategy comprehensive_validation(goal, context) {
  config = goal.arguments[0]
  issues = []
  
  # Check port assignments
  for service_name, service_config in config.services do
    # Assert service facts for logic queries
    assert_fact(service_config(
      service_name,
      port: service_config.port,
      version: service_config.version,
      dependencies: service_config.dependencies
    ))
    
    # Validate port for environment
    current_env = query ?- current_environment(Env)
    if not query ?- valid_port_for_environment(
      service_name, service_config.port, current_env.first.Env) then
      issues.push({
        type: "port_error",
        service: service_name,
        port: service_config.port,
        environment: current_env.first.Env
      })
    end
    
    # Check dependencies
    for dependency in service_config.dependencies do
      if not query ?- dependency_satisfied(service_name, dependency) then
        issues.push({
          type: "dependency_error", 
          service: service_name,
          missing_dependency: dependency
        })
      end
    end
    
    # Validate resource requirements
    current_env = query ?- current_environment(Env)
    if not query ?- valid_resource_allocation(
      service_name, current_env.first.Env) then
      issues.push({
        type: "resource_error",
        service: service_name,
        resources: service_config.resources
      })
    end
  end
  
  # Check for port conflicts between services
  service_names = config.services.keys
  for i in 0..(service_names.length - 2) do
    for j in (i + 1)..(service_names.length - 1) do
      service1 = service_names[i]
      service2 = service_names[j]
      
      if not query ?- no_port_conflicts(service1, service2) then
        issues.push({
          type: "port_conflict",
          services: [service1, service2],
          port: config.services[service1].port
        })
      end
    end
  end
  
  if issues.empty then
    return config
  else
    fail ValidationError(issues)
  end
}

# Intelligent port assignment strategy
strategy intelligent_port_assignment(goal, context) {
  config = goal.arguments[0]
  current_env = query ?- current_environment(Env)
  env = current_env.first.Env
  
  # Get valid port range for environment
  port_info = query ?- port_range(env, MinPort, MaxPort)
  min_port = port_info.first.MinPort
  max_port = port_info.first.MaxPort
  
  used_ports = []
  new_config = config.deep_copy
  
  for service_name, service_config in new_config.services do
    # Check if current port is valid
    if service_config.port < min_port or service_config.port > max_port or
       service_config.port in used_ports then
      
      # Find next available port
      new_port = find_available_port(min_port, max_port, used_ports)
      
      if new_port then
        service_config.port = new_port
        used_ports.push(new_port)
        
        # Update facts for other validations
        retract_fact(service_config(service_name, port: _, version: _, dependencies: _))
        assert_fact(service_config(
          service_name,
          port: new_port,
          version: service_config.version,
          dependencies: service_config.dependencies
        ))
      else
        fail "No available ports in range #{min_port}-#{max_port}"
      end
    else
      used_ports.push(service_config.port)
    end
  end
  
  return new_config
}

# Usage example
config_data = {
  services: {
    "web-server": {
      name: "web-server",
      version: "2.1.0", 
      port: 3000,
      dependencies: ["database", "cache"],
      resources: {
        memory: "512MB",
        cpu: 1.0,
        disk: "1GB"
      }
    },
    "api-server": {
      name: "api-server",
      version: "1.5.2",
      port: 3000,  # Conflict with web-server
      dependencies: ["database"],
      resources: {
        memory: "256MB", 
        cpu: 0.5,
        disk: "500MB"
      }
    },
    "database": {
      name: "database",
      version: "5.7.0",
      port: 3306,
      dependencies: [],
      resources: {
        memory: "1GB",
        cpu: 2.0, 
        disk: "10GB"
      }
    }
  },
  global_settings: {
    log_level: "info",
    timeout: 30
  },
  environment: "development"
}

result = manage_configuration(config_data, "development")

print "Configuration status: #{result.status}"
if result.status == "resolved" then
  print "Automatic changes made:"
  for change in result.changes do
    print "  #{change}"
  end
  print "Final configuration valid for development environment"
elsif result.status == "invalid" then
  print "Configuration errors:"
  for error in result.errors do
    print "  #{error.type}: #{error.message}"
  end
end
```

### Key Features Demonstrated

1. **Complex Type Validation**: Nested object types with constraint expressions
2. **Environmental Logic**: Context-sensitive business rules
3. **Conflict Resolution Goals**: Automatic problem-solving with backtracking
4. **Dynamic Fact Management**: Runtime assertion and retraction of facts

## Example 4: Machine Learning Pipeline

### Problem Statement

Create a machine learning pipeline that uses type constraints to ensure data quality, logic programming to select appropriate algorithms, and goals to optimize model performance.

### Implementation

```patlang
# Type system for ML data
constrain Dataset :: Object {
  features :: List(Feature),
  target :: Feature,
  rows :: Number where rows > 0,
  clean :: Boolean
}

constrain Feature :: Object {
  name :: String,
  type :: DataType,  # :numerical, :categorical, :text, :date
  missing_percentage :: Number where missing_percentage >= 0 and missing_percentage <= 1,
  unique_values :: Number
}

constrain MLModel :: Object {
  algorithm :: Algorithm,
  hyperparameters :: Map(String, Any),
  performance :: ModelPerformance,
  trained :: Boolean
}

constrain ModelPerformance :: Object {
  accuracy :: Number where accuracy >= 0 and accuracy <= 1,
  precision :: Number where precision >= 0 and precision <= 1,
  recall :: Number where recall >= 0 and recall <= 1,
  f1_score :: Number where f1_score >= 0 and f1_score <= 1
}

# Algorithm selection rules
rule suitable_for_classification(Algorithm, Dataset) if
  classification_algorithm(Algorithm) and
  target_is_categorical(Dataset)

rule suitable_for_regression(Algorithm, Dataset) if
  regression_algorithm(Algorithm) and
  target_is_numerical(Dataset)

rule good_for_small_dataset(Algorithm) if
  small_data_algorithm(Algorithm)

rule good_for_large_dataset(Algorithm) if
  scalable_algorithm(Algorithm)

rule handles_missing_data(Algorithm) if
  missing_data_tolerant(Algorithm)

rule requires_feature_scaling(Algorithm) if
  distance_based_algorithm(Algorithm)

# Algorithm facts
fact classification_algorithm("random_forest")
fact classification_algorithm("svm")
fact classification_algorithm("logistic_regression")
fact classification_algorithm("neural_network")

fact regression_algorithm("linear_regression")
fact regression_algorithm("random_forest")
fact regression_algorithm("neural_network")

fact small_data_algorithm("svm")
fact small_data_algorithm("logistic_regression")

fact scalable_algorithm("random_forest")
fact scalable_algorithm("neural_network")

fact missing_data_tolerant("random_forest")

fact distance_based_algorithm("svm")
fact distance_based_algorithm("knn")

# Goals for ML pipeline
goal build_ml_pipeline(dataset) {
  precondition: dataset :: Dataset
  postcondition: result.performance.f1_score > 0.8
  
  strategy: comprehensive_ml_pipeline
  timeout: 300000ms  # 5 minutes
}

goal select_algorithm(dataset) {
  precondition: dataset :: Dataset and dataset.clean == true
  postcondition: suitable_algorithm(result, dataset)
  
  strategy: algorithm_selection_strategy
}

goal optimize_hyperparameters(model, dataset) {
  precondition: model :: MLModel and dataset :: Dataset
  postcondition: result.performance.f1_score >= model.performance.f1_score
  
  strategy: hyperparameter_optimization
}

goal clean_dataset(raw_dataset) {
  precondition: raw_dataset :: Dataset and raw_dataset.clean == false
  postcondition: result :: Dataset and result.clean == true
  
  strategy: data_cleaning_strategy
}

# ML Pipeline implementation
function train_ml_model(raw_data, target_column) {
  # Convert raw data to typed dataset
  dataset = analyze_dataset(raw_data, target_column) as Dataset
  
  try {
    # Build complete ML pipeline
    result = pursue build_ml_pipeline(dataset)
    
    if result.success then
      return {
        model: result.result,
        performance: result.result.performance,
        pipeline_steps: result.steps_taken,
        message: "Model successfully trained with F1-score: #{result.result.performance.f1_score}"
      }
    else
      return {
        error: "Pipeline failed to meet performance target",
        best_attempt: result.best_attempt,
        reason: result.failure_reason
      }
    end
    
  } catch TypeConstraintViolation(field, constraint, value) {
    return {
      error: "Data quality issue",
      field: field,
      message: "#{field} = #{value} violates #{constraint}",
      suggestion: suggest_data_fix(field, constraint, value)
    }
  }
}

# Comprehensive ML pipeline strategy
strategy comprehensive_ml_pipeline(goal, context) {
  dataset = goal.arguments[0]
  
  # Step 1: Data cleaning if needed
  if not dataset.clean then
    cleaned_dataset = pursue clean_dataset(dataset)
    if not cleaned_dataset.success then
      fail "Data cleaning failed: #{cleaned_dataset.failure_reason}"
    end
    dataset = cleaned_dataset.result
  end
  
  # Step 2: Algorithm selection
  selected_algorithm = pursue select_algorithm(dataset)
  if not selected_algorithm.success then
    fail "No suitable algorithm found for dataset"
  end
  
  algorithm = selected_algorithm.result
  
  # Step 3: Initial model training
  initial_model = train_initial_model(algorithm, dataset)
  
  # Step 4: Hyperparameter optimization
  optimized_model = pursue optimize_hyperparameters(initial_model, dataset)
  if not optimized_model.success then
    # Use initial model if optimization fails
    optimized_model = initial_model
  else
    optimized_model = optimized_model.result
  end
  
  # Step 5: Performance validation
  if optimized_model.performance.f1_score >= 0.8 then
    return optimized_model
  else
    # Try alternative approaches
    choice_point {
      # Try feature engineering
      engineered_dataset = pursue engineer_features(dataset)
      if engineered_dataset.success then
        improved_model = pursue optimize_hyperparameters(
          train_initial_model(algorithm, engineered_dataset.result),
          engineered_dataset.result
        )
        if improved_model.success and 
           improved_model.result.performance.f1_score >= 0.8 then
          return improved_model.result
        end
      end
    } backtrack_on_failure
    
    choice_point {
      # Try ensemble methods
      ensemble_model = pursue build_ensemble(dataset, [algorithm])
      if ensemble_model.success and
         ensemble_model.result.performance.f1_score >= 0.8 then
        return ensemble_model.result
      end
    } backtrack_on_failure
    
    fail "Could not achieve target performance (F1 >= 0.8)"
  end
}

# Algorithm selection strategy
strategy algorithm_selection_strategy(goal, context) {
  dataset = goal.arguments[0]
  candidate_algorithms = []
  
  # Use logic system to find suitable algorithms
  if query ?- target_is_categorical(dataset) then
    # Classification problem
    classification_algos = query ?- classification_algorithm(Algo)
    for result in classification_algos do
      candidate_algorithms.push(result.Algo)
    end
  else
    # Regression problem  
    regression_algos = query ?- regression_algorithm(Algo)
    for result in regression_algos do
      candidate_algorithms.push(result.Algo)
    end
  end
  
  # Filter based on dataset characteristics
  suitable_algorithms = []
  
  for algorithm in candidate_algorithms do
    reasons_to_include = []
    reasons_to_exclude = []
    
    # Check dataset size
    if dataset.rows < 1000 and query ?- good_for_small_dataset(algorithm) then
      reasons_to_include.push("good_for_small_data")
    elsif dataset.rows >= 10000 and query ?- good_for_large_dataset(algorithm) then
      reasons_to_include.push("good_for_large_data")
    end
    
    # Check missing data handling
    max_missing = max(dataset.features.map(f -> f.missing_percentage))
    if max_missing > 0.1 and not query ?- handles_missing_data(algorithm) then
      reasons_to_exclude.push("cannot_handle_missing_data")
    end
    
    # Score algorithm based on suitability
    score = reasons_to_include.length - reasons_to_exclude.length
    
    if score >= 0 then
      suitable_algorithms.push({
        algorithm: algorithm,
        score: score,
        reasons: reasons_to_include
      })
    end
  end
  
  if suitable_algorithms.empty then
    fail "No algorithms suitable for this dataset"
  end
  
  # Return highest scoring algorithm
  best = suitable_algorithms.max_by(a -> a.score)
  return best.algorithm
}

# Data cleaning strategy
strategy data_cleaning_strategy(goal, context) {
  dataset = goal.arguments[0]
  cleaned_features = []
  
  for feature in dataset.features do
    cleaned_feature = feature.deep_copy
    
    # Handle missing data
    if feature.missing_percentage > 0 then
      if feature.missing_percentage > 0.5 then
        # Too much missing data - remove feature
        continue  # Skip this feature
      elsif feature.type == :numerical then
        # Impute with median for numerical
        cleaned_feature.set_metadata(:imputation_method, "median")
        cleaned_feature.missing_percentage = 0
      elsif feature.type == :categorical then
        # Impute with mode for categorical
        cleaned_feature.set_metadata(:imputation_method, "mode")
        cleaned_feature.missing_percentage = 0
      end
    end
    
    # Handle high cardinality categorical features
    if feature.type == :categorical and feature.unique_values > 100 then
      # Apply feature encoding/grouping
      cleaned_feature.set_metadata(:encoding_applied, "frequency_encoding")
      cleaned_feature.unique_values = min(50, feature.unique_values)
    end
    
    cleaned_features.push(cleaned_feature)
  end
  
  # Create cleaned dataset
  cleaned_dataset = Dataset.new({
    features: cleaned_features,
    target: dataset.target,
    rows: dataset.rows,
    clean: true
  })
  
  return cleaned_dataset
}

# Usage example
raw_data = load_csv("customer_data.csv")

# Analyze dataset structure
dataset_info = {
  features: [
    { name: "age", type: :numerical, missing_percentage: 0.05, unique_values: 50 },
    { name: "income", type: :numerical, missing_percentage: 0.12, unique_values: 1000 },
    { name: "category", type: :categorical, missing_percentage: 0.02, unique_values: 5 },
    { name: "region", type: :categorical, missing_percentage: 0.0, unique_values: 25 }
  ],
  target: { name: "churn", type: :categorical, missing_percentage: 0.0, unique_values: 2 },
  rows: 5000,
  clean: false
}

result = train_ml_model(raw_data, "churn")

if result.model then
  print "Successfully trained #{result.model.algorithm} model"
  print "Performance metrics:"
  print "  Accuracy: #{result.performance.accuracy}"
  print "  Precision: #{result.performance.precision}"
  print "  Recall: #{result.performance.recall}"
  print "  F1-Score: #{result.performance.f1_score}"
  
  print "Pipeline steps taken:"
  for step in result.pipeline_steps do
    print "  #{step}"
  end
else
  print "Training failed: #{result.error}"
  if result.suggestion then
    print "Suggestion: #{result.suggestion}"
  end
end
```

### Key Features Demonstrated

1. **Type-Driven Data Validation**: Comprehensive data quality constraints
2. **Logic-Based Algorithm Selection**: Rule-based matching of algorithms to data characteristics
3. **Goal-Oriented Optimization**: Performance targets with fallback strategies
4. **Complex Decision Making**: Multi-step pipeline with backtracking and alternatives

## Summary

These examples demonstrate the power of Patlang's unified reasoning systems:

1. **Type Inference** provides static guarantees and validation
2. **Goal-Oriented Programming** enables intelligent problem-solving with backtracking
3. **Logic Programming** captures domain knowledge as declarative rules
4. **Cross-Paradigm Integration** creates synergistic effects greater than the sum of parts

The integration with Patlang's object-oriented foundation and event system enables reactive, maintainable, and extensible reasoning applications that can adapt to changing requirements and learn from execution patterns.