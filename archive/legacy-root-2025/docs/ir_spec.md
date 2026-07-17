# Patlang Intermediate Representation (IR) Specification

> Status: IN TRANSITION. This document now reflects the *implemented* core in
> `ir_interpreter.rb` and the emerging native C runtime plus a roadmap section
> for deferred/extended opcodes. Former names `IR_MUL` / `IR_DIV` are now
> standardised as `IR_MULTIPLY` / `IR_DIVIDE`; legacy forms remain accepted as
> aliases (see Compatibility section).

## 1. Overview
Patlang IR is a stack‑based, post‑parse, post‑(light) semantic lowering format.
Each instruction is an array: `["OPCODE", optional_operand1, optional_operand2, ...]`.

Current executors:
* Ruby reference interpreter: `ir_interpreter.rb`
* Patlang self-host line IR runner: `tools/ir_interpreter.patlang` (parses a
	line form and/or the array form).
* Native C prototype runtime: `tools/compiler/runtime.c` (subset).

## 2. Core Implemented Opcode Set (2025‑09)

| Category | Opcode | Stack Behavior (before -> after) | Notes |
|----------|--------|-----------------------------------|-------|
| Const / Data | IR_CONST v | [] -> [v] | `v` may be number, string, nil |
| Data | IR_ASSIGN name | [..., value] -> [...] | Pops value, stores env[name], pushes nothing (Ruby). C runtime currently pushes nil placeholder. |
| Data | IR_LOAD name | [...] -> [..., value] | Pushes copy / reference of env[name] or nil |
| Printing | IR_PRINT | [..., v] -> [...] | Emits tagged line. Native runtime prints `[OUT] v` while Ruby prints `[IR OUTPUT] v` (normalisation pending) |
| Arithmetic | IR_ADD | [..., a, b] -> [..., r] | Number+number = sum; otherwise string concat (nil becomes empty) |
| Arithmetic | IR_SUB | [..., a, b] -> [..., r|nil] | Nil if non‑numeric |
| Arithmetic | IR_MULTIPLY | [..., a, b] -> [..., r|nil] | Legacy alias: IR_MUL |
| Arithmetic | IR_DIVIDE | [..., a, b] -> [..., r|nil] | Division by zero -> nil. Legacy alias: IR_DIV |
| Arithmetic | IR_MODULO | [..., a, b] -> [..., r|nil] | b==0 -> nil |
| Control | IR_LABEL name | - | Marks jump target (no stack change) |
| Control | IR_JUMP name | - | Unconditional IP change |
| Control | IR_JUMP_IF name | [..., cond] -> [...] | Truthy cond triggers jump |
| Control | IR_RETURN | [..., v?] -> (halt/frame return) | Halts (or unwinds call frame) |
| Meta / Call | IR_CALL operand | See below | Handles builtin functions, label calls, closures (partial) |

### 2.1 IR_CALL Forms
`["IR_CALL", n]` – numeric (argc) call: expects stack top = func/closure, preceded by args.

`["IR_CALL", "labelName"]` – label call: optional argc numeric at stack top (popped); pushes frame `{return_ip, saved_stack_len}` then jumps.

`["IR_CALL", "MAKE_CLOSURE", label]` – builds closure capturing a *shallow copy* of current environment and pushes a closure object.

### 2.2 Truthiness
Ruby interpreter: nil/falsey values: `nil`, `false`; numbers (including 0) are truthy. **Native C runtime currently treats numeric 0 as false** (implementation divergence to be aligned – tracked as TODO).

## 3. Line IR (Text) to Array IR Mapping
The Patlang line IR (handled in `ir_interpreter.patlang`) maps one tokenised line to a canonical array entry:

| Line Form | Canonical Array IR |
|-----------|--------------------|
| NUM <n> | ["IR_CONST", <number>] |
| STR <text> | ["IR_CONST", <string>] |
| ADD | ["IR_ADD"] |
| SUB | ["IR_SUB"] |
| MUL | ["IR_MULTIPLY"] |
| DIV | ["IR_DIVIDE"] |
| MOD | ["IR_MODULO"] |
| PRINT | ["IR_PRINT"] |
| LABEL <name> | ["IR_LABEL", <name>] |
| JUMP <name> | ["IR_JUMP", <name>] |
| JUMP_IF <name> | ["IR_JUMP_IF", <name>] |
| ASSIGN <name> | ["IR_ASSIGN", <name>] |
| LOAD <name> | ["IR_LOAD", <name>] (special rewrite if preceded by STR) |
| CALL <x> | ["IR_CALL", <x>] (string or integer) |
| MAKE_CLOSURE <label> | ["IR_CALL", "MAKE_CLOSURE", <label>] |
| HALT | ["IR_RETURN"] |

## 4. Goal-Oriented Paradigm Opcodes (Phase 5.2)

| Opcode | Stack Behavior | Notes |
|--------|----------------|-------|
| IR_DEFINE_GOAL | [..., actions_array, conditions_array, name_str] -> [...] | Defines a goal with name, conditions, and actions for pursuit |
| IR_PURSUE | [..., goal_name_str, context] -> [..., result_map] | Pursues a goal, returns {success: bool, result: value} |
| IR_GOAL_SUCCESS | [..., goal_name_str, context] -> [..., bool] | Checks if a goal succeeded in context |
| IR_BACKTRACK | [..., context, failed_goal_name] -> [..., bool] | Attempts backtracking to alternative goal path |

These opcodes enable goal-driven programming with condition evaluation, dependency tracking, and choice point management.

## 5. Logic Programming Paradigm Opcodes (Phase 5.3)

| Opcode | Stack Behavior | Notes |
|--------|----------------|-------|
| IR_ASSERT_FACT | [..., fact_term] -> [...] | Asserts a fact into the knowledge base. fact_term is typically a tuple/array [predicate, arg1, arg2, ...] |
| IR_DEFINE_RULE | [..., body_goals_array, head_term] -> [...] | Defines a rule with head and body. head_term is the rule head; body_goals_array contains subgoals to unify |
| IR_QUERY | [..., goal_term] -> [..., solutions_array] | Executes a query against the knowledge base. Returns array of solution maps {var1: value1, ...} for each solution found via SLD resolution |
| IR_UNIFY | [..., term1, term2] -> [..., bool] | Tests if term1 and term2 unify. Returns true if unifiable, false otherwise. Can be used for explicit unification checks in knowledge base queries |

**Logic Programming Details:**

These opcodes provide Prolog-style logic programming with:
- **Knowledge Base:** Facts and rules stored persistently
- **Unification:** Full unification algorithm with occurs check
- **Query Execution:** SLD resolution with backtracking search
- **Multiple Solutions:** Queries return all solutions found via depth-first search
- **Variable Binding:** Solutions contain substitutions for all query variables

**Interoperability with Goals:** Logic programs can assert facts dynamically (from goal actions), rules can call goal-driven logic, and queries can be embedded in goal pursuits.

## 6. Planned / Deferred Opcodes (Future Phases)
These were listed in the legacy spec but are **not yet implemented**:

### Logic / Reasoning Layer (Phase 5.3)
IR_ASSERT_FACT, IR_DEFINE_RULE, IR_QUERY, IR_UNIFY [IN PROGRESS]

### Events & Reactive (Phase 5.4)
IR_EVENT, IR_EMIT, IR_ON

### Higher-Level Structural / Definition
IR_DEF, IR_CLASS_DEF, IR_NEW, IR_CONTRACT, IR_TYPE_ANNOT

IR_READ_FILE, IR_WRITE_FILE, IR_DELETE_FILE, IR_OPEN_SOCKET, IR_SEND_SOCKET,
IR_RECV_SOCKET, IR_SPAWN_PROCESS, IR_KILL_PROCESS, IR_WAIT_PROCESS

### Collections & Data Structures
IR_LIST, IR_DICT (list append/length currently appear as higher-level helpers, not core opcodes in native runtime)

### Concurrency & Async
IR_THREAD_START, IR_THREAD_JOIN, IR_CHANNEL_SEND, IR_CHANNEL_RECV, IR_FUTURE_CREATE, IR_FUTURE_AWAIT, IR_EVENT_WAIT, IR_EVENT_SIGNAL, IR_LOCK, IR_SYNC_BLOCK

### Errors
IR_THROW, IR_TRY

### Logic / Boolean Extras
IR_EQ, IR_NEQ, IR_LT, IR_GT, IR_AND, IR_OR, IR_NOT, IR_LEQ, IR_GEQ

## 7. Compatibility Notes
* Legacy names `IR_MUL`, `IR_DIV` in historical docs map to `IR_MULTIPLY`, `IR_DIVIDE`.
* Ruby interpreter currently recognises only `IR_MULTIPLY` / `IR_DIVIDE`; an alias layer has been added (see code comments) to accept old forms.
* Native C runtime subset (as of this spec update): IR_CONST, IR_PRINT, IR_ADD, IR_SUB, IR_MULTIPLY, IR_DIVIDE, IR_MODULO, IR_ASSIGN, IR_LOAD, IR_LABEL, IR_JUMP, IR_JUMP_IF, IR_RETURN.
* Output tag divergence: `[IR OUTPUT]` (Ruby / Patlang line runner) vs `[OUT]` (C). A unification to a single marker is TODO.
* Goal-oriented opcodes (IR_DEFINE_GOAL, IR_PURSUE, IR_GOAL_SUCCESS, IR_BACKTRACK) integrated in Phase 5.2.

## 8. Value Types
Runtime values are dynamic (Ruby) or tagged (C): numbers (double), strings, nil. Future: booleans, lists, dicts, objects, closures, goal contexts, maps.

## 9. Design Principles
1. Keep initial IR minimal & portable.
2. Prefer stack operations to reduce operand encoding overhead.
3. Separate high-level paradigms (logic/goal/event) into later lowering passes.

## 10. Example (Current Core)
```
[
	["IR_CONST", 2],
	["IR_CONST", 3],
	["IR_ADD"],
	["IR_PRINT"],
	["IR_RETURN"]
]
```

## 11. Example (Line IR Source)
```
NUM 2
NUM 3
ADD
PRINT
HALT
```

## 12. Goal-Oriented Programming Example (Phase 5.2)
```
[
	["IR_CONST", "clean"],
	["IR_CONST", []],
	["IR_CONST", [{"type" => "call", "function" => "clean_files"}]],
	["IR_DEFINE_GOAL"],
	["IR_CONST", "build"],
	["IR_LOAD", "goal_context"],
	["IR_PURSUE"],
	["IR_RETURN"]
]
```

## 13. Logic Programming Example (Phase 5.3)
```
[
	["IR_CONST", ["parent", "john", "mary"]],
	["IR_ASSERT_FACT"],
	["IR_CONST", ["parent", "mary", "alice"]],
	["IR_ASSERT_FACT"],
	["IR_CONST", [["parent", "X", "Y"], ["parent", "Y", "Z"]]],
	["IR_CONST", ["grandparent", "X", "Z"]],
	["IR_DEFINE_RULE"],
	["IR_CONST", ["grandparent", "X", "Z"]],
	["IR_QUERY"],
	["IR_PRINT"],
	["IR_RETURN"]
]
```
Output: Solutions map showing all bindings where grandparent relationship holds.

## 6. Event-Driven Programming Paradigm Opcodes (Phase 5.4)

| Opcode | Stack Behavior | Notes |
|--------|----------------|-------|
| IR_EMIT | [..., payload_map, event_name_str] -> [..., handlers_count_int] | Emits an event with payload. Returns count of handlers called. Supports variable/function/object/goal attachment |
| IR_ON | [..., handler_callback, event_name_str] -> [..., handler_id_int] | Subscribes to event. handler_callback is function/closure. Returns unique handler ID for later unsubscription |
| IR_ONCE | [..., handler_callback, event_name_str] -> [..., handler_id_int] | Subscribes to event for single execution. Handler is automatically unsubscribed after first trigger |
| IR_OFF | [..., handler_id_int] -> [..., bool] | Unsubscribes handler. Returns true if found and removed, false otherwise |
| IR_ATTACH | [..., event_types_array, target_id_str] -> [..., bool] | Attaches events to a target (variable, function, object, goal, query). Returns true on success |
| IR_DETACH | [..., event_types_array, target_id_str] -> [..., bool] | Detaches events from target. Returns true on success |

**Event-Driven Programming Details:**

These opcodes provide a flexible event system with:
- **Universal Attachment:** Events can be attached to any construct (variables, functions, objects, goals, queries, control flow)
- **Emission:** Events carry typed payloads with context metadata
- **Subscription:** Handlers can filter, prioritize, and react to events
- **Scoped Execution:** Handlers belong to scopes and auto-cleanup on scope exit
- **Handler Management:** Explicit subscription/unsubscription with handler ID tracking
- **Async Support:** Event queue for deferred handling

**Attachment Semantics:**

Variables can emit on:
- `variable:change` – value assignment
- `variable:access` – variable read
- `variable:mutate` – destructive update

Functions can emit on:
- `function:call` – before execution (with args)
- `function:return` – after execution (with return value)
- `function:error` – on exception

Objects can emit on:
- `object:property_change` – property update
- `object:method_call` – method invocation

Goals can emit on:
- `goal:start` – goal pursuit begins
- `goal:success` – goal conditions met
- `goal:failure` – goal failed
- `goal:backtrack` – alternative path explored

Queries can emit on:
- `query:start` – query begins
- `query:solution` – solution found
- `query:complete` – all solutions found

**Stack Examples:**

```
; Emit event with payload
["IR_CONST", "user:login"],
["IR_CONST", { "user": "alice", "timestamp": 1234567890 }],
["IR_EMIT"],                              ; -> [2] (2 handlers called)

; Subscribe to event
["IR_CONST", "user:login"],
["IR_CONST", handler_callback_func],
["IR_ON"],                                ; -> [42] (handler ID 42)

; Subscribe once
["IR_CONST", "app:startup"],
["IR_CONST", init_handler_func],
["IR_ONCE"],                              ; -> [43] (handler ID 43, auto-unsubscribed after first call)

; Unsubscribe
["IR_CONST", 42],
["IR_OFF"],                               ; -> [1] (true: unsubscribed)

; Attach events to variable
["IR_CONST", ["change", "access"]],
["IR_CONST", "user_var"],
["IR_ATTACH"],                            ; -> [1] (true: attached)

; Emit variable change
["IR_CONST", "user_var"],
["IR_CONST", "alice"],
["IR_EMIT_VARIABLE_CHANGE"]               ; -> [handler_count]
```

**Integration with Other Paradigms:**

Events integrate seamlessly:
- **With Goals:** Goals can emit on state transitions; handlers can trigger goal pursuit
- **With Logic:** Logic queries can emit on solution finding; handlers can assert facts
- **With Control Flow:** Loops emit iteration events; handlers can break early; conditionals emit branch events

**Handler Filtering and Context:**

Handlers receive event context:
```javascript
{
  "event": "user:login",
  "payload": { "user": "alice", ... },
  "timestamp": 1234567890,
  "target": "auth_service",
  "source": "variable_assignment"
}
```

Handlers can filter based on payload properties and context before execution.

## 14. Roadmap
Phase 5.1: Mixed-paradigm transpilation framework with paradigm detection.
Phase 5.2: Goal-oriented programming (DEFINE_GOAL, PURSUE, GOAL_SUCCESS, BACKTRACK opcodes). [✅ COMPLETE]
Phase 5.3: Logic programming (ASSERT_FACT, DEFINE_RULE, QUERY, UNIFY opcodes). [✅ COMPLETE]
Phase 5.4: Event-driven programming (EMIT, ON, ONCE, OFF, ATTACH, DETACH opcodes). [IN PROGRESS]
Phase 6: Concurrency primitives (threads/channels/futures) re-spec with deterministic guarantees.

---
Change Log (recent):
* 2025-09-05: Aligned spec with implemented core; added line IR mapping; deprecated IR_MUL/IR_DIV names.
* 2025-09-17: Added goal-oriented paradigm opcodes (Phase 5.2); examples and roadmap updated.
* 2026-01-17: Added logic programming opcodes (Phase 5.3); IR_ASSERT_FACT, IR_DEFINE_RULE, IR_QUERY, IR_UNIFY with examples and semantics.
* 2026-01-17: Added event-driven paradigm opcodes (Phase 5.4); IR_EMIT, IR_ON, IR_ONCE, IR_OFF, IR_ATTACH, IR_DETACH with attachment semantics and integration patterns.
