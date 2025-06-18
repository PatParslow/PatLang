# Unified Reasoning Architecture

## Executive Summary

This document specifies the technical architecture for integrating **Type Inference**, **Goal-Oriented Programming**, and **Logic Programming** paradigms within Patlang's existing object-oriented, event-driven infrastructure. The architecture leverages the established [`PatlangObject`](../../patlang-core/object_model/patlang_object.rb:1) foundation and [`EventSystem`](../../patlang-core/object_model/event_system.rb:1) to create a unified reasoning engine that coordinates constraint propagation, unification, and declarative programming.

## Architecture Overview

### Core Components

```
┌─────────────────────────────────────────────────────────┐
│                Unified Reasoning Engine                  │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────┐ │
│  │ Type Inference  │ │ Goal-Oriented   │ │    Logic    │ │
│  │    System      │ │   Programming   │ │ Programming │ │
│  │                │ │                 │ │             │ │
│  │ • Constraints  │ │ • Goal Stack    │ │ • Facts DB  │ │
│  │ • Unification  │ │ • Resolution    │ │ • Rules     │ │
│  │ • Propagation  │ │ • Backtracking  │ │ • Queries   │ │
│  └─────────────────┘ └─────────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│              Event-Driven Coordination Layer            │
├─────────────────────────────────────────────────────────┤
│ • Constraint Events  • Goal Events  • Logic Events     │
│ • Cross-paradigm messaging and synchronization         │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                 PatlangObject Foundation                │
├─────────────────────────────────────────────────────────┤
│ • Object registry and lifecycle management              │
│ • Event system and message passing                      │
│ • Metadata storage for reasoning state                  │
└─────────────────────────────────────────────────────────┘
```

### Integration Points

1. **Type-Guided Goal Resolution**: Type constraints inform goal achievement strategies
2. **Logic-Driven Type Refinement**: Logic rules refine and constrain type inference
3. **Event-Driven Constraint Propagation**: Changes trigger cross-paradigm updates
4. **Unified Variable Management**: Single namespace across all paradigms

## Type Inference System

### Type Constraint Engine

Extends [`PatlangObject`](../../patlang-core/object_model/patlang_object.rb:96) metadata system to store type constraints:

```ruby
class TypeConstraint < PatlangObject
  def initialize(variable, constraint_type, constraint_data)
    super({
      variable: variable,
      type: constraint_type,
      data: constraint_data
    }, :type_constraint)
    
    # Fire constraint creation event
    fire_event(:constraint_created, {
      variable: variable,
      constraint: constraint_type
    })
  end
end
```

### Unification Engine

Core unification algorithm with event notifications:

```ruby
class UnificationEngine
  include EventSystem::EventCapable
  
  def unify(term1, term2, substitution = {})
    result = perform_unification(term1, term2, substitution)
    
    fire_event(:unification_attempted, {
      term1: term1,
      term2: term2,
      result: result,
      substitution: result ? substitution : nil
    })
    
    result
  end
  
  private
  
  def perform_unification(term1, term2, substitution)
    # Implementation follows Robinson's algorithm
    # with PatlangObject integration
  end
end
```

### Type Propagation Network

Event-driven constraint propagation using existing [`EventSystem`](../../patlang-core/object_model/event_system.rb:286):

```ruby
class TypePropagationNetwork
  include EventSystem::EventCapable
  
  def initialize
    initialize_event_system
    @constraints = []
    @variables = {}
    
    # Subscribe to relevant events
    EventSystem.subscribe(:value_changed) do |event|
      propagate_from_value_change(event)
    end
  end
  
  def add_constraint(constraint)
    @constraints << constraint
    fire_event(:constraint_added, { constraint: constraint })
    propagate_constraint(constraint)
  end
  
  private
  
  def propagate_constraint(constraint)
    # Propagate type information through the network
    affected_variables = compute_affected_variables(constraint)
    
    affected_variables.each do |var|
      fire_event(:type_refined, {
        variable: var,
        old_type: @variables[var]&.type,
        new_type: refine_type(var, constraint)
      })
    end
  end
end
```

## Goal-Oriented Programming System

### Goal Stack Management

Built on [`PatlangObject`](../../patlang-core/object_model/patlang_object.rb:1) for lifecycle tracking:

```ruby
class Goal < PatlangObject
  def initialize(description, preconditions = [], postconditions = [])
    super({
      description: description,
      preconditions: preconditions,
      postconditions: postconditions,
      status: :pending,
      subgoals: [],
      solutions: []
    }, :goal)
    
    fire_event(:goal_created, { goal_id: object_id })
  end
  
  def achieve(context)
    fire_event(:goal_attempt_started, { goal_id: object_id })
    
    result = attempt_achievement(context)
    
    fire_event(:goal_attempt_completed, {
      goal_id: object_id,
      success: result.success?,
      solution: result.solution
    })
    
    result
  end
end
```

### Goal Resolution Engine

Coordinates with type system and logic system:

```ruby
class GoalResolutionEngine
  include EventSystem::EventCapable
  
  def initialize(type_system, logic_system)
    initialize_event_system
    @type_system = type_system
    @logic_system = logic_system
    @goal_stack = []
    
    # Cross-paradigm event subscriptions
    @type_system.on_event(:type_refined) do |event|
      update_goals_for_type_change(event)
    end
    
    @logic_system.on_event(:fact_asserted) do |event|
      update_goals_for_new_fact(event)
    end
  end
  
  def pursue_goal(goal)
    @goal_stack.push(goal)
    
    fire_event(:goal_pushed, { 
      goal: goal, 
      stack_depth: @goal_stack.length 
    })
    
    resolve_goal(goal)
  ensure
    @goal_stack.pop
    fire_event(:goal_popped, { 
      goal: goal, 
      stack_depth: @goal_stack.length 
    })
  end
  
  private
  
  def resolve_goal(goal)
    # Use type constraints to guide resolution
    type_constraints = @type_system.constraints_for_goal(goal)
    
    # Query logic system for applicable facts/rules
    applicable_rules = @logic_system.rules_for_goal(goal)
    
    # Attempt resolution with cross-paradigm coordination
    attempt_resolution(goal, type_constraints, applicable_rules)
  end
end
```

## Logic Programming System

### Facts and Rules Database

Extends [`PatlangObject`](../../patlang-core/object_model/patlang_object.rb:185) registry pattern:

```ruby
class FactsDatabase
  include EventSystem::EventCapable
  
  def initialize
    initialize_event_system
    @facts = {}
    @rules = {}
    @fact_counter = 0
  end
  
  def assert_fact(predicate, args = [])
    fact_id = generate_fact_id
    fact = Fact.new(fact_id, predicate, args)
    
    @facts[fact_id] = fact
    
    fire_event(:fact_asserted, {
      fact_id: fact_id,
      predicate: predicate,
      args: args
    })
    
    # Trigger goal system updates
    EventSystem.fire_global_event(:knowledge_updated, {
      type: :fact,
      content: fact
    })
    
    fact_id
  end
  
  def add_rule(head, body)
    rule_id = generate_rule_id
    rule = Rule.new(rule_id, head, body)
    
    @rules[rule_id] = rule
    
    fire_event(:rule_added, {
      rule_id: rule_id,
      head: head,
      body: body
    })
    
    # Trigger goal system updates
    EventSystem.fire_global_event(:knowledge_updated, {
      type: :rule,
      content: rule
    })
    
    rule_id
  end
end
```

### Query Resolution Engine

Integrates with unification and goal systems:

```ruby
class QueryEngine
  include EventSystem::EventCapable
  
  def initialize(facts_db, unification_engine, goal_system)
    initialize_event_system
    @facts_db = facts_db
    @unification_engine = unification_engine
    @goal_system = goal_system
  end
  
  def query(goal_term, substitution = {})
    fire_event(:query_started, { 
      goal: goal_term, 
      substitution: substitution 
    })
    
    solutions = []
    
    # Try facts first
    solutions.concat(query_facts(goal_term, substitution))
    
    # Try rules
    solutions.concat(query_rules(goal_term, substitution))
    
    fire_event(:query_completed, {
      goal: goal_term,
      solutions: solutions,
      count: solutions.length
    })
    
    solutions
  end
  
  private
  
  def query_facts(goal_term, substitution)
    matching_facts = @facts_db.facts_matching(goal_term.predicate)
    solutions = []
    
    matching_facts.each do |fact|
      unified_substitution = substitution.dup
      if @unification_engine.unify(goal_term, fact.term, unified_substitution)
        solutions << unified_substitution
      end
    end
    
    solutions
  end
end
```

## Cross-Paradigm Coordination

### Unified Reasoning Coordinator

Central orchestration using [`EventSystem`](../../patlang-core/object_model/event_system.rb:369) message bus:

```ruby
class UnifiedReasoningCoordinator
  include EventSystem::EventCapable
  
  def initialize
    initialize_event_system
    
    @type_system = TypeInferenceSystem.new
    @goal_system = GoalOrientedSystem.new
    @logic_system = LogicProgrammingSystem.new
    
    setup_cross_paradigm_coordination
  end
  
  private
  
  def setup_cross_paradigm_coordination
    # Type system informs goal system
    @type_system.on_event(:type_refined) do |event|
      @goal_system.handle_type_refinement(event)
    end
    
    # Goal system queries logic system
    @goal_system.on_event(:goal_needs_facts) do |event|
      facts = @logic_system.query_for_goal(event[:goal])
      @goal_system.provide_facts(event[:goal], facts)
    end
    
    # Logic system updates type constraints
    @logic_system.on_event(:fact_asserted) do |event|
      if type_fact?(event[:fact])
        @type_system.add_constraint_from_fact(event[:fact])
      end
    end
    
    # All systems contribute to unified variable resolution
    setup_variable_coordination
  end
  
  def setup_variable_coordination
    # Unified variable namespace across paradigms
    @shared_variables = {}
    
    [type_system, @goal_system, @logic_system].each do |system|
      system.on_event(:variable_referenced) do |event|
        coordinate_variable_access(event)
      end
    end
  end
end
```

## Integration with Existing Infrastructure

### Evaluator Integration

Extends existing [`Evaluator`](../../patlang-core/evaluator/evaluator.rb:9) architecture:

```ruby
# In patlang-core/evaluator/reasoning_evaluator.rb
module EvaluatorModules
  class ReasoningEvaluator
    def initialize(evaluator)
      @evaluator = evaluator
      @reasoning_coordinator = UnifiedReasoningCoordinator.new
    end
    
    def visit_type_constraint_node(node)
      constraint = @reasoning_coordinator.type_system.add_constraint(
        node.variable,
        node.constraint_type,
        node.constraint_data
      )
      
      if @evaluator.object_mode_enabled?
        constraint
      else
        constraint.value
      end
    end
    
    def visit_goal_node(node)
      goal = Goal.new(node.description, node.preconditions, node.postconditions)
      result = @reasoning_coordinator.goal_system.pursue_goal(goal)
      
      if @evaluator.object_mode_enabled?
        result
      else
        result.success?
      end
    end
    
    def visit_logic_rule_node(node)
      rule_id = @reasoning_coordinator.logic_system.add_rule(
        node.head,
        node.body
      )
      
      if @evaluator.object_mode_enabled?
        @reasoning_coordinator.logic_system.get_rule(rule_id)
      else
        rule_id
      end
    end
  end
end
```

### Parser Extensions

New AST nodes for reasoning constructs:

```ruby
# In patlang-core/ast/ast_nodes.rb extensions
class TypeConstraintNode < ASTNode
  attr_reader :variable, :constraint_type, :constraint_data
  
  def initialize(variable, constraint_type, constraint_data)
    @variable = variable
    @constraint_type = constraint_type
    @constraint_data = constraint_data
  end
end

class GoalNode < ASTNode
  attr_reader :description, :preconditions, :postconditions
  
  def initialize(description, preconditions = [], postconditions = [])
    @description = description
    @preconditions = preconditions
    @postconditions = postconditions
  end
end

class LogicRuleNode < ASTNode
  attr_reader :head, :body
  
  def initialize(head, body)
    @head = head
    @body = body
  end
end

class QueryNode < ASTNode
  attr_reader :goal_term, :variables
  
  def initialize(goal_term, variables = [])
    @goal_term = goal_term
    @variables = variables
  end
end
```

## Performance and Scalability

### Event System Optimization

Leverages existing [`EventSystem`](../../patlang-core/object_model/event_system.rb:12) performance features:

- Event batching for constraint propagation
- Selective subscription patterns
- Event history management with configurable limits
- Lazy evaluation of reasoning chains

### Memory Management

Uses [`PatlangObject`](../../patlang-core/object_model/patlang_object.rb:183) lifecycle management:

- Automatic cleanup of reasoning artifacts
- Reference counting for constraint networks
- Garbage collection integration
- Memory pressure response strategies

### Caching Strategy

```ruby
class ReasoningCache
  include EventSystem::EventCapable
  
  def initialize
    initialize_event_system
    @type_cache = {}
    @goal_cache = {}
    @query_cache = {}
    
    # Invalidate caches on knowledge updates
    EventSystem.subscribe(:knowledge_updated) do |event|
      invalidate_affected_caches(event)
    end
  end
  
  def cached_query(query_key, &computation)
    if @query_cache.key?(query_key)
      fire_event(:cache_hit, { key: query_key, type: :query })
      return @query_cache[query_key]
    end
    
    result = computation.call
    @query_cache[query_key] = result
    
    fire_event(:cache_miss, { key: query_key, type: :query })
    result
  end
end
```

## Testing Integration

### Test Categories

Aligns with existing test infrastructure:

1. **infrastructure/**: Core reasoning engine tests
2. **patlang_language/**: Language syntax and semantics
3. **ruby_implementation/**: Ruby-specific implementation details

### Test Examples

```ruby
# test/infrastructure/test_unified_reasoning.rb
class TestUnifiedReasoning < Minitest::Test
  def setup
    @coordinator = UnifiedReasoningCoordinator.new
  end
  
  def test_type_constraint_goal_interaction
    # Test type constraints guiding goal resolution
    goal = Goal.new("find_number", [], ["result.type == :number"])
    @coordinator.type_system.add_constraint("result", :type, :number)
    
    result = @coordinator.pursue_goal(goal)
    assert result.success?
    assert_equal :number, result.solution.type
  end
end
```

## Security Considerations

### Constraint Validation

- Input sanitization for constraint definitions
- Privilege separation between paradigms
- Resource limits for reasoning depth
- Audit logging for reasoning decisions

### Event Security

Extends [`EventSystem`](../../patlang-core/object_model/event_system.rb:1) security model:

- Event source verification
- Payload validation
- Cross-paradigm access controls
- Reasoning result integrity checks

## Conclusion

This architecture provides a foundation for implementing unified reasoning capabilities while maintaining compatibility with Patlang's existing object-oriented and event-driven infrastructure. The design emphasizes:

1. **Incremental Implementation**: Each paradigm can be developed independently
2. **Event-Driven Coordination**: Natural integration with existing patterns
3. **Object-Oriented Foundation**: Leverages established [`PatlangObject`](../../patlang-core/object_model/patlang_object.rb:1) capabilities
4. **Extensible Design**: Clean extension points for future reasoning paradigms

The next phase involves detailed API design and implementation roadmap planning.