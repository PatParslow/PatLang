# Type Constraint Parser Event System Fix

## Problem
The test `test_parse_simple_type_annotation` was failing with:
```
Expected type_annotation_parsed event to fire (Minitest::Assertion)
```

## Root Cause
The Parser class lacked an event system but the test expected:
- `parser.on_event(:type_annotation_parsed)` to work  
- Events to be fired when parsing type annotations

## Solution
### 1. Added Event System to Parser Class
**File**: `src/parser.rb`
```ruby
# Added EventCapable mixin and event system initialization
require_relative 'object_model/event_system'

class Parser
  include EventSystem::EventCapable
  
  def initialize(tokens_or_lexer)
    # Initialize event system
    initialize_event_system
    # ... rest of initialization
  end
```

### 2. Added Event Firing to TypeConstraintParser  
**File**: `src/parser/type_constraint_parser.rb`
```ruby
def parse_type_annotation
  variable_name = expect_identifier
  @parser.eat(:DOUBLE_COLON)
  type_constraint = parse_type_constraint
  
  # Fire event when type annotation is parsed
  if @parser.respond_to?(:fire_event)
    @parser.fire_event(:type_annotation_parsed, {
      variable: variable_name,
      type: type_constraint
    })
  end
  
  TypeAnnotationNode.new(variable_name, type_constraint)
end
```

## Verification
- ✅ `parser.respond_to?(:on_event)` returns `true`
- ✅ `parser.respond_to?(:fire_event)` returns `true`  
- ✅ `test_parse_simple_type_annotation` now passes
- ✅ Original failing command now works: "Test completed successfully"

## Impact
This fix enables event-driven testing for type constraint parsing while maintaining backward compatibility. The event system integrates with the existing Patlang object model event infrastructure.