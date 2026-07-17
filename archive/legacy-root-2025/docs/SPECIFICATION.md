# PatLang Formal Specification
## Core Language Syntax, Semantics, and Type System

**Version**: 0.7.0-draft
**Status**: Living specification for TDD-driven implementation
**Approach**: Formal methods where appropriate; executable specification via property-based tests

---

## 1. Lexical Grammar (Token Definitions)

### 1.1 Token Categories

```
TOKEN ::= 
    | IDENTIFIER          # [a-zA-Z_][a-zA-Z0-9_]* (case-sensitive)
    | INTEGER_LITERAL     # [0-9]+
    | FLOAT_LITERAL       # [0-9]+'.'[0-9]+
    | STRING_LITERAL      # '"' (ESCAPED_CHAR | NON_QUOTE)* '"'
    | BLOCK_PARAM         # '|' IDENTIFIER (',' IDENTIFIER)* '|'
    
    # Keywords (context-sensitive - see §1.3)
    | MAKE | A | AN | CALLED | WHEN | THEN | ELSE | END | BEGIN
    | IS | BECOMES | IS_NOT | AND | OR | NOT
    | IF | WHILE | FOR | IN | RETURN | BREAK | CONTINUE
    | REQUIRES | ENSURES | MAINTAINS | ACHIEVED | RUNS
    | ACTIVATE | QUERY | ASSERT | RETRACT
    | TRUE | FALSE | NIL
    | TAKES | RETURNS
    
    # Operators & Delimiters
    | PLUS | MINUS | STAR | SLASH | PERCENT
    | EQ | NEQ | LT | GT | LTE | GTE
    | LPAREN | RPAREN | LBRACE | RBRACE | LBRACKET | RBRACKET
    | COMMA | DOT | COLON | SEMICOLON | ARROW | PIPE
    | NEWLINE | EOF
```

### 1.2 Context-Sensitive Tokenization

**Critical Design**: The parser communicates expected token types to the lexer. The lexer resolves ambiguities based on parser expectations.

```
LEXER_INTERFACE(
    input: String,
    expectations: Set<TokenType>  -- from parser
) -> TokenStream
```

**Ambiguity Resolution Rules**:

| Token Text | Possible Types | Resolution by Expectation |
|------------|----------------|---------------------------|
| `is` | IDENTIFIER, IS_KEYWORD | If `IS_KEYWORD ∈ expectations` → IS_KEYWORD; else IDENTIFIER |
| `make` | IDENTIFIER, MAKE_KEYWORD | If `MAKE_KEYWORD ∈ expectations` → MAKE_KEYWORD |
| `a`/`an` | IDENTIFIER, ARTICLE | If `ARTICLE ∈ expectations` → ARTICLE |
| `when` | IDENTIFIER, WHEN_KEYWORD | If `WHEN_KEYWORD ∈ expectations` → WHEN_KEYWORD |
| `then` | IDENTIFIER, THEN_KEYWORD | If `THEN_KEYWORD ∈ expectations` → THEN_KEYWORD |
| `end` | IDENTIFIER, END_KEYWORD | If `END_KEYWORD ∈ expectations` → END_KEYWORD |
| `{` | LBRACE, BLOCK_START | If in function/block context → BLOCK_START |
| `|` | PIPE, BLOCK_PARAM_START | If expecting block parameter → BLOCK_PARAM_START |
| `=>` | ARROW | Always ARROW (no ambiguity) |

### 1.3 Parser-Driven Lexer Protocol

```ruby
# The parser requests tokens with expectations
class Parser
  def tokenize(input, expectations = default_expectations)
    @lexer.tokenize(input, expectations)
  end
  
  # Example: parsing "make a function called foo { ... }"
  def make_declaration
    # After "make", we expect ARTICLE
    @current_expectations = { ARTICLE }
    consume(ARTICLE)  # "a" or "an"
    
    # Then declaration type keyword
    @current_expectations = { FUNCTION_KW, CLASS_KW, TEMPLATE_KW, GOAL_KW, LIST_KW }
    decl_type = consume_expected([FUNCTION_KW, CLASS_KW, TEMPLATE_KW, GOAL_KW, LIST_KW])
    
    # Then CALLED
    @current_expectations = { CALLED }
    consume(CALLED)
    
    # Then IDENTIFIER (name)
    @current_expectations = { IDENTIFIER }
    name = consume(IDENTIFIER)
    ...
  end
end
```

---

## 2. Syntax Grammar (EBNF)

### 2.1 Program Structure

```
PROGRAM        ::= STATEMENT* EOF

STATEMENT      ::= 
    | MAKE_DECLARATION NEWLINE
    | WHEN_HANDLER NEWLINE
    | IF_STATEMENT NEWLINE
    | WHILE_STATEMENT NEWLINE
    | FOR_STATEMENT NEWLINE
    | EXPRESSION_STATEMENT NEWLINE
    | ASSIGNMENT NEWLINE
    | ACTIVATE_STATEMENT NEWLINE
    | QUERY_STATEMENT NEWLINE
    | ASSERT_STATEMENT NEWLINE
    | RETURN_STATEMENT NEWLINE

MAKE_DECLARATION ::= 
    'make' ARTICLE DECL_TYPE 'called' IDENTIFIER BLOCK
    
ARTICLE        ::= 'a' | 'an'
DECL_TYPE      ::= 'function' | 'class' | 'template' | 'goal' | 'list' | 'number' | 'text' | 'boolean'

BLOCK          ::= '{' STATEMENT* '}' 
                | 'begin' STATEMENT* 'end'
                | NEWLINE INDENT STATEMENT* DEDENT  -- optional significant whitespace
```

### 2.2 Function Declaration

```
FUNCTION_BLOCK ::= 
    ('takes' ':' PARAM_LIST)?
    ('returns' ':' TYPE_ANNOTATION)?
    ('requires' ':' PRECONDITION_LIST)?
    ('ensures' ':' POSTCONDITION_LIST)?
    BODY
    
PARAM_LIST     ::= PARAM (',' PARAM)*
PARAM          ::= IDENTIFIER ('- ' TYPE_ANNOTATION)? ('=' EXPRESSION)?
TYPE_ANNOTATION::= 'number' | 'text' | 'boolean' | 'list' | 'any' | IDENTIFIER  -- user types
PRECONDITION_LIST ::= PRECONDITION (',' PRECONDITION)*
POSTCONDITION_LIST ::= POSTCONDITION (',' POSTCONDITION)*
PRECONDITION   ::= EXPRESSION
POSTCONDITION  ::= EXPRESSION
```

### 2.3 Class/Template Declaration

```
TEMPLATE_BLOCK ::= 
    ('inherits' 'from' IDENTIFIER)?
    ('has' ':' FIELD_LIST)?
    ('maintains' ':' INVARIANT_LIST)?
    METHOD_DECL*
    
FIELD_LIST     ::= FIELD (',' FIELD)*
FIELD          ::= IDENTIFIER '-' TYPE_ANNOTATION ('=' EXPRESSION)?
INVARIANT_LIST ::= INVARIANT (',' INVARIANT)*
INVARIANT      ::= EXPRESSION
METHOD_DECL    ::= IDENTIFIER FUNCTION_BLOCK
```

### 2.4 Goal Declaration

```
GOAL_BLOCK ::= 
    ('requires' ':' REQUIREMENT_LIST)?
    ('achieved' 'when' ':' CONDITION_LIST)?
    ('runs' ':' BODY)?
    
REQUIREMENT_LIST ::= IDENTIFIER ('-' TYPE_ANNOTATION)? ('=' EXPRESSION)? (',' ...)?
CONDITION_LIST   ::= EXPRESSION (',' EXPRESSION)*
```

### 2.5 Control Flow

```
IF_STATEMENT ::= 'if' EXPRESSION 'then' BLOCK ('elsif' EXPRESSION 'then' BLOCK)* ('else' BLOCK)? 'end'

WHILE_STATEMENT ::= 'while' EXPRESSION 'do' BLOCK 'end'

FOR_STATEMENT ::= 'for' IDENTIFIER 'in' EXPRESSION 'do' BLOCK 'end'
               | 'for' IDENTIFIER 'in' 'range' '(' EXPRESSION ',' EXPRESSION ')' 'do' BLOCK 'end'
```

### 2.6 Event Handlers

```
WHEN_HANDLER ::= 'when' EVENT_SPEC ('is' 'activated')? BLOCK

EVENT_SPEC   ::= IDENTIFIER (':' EVENT_ACTION)?
EVENT_ACTION ::= 'called' | 'completed' | 'error' | 'changed' | 'activated'
```

### 2.7 Activations & Queries

```
ACTIVATE_STATEMENT ::= 'activate' IDENTIFIER ('with' EXPRESSION)?
QUERY_STATEMENT    ::= 'query' IDENTIFIER BLOCK 'end'
ASSERT_STATEMENT   ::= 'assert' FACT '.'
FACT           ::= PREDICATE '(' TERM (',' TERM)* ')'
PREDICATE      ::= IDENTIFIER
TERM           ::= IDENTIFIER | LITERAL | VARIABLE
```

### 2.8 Expressions

```
EXPRESSION     ::= LOGICAL_OR

LOGICAL_OR     ::= LOGICAL_AND ('or' LOGICAL_AND)*
LOGICAL_AND    ::= EQUALITY ('and' EQUALITY)*
EQUALITY       ::= COMPARISON (('is' | 'is not') COMPARISON)*
COMPARISON     ::= ADDITIVE (('<' | '>' | '<=' | '>=') ADDITIVE)*
ADDITIVE       ::= MULTIPLICATIVE (('+' | '-') MULTIPLICATIVE)*
MULTIPLICATIVE ::= UNARY (('*' | '/' | '%') UNARY)*
UNARY          ::= ('not' | '-' )? PRIMARY
PRIMARY        ::= LITERAL | VARIABLE | FUNCTION_CALL | BLOCK_LITERAL | LIST_LITERAL | '(' EXPRESSION ')'

FUNCTION_CALL  ::= IDENTIFIER '(' ARG_LIST? ')'
               | IDENTIFIER                      -- zero-arg call
               
ARG_LIST       ::= EXPRESSION (',' EXPRESSION)*
BLOCK_LITERAL  ::= '|' PARAM_LIST? '|' BLOCK    -- lambda: |x, y| x + y
LIST_LITERAL   ::= '[' EXPRESSION? (',' EXPRESSION)* ']'
LITERAL        ::= INTEGER_LITERAL | FLOAT_LITERAL | STRING_LITERAL | TRUE | FALSE | NIL
VARIABLE       ::= IDENTIFIER
```

---

## 3. Operational Semantics (Small-Step)

### 3.1 Configuration

```
Configuration ::= ⟨ Environment, Store, Continuation, EventQueue ⟩

Environment   ::= Var ⟼ Value          -- lexical scope
Store         ::= Loc ⟼ Value          -- heap (objects, closures)
Continuation  ::= Frame*               -- call stack
EventQueue    ::= Event*               -- pending events
```

### 3.2 Values

```
Value ::= 
    | Int(n) 
    | Float(f) 
    | String(s) 
    | Bool(b) 
    | Nil 
    | Loc(l)                    -- object reference
    | Closure(params, body, env) 
    | NativeFn(name, arity, fn) 
    | ListRef(loc) 
    | EventHandler(handler_fn)
```

### 3.3 Evaluation Rules (Selected)

#### Variable Binding (IS)
```
⟨ Γ, σ, IS x = e :: κ, Q ⟩ 
  → ⟨ Γ, σ, e :: BindVar(x) :: κ, Q ⟩

[BindVar(x)] v :: κ  →  ⟨ Γ[x ↦ v], σ, κ ⟩
  -- Side effect: emit VariableChanged(x, old_Γ(x), v) to EventQueue
```

#### Variable Mutation (BECOMES)
```
⟨ Γ, σ, BECOMES x = e :: κ, Q ⟩
  → ⟨ Γ, σ, e :: UpdateVar(x) :: κ, Q ⟩

[UpdateVar(x)] v :: κ  →  ⟨ Γ[x ↦ v], σ, κ ⟩
  -- Side effect: emit VariableChanged(x, old_Γ(x), v) to EventQueue
```

#### Function Call
```
⟨ Γ, σ, CALL f(args) :: κ, Q ⟩
  → ⟨ Γ, σ, args :: CallFunc(f) :: κ, Q ⟩

[CallFunc(f)] [v₁...vₙ] :: κ  →  
  if f = Closure(params, body, env) ∧ len(params) = n then
    -- Emit FunctionCalled event
    emit(FunctionCalled(f, [v₁...vₙ]), Q)
    let new_env = env ⊕ {paramsᵢ ↦ vᵢ}
    ⟨ Γ, σ, body :: Return(result) :: κ, Q' ⟩
  else if f = NativeFn then
    -- ... native call ...
```

#### Function Return
```
[Return] v :: κ  →  
  -- Emit FunctionCompleted event
  emit(FunctionCompleted(f, v), Q)
  κ  (pop frame)
```

#### Event Emission
```
⟨ Γ, σ, EMIT event_spec WITH payload :: κ, Q ⟩
  → ⟨ Γ, σ, payload :: EmitEvent(event_spec) :: κ, Q' ⟩

[EmitEvent(spec)] payload :: κ  →  
  let handlers = lookup_handlers(spec)
  Q' = Q ⊕ { (h, payload) for h in handlers }
  ⟨ Γ, σ, κ, Q' ⟩
```

#### Event Handler Execution (asynchronous, queued)
```
EventLoop(Q) = 
  if Q = ∅ then idle
  else 
    let (handler, payload) = pop(Q)
    -- Execute handler in fresh continuation
    ⟨ ∅, σ, handler(payload) :: HALT, Q' ⟩
    then continue EventLoop(Q')
```

#### Goal Activation
```
⟨ Γ, σ, ACTIVATE goal_name [with args] :: κ, Q ⟩
  → 
  let goal = lookup_goal(goal_name)
  if preconditions_satisfied(goal, args, Γ) then
    Q' = Q ⊕ (goal.runs_handler, args)
    emit(GoalActivated(goal_name), Q)
    ⟨ Γ, σ, κ, Q' ⟩
  else
    emit(GoalFailed(goal_name, missing_preconditions), Q)
    ⟨ Γ, σ, κ, Q ⟩
```

---

## 4. Type System

### 4.1 Types

```
Type ::= 
    | Int | Float | Bool | String | Nil
    | Any
    | List(Type)
    | Function(ParamTypes, ReturnType)
    | Object(TypeName)          -- template/class instances
    | TypeVar(α)               -- for inference
    | Union(Type, Type)
```

### 4.2 Typing Judgments

```
Γ ⊢ e : τ          -- expression typing
Γ ⊢ s ok           -- statement well-formed
Γ ⊢ decl : τ       -- declaration typing
```

### 4.3 Key Typing Rules

```
[VAR]    Γ(x) = τ
         ──────
         Γ ⊢ x : τ

[LIT]    ──────
         Γ ⊢ n : Int
         Γ ⊢ s : String
         Γ ⊢ true : Bool

[APP]    Γ ⊢ f : Function(τ₁...τₙ, τ)    Γ ⊢ eᵢ : τᵢ
         ────────────────────────────────────────
         Γ ⊢ f(e₁...eₙ) : τ

[LAMBDA]  Γ, x₁:τ₁...xₙ:τₙ ⊢ e : τ
         ───────────────────────────────────
         Γ ⊢ |x₁...xₙ| e : Function(τ₁...τₙ, τ)

[LET]     Γ ⊢ e₁ : τ₁    Γ, x:τ₁ ⊢ e₂ : τ₂
         ──────────────────────────────────
         Γ ⊢ (x IS e₁; e₂) : τ₂  -- 'x IS e₁' binds x

[MUTATE]  Γ ⊢ e : τ    Γ(x) = τ
         ──────────────────────
         Γ ⊢ (x BECOMES e) : τ
```

### 4.4 Type Inference (Hindley-Milner + Constraints)

**Algorithm W extended with:**
- Subtyping constraints (for Object types)
- Union types (for flexible returns)
- Constraint generation from contracts (requires/ensures)

---

## 5. Contract Semantics

### 5.1 Contract Structure

```
Contract ::= Requires(preconditions) | Ensures(postconditions) | Maintains(invariants)
Precondition  ::= Expr of type Bool
Postcondition ::= Expr of type Bool (may reference `result`)
Invariant     ::= Expr of type Bool
```

### 5.2 Runtime Enforcement

```
-- At function entry:
∀ pre ∈ requires(f):  assert(pre(args), PreconditionViolation)

-- At function exit (normal):
∀ post ∈ ensures(f):  assert(post(args, result), PostconditionViolation)

-- At object mutation:
∀ inv ∈ maintains(template):  assert(inv(self), InvariantViolation)
```

### 5.3 Static Verification (Future)

Contracts generate verification conditions for SMT solving:

```
VC(f) = (requires(f) ∧ body(f)) → (ensures(f) ∧ maintains(f))
```

---

## 6. Standard Library Module System

### 6.1 Module Declaration

```
MODULE ::= 'module' IDENTIFIER ('version' STRING)? 
            ('depends' 'on' MODULE_LIST)?
            ('provides' EXPORT_LIST)?
            BLOCK
```

### 6.2 Runtime Feature Flags

```ruby
# stdlib/core/collections.rb
module Patlang::Stdlib::Collections
  # Conditional inclusion based on runtime capability flags
  include_if :functional do
    def map(list, block) ... end
    def filter(list, block) ... end
    def reduce(list, block, init) ... end
  end
  
  include_if :basic do
    def length(list) ... end
    def append(list, item) ... end
  end
end
```

### 6.3 Capability Registry

```ruby
class CapabilityRegistry
  CAPABILITIES = {
    basic:        { requires: [] },
    functional:   { requires: [:basic, :closures] },
    goal_based:   { requires: [:basic, :events, :logic] },
    logic:        { requires: [:basic, :unification] },
    events:       { requires: [:basic] },
    oo:           { requires: [:basic] },
    contracts:    { requires: [:basic] },
  }
  
  def enable(capability, runtime)
    CAPABILITIES[capability][:requires].each { |req| 
      enable(req, runtime) unless runtime.has?(req) 
    }
    load_module(capability, runtime)
  end
end
```

---

## 7. Self-Hosting Constraints

### 7.1 Bootstrap Subset (PatLang₀)

The following constructs must be implementable in PatLang itself:

| Construct | In PatLang₀? | Notes |
|-----------|--------------|-------|
| Variables (IS/BECOMES) | ✅ | Core |
| Basic arithmetic | ✅ | In stdlib::basic |
| Functions (closures) | ✅ | Required for compiler passes |
| Lists | ✅ | AST nodes are lists of lists |
| Pattern matching | 🚧 | Needed for parser |
| String manipulation | ❌ | Need for source handling |
| File I/O | ❌ | Need for reading source |
| Pattern matching | 🚧 | Parser token resolution |
| Hash maps | 🚧 | Symbol tables |

### 7.2 Compiler Pipeline in PatLang

```patlang
module compiler
  -- Stage 1: Lexing (needs pattern matching + strings)
  make a function called lex { ... }
  
  -- Stage 2: Parsing (needs pattern matching + recursion)
  make a function called parse { ... }
  
  -- Stage 3: Type checking (needs unification + constraints)
  make a function called type_check { ... }
  
  -- Stage 4: IR generation (needs custom data structures)
  make a function called gen_ir { ... }
  
  -- Stage 5: Code emission (needs string building + I/O)
  make a function called emit_code { ... }
end
```

---

## 8. Testing Specification (TDD Contracts)

### 8.1 Property-Based Tests

```ruby
# Property: Variable binding is idempotent
property "IS binding" do
  for_all(input: valid_identifier) do |name|
    eval!("#{name} IS 42; #{name}").should == 42
  end
end

# Property: Function call preserves lexical scope
property "closure captures environment" do
  for_all(x: integer, y: integer) do |x, y|
    code = "
      outer_x IS #{x}
      make a function called inner {
        inner takes: z - number
        inner returns: outer_x + z
      }
      inner(#{y})
    "
    eval!(code).should == x + y
  end
end

# Property: Event handlers fire exactly once per emission
property "event handler execution" do
  # ... test event queue semantics
end
```

### 8.2 Contract Test Templates

```ruby
# Every public API must have contract tests
RSpec.describe "FunctionElement" do
  it "emits :called before execution" do
    # Given a function with handler
    # When called
    # Then :called event emitted with correct payload
  end
  
  it "emits :completed with result after success" do ... end
  
  it "emits :error with exception on failure" do ... end
  
  it "preserves lexical environment across calls" do ... end
end
```

### 8.3 Formal Verification Points

```ruby
# Unification engine must satisfy algebraic properties
property "unification is idempotent" do
  for_all(t1: type, t2: type) do |t1, t2|
    u1 = unify(t1, t2)
    u2 = unify(u1, u2) if u1
    u1.should == u2
  end
end

property "unification is commutative" do
  for_all(t1: type, t2: type) do |t1, t2|
    unify(t1, t2).should == unify(t2, t1)
  end
end

property "substitution composition is associative" do
  # (σ₁ ∘ σ₂) ∘ σ₃ = σ₁ ∘ (σ₂ ∘ σ₃)
end
```

---

## 9. Implementation Milestones (TDD Order)

| Phase | Feature | Test File | Implementation | Formal Check |
|-------|---------|-----------|----------------|--------------|
| 0.1 | Expectation-driven lexer | `spec/lexer_expectations_spec.rb` | `patlang-core/lexer/lexer.rb` | Grammar coverage |
| 0.2 | Recursive descent parser | `spec/parser_spec.rb` | `patlang-core/parser/parser.rb` | EBNF conformance |
| 1.1 | Variable binding (IS) | `spec/variables_spec.rb` | `evaluator.rb`, `scope_manager.rb` | Substitution lemma |
| 1.2 | Variable mutation (BECOMES) | `spec/mutation_spec.rb` | `evaluator.rb` | Store update |
| 1.3 | Function literals + calls | `spec/functions_spec.rb` | `function_evaluator.rb` | Closure conversion |
| 1.4 | Control flow | `spec/control_flow_spec.rb` | `control_flow_parser.rb` | CFG construction |
| 2.1 | Event system | `spec/events_spec.rb` | `event_system.rb` | Queue semantics |
| 2.2 | Closures + HOFs | `spec/functional_spec.rb` | `function_evaluator.rb` | Environment capture |
| 3.1 | Goal activation | `spec/goals_spec.rb` | `goal_system.rb` | Dependency resolution |
| 3.2 | Logic unification | `spec/logic_spec.rb` | `unification_engine.rb` | Most general unifier |
| 3.3 | Contracts | `spec/contracts_spec.rb` | `evaluator.rb` | VC generation |
| 4.1 | Modular stdlib | `spec/stdlib_spec.rb` | `CapabilityRegistry` | Feature composition |

---

## 10. Appendix: Token Expectation Matrix

| Parser Context | Expected Tokens | Ambiguity Resolution |
|----------------|-----------------|---------------------|
| Start of statement | MAKE, WHEN, IF, WHILE, FOR, IDENTIFIER (assign), ACTIVATE, QUERY, ASSERT, RETURN | — |
| After `make` | ARTICLE (`a`/`an`) | `a`/`an` → ARTICLE |
| After article | FUNCTION_KW, CLASS_KW, TEMPLATE_KW, GOAL_KW, LIST_KW, TYPE_KW | — |
| After decl type | CALLED | — |
| After `called` | IDENTIFIER | — |
| After function name | `{`, `begin`, NEWLINE | `{` → BLOCK_START |
| In function block | TAKES, RETURNS, REQUIRES, ENSURES, `}` | — |
| After `takes` | `:`, `}` | `:` expected |
| After `:` in params | IDENTIFIER | — |
| After param name | `-`, `,`, `)`, `}` | `-` for type annotation |
| After `-` in param | TYPE_ANNOTATION | — |
| In expression start | LITERAL, IDENTIFIER, `(`, `|`, `[`, `not`, `-` | `|` → LAMBDA_START if expecting block |
| After `when` | IDENTIFIER | — |
| After event name | `:`, `is`, `{`, `begin` | `:` → EVENT_ACTION |
| After `activate` | IDENTIFIER | — |
| After goal name (optional) | `with`, NEWLINE | — |

---

*End of Specification — This document drives TDD implementation. Each section corresponds to executable tests.*