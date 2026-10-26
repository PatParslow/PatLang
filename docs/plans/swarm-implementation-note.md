Below is a self-contained implementation note intended to sit immediately after the previous independent-object compilation description. It clarifies that the model is a compilation discipline, not a restricted subset of PatLang, and gives the local agent concrete rules for handling dynamic or imprecise programs.

Implementation Note: Expressiveness, Dynamic Behaviour, and Contract Precision
Purpose

Independent object compilation must not require user programs to be statically predictable, pure, closed-world, or formally verified.

The core implementation rule is:

An object implementation may observe another object only through a contract available in its compilation environment.

This rule constrains the compiler’s representation of dependencies. It should not unnecessarily constrain the behaviour that a user can express.

A user program may remain dynamic, reflective, stateful, concurrent, self-modifying, synthesised, or dependent on external resources. Where the compiler cannot determine precise behaviour statically, it must use a broader contract and preserve the relevant operation for runtime resolution.

The guiding policy is:

Imprecision reduces static guarantees and optimisation opportunities. It does not, by itself, make a program invalid.

1. Compile object implementations, not runtime instances

“Every object is independently compilable” refers to each distinct object implementation, not necessarily every runtime instance.

For example, ten thousand instances of Account should normally share one compiled implementation. Each instance carries or references its own state, identity, behaviour descriptor, and applicable contract.

A runtime representation might conceptually contain:

RuntimeObject {
    identity
    implementation_reference
    contract_reference
    state
    ownership_metadata
}


Anonymous objects, closures, generated implementations, and runtime-synthesised behaviour may cause the compiler to create new implementation objects. These can then be compiled using the same contract-directed protocol.

Do not generate a separate copy of identical machine code merely because multiple runtime objects instantiate the same implementation.

2. Distinguish three levels of contract

Do not treat every contract clause as a mandatory static proof obligation. Separate contracts into three levels.

2.1 Minimal compilation contract

This is the minimum information necessary to compile an object and its consumers independently.

It should include, as applicable:

operation identities;
argument and result boundary representations;
dispatch protocol;
generic or dynamic value handling;
basic ownership transfer rules;
failure and exception protocol;
target boundary ABI;
required imported contracts.

Every independently compiled object must have this level of contract. It may be explicitly written or inferred.

2.2 Analysis contract

This provides additional information for checking and optimisation:

effects;
mutation;
aliasing;
identity observability;
closure captures;
concurrency behaviour;
capabilities;
allocation behaviour;
thread or actor affinity;
serialisability and transferability.

Analysis contracts may be precise or conservative.

For example:

effects {
    reads self.items
    writes self.cache
}


is more precise than:

effects {
    arbitrary
}


Both should be valid. The latter permits fewer optimisations and provides weaker guarantees.

2.3 Behavioural contract

This contains semantic claims such as:

preconditions;
postconditions;
invariants;
protocol-state transitions;
temporal requirements;
domain-specific assertions.

For example:

ensures sort {
    result is_sorted
    result is_permutation_of input
}


The implementation must not assume that every behavioural condition can be proved statically. Behavioural obligations may be:

statically proved
runtime checked
verified by generated tests
verified by supplied evidence
trusted
assumed
unsafe


The compiled-object artefact must record the assurance level of each externally relevant obligation.

Independent compilation requires a stable boundary. It does not require the compiler to decide every semantic property of the implementation.

3. Allow conservative contracts

When precise analysis is unavailable, infer or accept a conservative contract.

For example, an implementation using reflection, dynamic invocation, or generated code may have:

contract DynamicPlugin {
    operation invoke(input: Dynamic) -> Dynamic

    effects {
        arbitrary
    }

    capabilities {
        dynamic_dispatch
        runtime_compilation
    }

    failure {
        dynamic
    }
}


This contract provides less information than a fully typed and effect-annotated alternative, but remains a usable compilation boundary.

The compiler should respond to imprecision by using:

dynamic dispatch;
boxed or tagged values;
runtime contract checks;
conservative ownership operations;
capability checks;
indirect calls;
broader cache invalidation;
reduced optimisation.

It should not reject the program solely because the program is dynamic.

4. Make ambient dependencies explicit in lowered form

User-level syntax may remain convenient. Users should not have to pass a verbose environment object through every operation manually.

However, ambient facilities must become explicit dependencies before independent compilation.

For example:

let contents = read_file(path)


may lower conceptually to:

let contents = current_context.filesystem.read(path)


The implementation’s contract would then record a filesystem capability:

capabilities {
    filesystem.read
}


Apply the same principle to:

environment variables;
process execution;
clocks;
random-number generation;
network access;
consoles;
logic stores;
GOAP planners;
event registries;
message queues;
runtime compilers;
reflection facilities.

This does not require verbose source syntax. It requires that the compiler make the dependencies explicit in the resolved object IR.

No dependency should remain compiler magic if it can instead be represented as access to a runtime object or capability.

5. Treat reflection as a contracted capability

Reflection does not conflict with independent compilation if the reflected information is part of an explicit contract.

A reflectable object may provide operations such as:

contract Reflectable {
    describe() -> ObjectDescription

    read_member(
        name: Symbol
    ) -> Dynamic

    invoke(
        name: Symbol,
        arguments: List[Dynamic]
    ) -> Dynamic
}


The compiler should distinguish at least three forms of reflection:

Contract reflection

The caller may inspect the target’s public contract.

This is compatible with representation independence and should normally be safe.

Exported implementation reflection

The target explicitly exports selected implementation metadata.

Changes to exported metadata may invalidate dependants.

Unsafe representation inspection

The caller may examine private layouts, raw memory, compiler IR, or machine-code details.

This can be supported through an explicit unsafe capability:

requires capability UnsafeObjectInspection


An object using this capability depends on the observed representation, not merely the target’s public contract. The compiler should record that stronger dependency and invalidate or relink the consumer when the observed representation changes.

Do not silently treat private representation inspection as ordinary contract access.

6. Support runtime compilation and evaluation

Runtime-generated code does not need to exist during ahead-of-time compilation.

An operation such as:

eval(source_text)


should lower to interaction with a compiler object and an explicit compilation environment.

Conceptually:

let source = SourceObject(source_text)

let compiled =
    runtime_compiler.compile(
        source,
        expected_contract,
        available_contracts,
        runtime_target
    )

compiled.instantiate()


The enclosing object can be compiled independently. The generated object is compiled later using the same object-compilation protocol.

A runtime compilation request must identify:

source or implementation object;
expected contract, if any;
imported contracts;
accessible capabilities;
syntax environment;
semantic version;
target contract;
verification policy.

Dynamically generated code must not inherit arbitrary compiler state implicitly. Any inherited environment must be represented as part of the compilation request or runtime context.

7. Support replacement and monkey-patching through explicit late binding

Runtime replacement of behaviour is compatible with independent compilation, but only where the relevant contract permits replacement.

For a replaceable operation, compile calls through a stable contract-level indirection:

contract operation identity
        ↓
current implementation binding
        ↓
compiled operation


This permits:

replace Account.withdraw with checked_withdraw


without recompiling every caller.

Where a contract declares an operation immutable or statically bound, the compiler may use a direct call.

The contract therefore needs a binding policy such as:

binding static
binding replaceable
binding per-instance
binding dynamic


The consequences are:

static permits aggressive inlining and direct calls;
replaceable requires a patchable binding;
per-instance requires object-specific behaviour lookup;
dynamic may require symbolic lookup at each call.

Do not reject monkey-patching merely because it prevents static binding. Preserve it through the appropriate dispatch mechanism.

Physical rewriting of arbitrary machine code may be supported separately as an unsafe runtime capability. It should not be confused with semantic replacement through object contracts.

8. Distinguish open and sealed contracts

Some user programs require exhaustive knowledge of possible implementations. Others require open extension.

These are incompatible assumptions and must be declared rather than guessed.

A sealed contract may identify its permitted implementations:

sealed contract Account {
    permits SavingsAccount
    permits BusinessAccount
    permits StudentAccount
}


The compiler may permit exhaustive matching over a sealed contract.

An open contract permits additional implementations:

open contract Account {
    operation balance() -> Money
}


Matching over an open contract must include a fallback or explicitly dynamic case:

match account {
    SavingsAccount => ...
    BusinessAccount => ...
    otherwise => ...
}


Open extension remains available. It simply prevents the compiler from assuming that the currently visible implementations are exhaustive.

9. Keep equality separate from identity

If runtime identity is observable, the compiler must preserve it.

PatLang should distinguish operations equivalent to:

a == b


and:

a is_same_object_as b


The first may represent value or contract-defined equality. The second represents runtime identity.

Contracts should be able to state an identity policy:

identity observable
identity value
identity opaque


An object with value identity may be copied, unboxed, interned, or deduplicated when behaviour remains unchanged.

An object with observable identity must retain a stable identity even if its representation is optimised.

This limits particular optimisations but does not limit what the user can express.

10. Do not require runtime objects to be serialisable

Distributed compilation does not imply that every runtime object must be transferable between compiler workers or runtime processes.

Some objects may be explicitly host-local:

contract NativeFileHandle {
    location host_local
    transferable false
    serialisable false
}


Examples include:

open file handles;
sockets;
operating-system process handles;
process-local pointers;
handles owned by foreign libraries;
callbacks into a host runtime;
thread-affine UI objects.

Such objects remain valid PatLang objects. They cannot be moved to a context in which their contract cannot be satisfied.

Compiler workers should ordinarily receive source objects, resolved IR, contracts, target descriptions, and immutable compilation inputs. They should not require arbitrary live runtime objects to be serialisable.

11. Represent foreign code with explicit boundary contracts

Calling externally compiled code remains permitted.

Foreign declarations must describe enough of the boundary to call the external implementation safely, or explicitly mark the boundary unsafe.

For example:

foreign object DatabaseConnection {
    abi c
    library "sqlite3"

    operation open(
        filename: CString,
        output: OutPointer
    ) -> Status

    ownership {
        filename borrowed
        output initialised_on_success
    }

    effects {
        filesystem
        allocation
    }
}


The compiler cannot infer the true ownership, effects, and behavioural properties of arbitrary machine code. Incorrect declarations must therefore be treated similarly to unsafe foreign declarations in other systems.

Foreign code does not violate the object model. It is represented by an object whose implementation lies outside the PatLang compiler and whose boundary is described by a PatLang contract.

12. Compile closures using explicit environment objects

A closure should be lowered to an implementation object plus an environment object.

For example:

let add_offset = fn(value) {
    value + offset
}


may produce a generated contract equivalent to:

contract GeneratedClosure {
    captures {
        offset: Int by_value
    }

    operation call(
        value: Int
    ) -> Int

    effects {
        pure
    }
}


The compiled closure representation can then contain:

ClosureInstance {
    implementation_reference
    environment {
        offset
    }
}


Where capture behaviour cannot be precisely inferred, use a conservative capture descriptor rather than rejecting the closure.

Capture modes may include:

by_value
shared
borrowed
transferred
mutable_shared
dynamic


The closure implementation is independently compilable once its environment shape and imported contracts are known.

13. Treat logic rules, actions, and handlers as ordinary objects

Avoid hidden global registration semantics.

Represent rules, GOAP actions, event handlers, and similar entities as objects satisfying protocol contracts.

For example:

contract Rule {
    head() -> Pattern
    dependencies() -> List[PredicateContract]
    resolve(bindings: Bindings) -> Stream[Bindings]
}

contract PlanningAction {
    applicable(state: State) -> Bool
    apply(state: State) -> State
    cost(state: State) -> Number
}

contract EventHandler[E] {
    handle(event: E) -> Effect
}


Registration syntax may remain concise:

rule_add(rule)
action_add(action)
when(Event, handler)


but should lower to operations on explicitly available registry objects:

current_rule_space.register(rule)
current_planner.register(action)
current_event_space.register(handler)


The resolved implementation contract should identify those dependencies.

This permits separate compilation without banning familiar PatLang syntax.

14. Infer contracts for local and anonymous objects

Do not require users to write full explicit contracts for every closure, local object, generated helper, or temporary value.

The compiler should infer minimal contracts where safe and practical.

For example:

let double = fn(x) {
    x * 2
}


may receive an inferred contract equivalent to:

contract InferredClosure {
    operation call(x: Number) -> Number

    effects {
        pure
    }

    captures {
        none
    }
}


Explicit contracts are most important when:

separately authored components meet;
implementations are replaceable;
a stable public interface is required;
recursive compilation dependencies exist;
dynamic loading is intended;
another target or process will consume the object;
inferred information would expose private implementation details;
stronger behavioural assurance is desired.

Inference should reduce source boilerplate without weakening the compiled object boundary.

15. Handle recursive dependencies contract-first

Mutually recursive implementations do not necessarily form one compilation unit.

Given:

contract A {
    operation f(value: B) -> Int
}

contract B {
    operation g(value: A) -> Int
}


the compiler may:

compile implementation A against contract B
compile implementation B against contract A
link the resulting compiled objects


The difficulty arises only when the contracts themselves must be inferred recursively.

For recursive contract inference, the compiler may:

calculate a fixed point over the mutually dependent contract descriptions;
require explicit contracts at the recursive public boundary;
infer a conservative dynamic contract;
create a temporary contract group;
report that a more precise contract requires an explicit annotation.

Do not combine implementations into one compilation island merely because their call graph is cyclic. First determine whether the cycle exists in contracts or only in implementations.

16. Make contract compatibility independent of proof strength

Two objects may agree on a calling boundary while providing different levels of assurance.

For example, both may implement:

contract Sorter {
    operation sort(
        values: List[Int]
    ) -> List[Int]

    ensures {
        result is_sorted
        result is_permutation_of values
    }
}


One implementation may carry a static proof. Another may use runtime checks. A third may mark the postcondition as trusted.

The linker or loader should distinguish:

boundary compatibility
behavioural obligation
assurance level
consumer assurance requirement


A consumer may require:

requires boundary contract Sorter
accepts assurance runtime_checked_or_better


or:

requires boundary contract Sorter
requires assurance statically_proved


Independent compilation only requires boundary compatibility unless a consumer or deployment policy explicitly requires stronger assurance.

Do not globally require the strongest possible verification mode.

17. Record the consequences of dynamic features

Dynamic features should produce explicit consequences in the compiled artefact.

Examples:

Broad effects
Consequence:
    cannot reorder across unknown effects
    cannot eliminate apparently unused calls
    must preserve capability boundary

Replaceable operation
Consequence:
    indirect dispatch required
    implementation may not be inlined without a guard

Unsafe representation reflection
Consequence:
    consumer depends on target representation hash
    private layout changes invalidate consumer

Observable identity
Consequence:
    instances cannot be freely deduplicated

Runtime-generated code
Consequence:
    runtime compiler capability required
    generated implementation verified under runtime policy

Open contract
Consequence:
    exhaustive implementation matching unavailable


The compiler should explain these consequences rather than describing the features as incompatible with independent compilation.

18. Required compiled-object metadata

Each compiled object should contain or reference metadata equivalent to:

CompiledObject {
    own_contract_hash
    implementation_hash
    semantic_version
    target_contract_hash
    compiler_contract_hash

    required_contracts
    provided_operations
    required_operations

    binding_policies
    ownership_boundary
    effect_summary
    capability_requirements
    identity_policy

    relocations
    initialisation_requirements

    verification_results
    runtime_checks
    trusted_assumptions
    unsafe_dependencies

    source_map
}


The exact encoding may evolve. The semantic distinction between these fields should remain.

This metadata allows the linker to determine whether two independently compiled objects can interact without inspecting either implementation.

19. Compiler rejection policy

The compiler should reject an object only where it cannot construct a valid execution boundary.

Valid reasons include:

an operation has no callable boundary representation;
ownership obligations are contradictory;
an imported contract cannot be found or generated;
two required contracts are irreconcilably incompatible;
a required capability is prohibited by deployment policy;
the object claims a proof or guarantee that verification disproves;
a sealed contract is implemented by an unauthorised object;
an object requires target behaviour unavailable on the selected target;
an implementation violates a mandatory, statically enforced contract condition.

The following are not sufficient reasons by themselves:

effects are broad;
dispatch is dynamic;
the object uses reflection;
behaviour is generated at runtime;
a postcondition cannot be proved statically;
an object uses mutable state;
identity is observable;
an implementation is replaceable;
foreign code is involved;
the implementation depends on ambient facilities;
contract information is imprecise.

In those cases, use conservative representations, dynamic checks, explicit capabilities, unsafe boundaries, or weaker assurance classifications.

20. Fundamental semantic choices that cannot be avoided

The model preserves broad expressiveness, but it cannot make contradictory promises simultaneously.

The following choices are unavoidable.

Private representation versus direct observation

An object cannot promise both:

my representation is private and independently changeable


and:

other objects may rely directly on my private field offsets


Representation inspection must either be prohibited, exported as part of the contract, or recorded as an unsafe representation dependency.

Open extension versus exhaustive implementation knowledge

A contract cannot be both open to arbitrary future implementations and statically known to have exactly a fixed set of implementations.

Use open and sealed contracts explicitly.

Observable identity versus unrestricted substitution

If users can observe runtime identity, the compiler cannot freely merge or replace distinct instances merely because their values are equivalent.

Dynamic replacement versus permanent direct binding

If behaviour can be replaced at runtime, calls to it require an appropriate late-binding mechanism unless protected by a valid optimisation guard.

Unknown behaviour versus strongest static guarantees

An implementation whose behaviour is genuinely unknown cannot simultaneously receive guarantees that require that behaviour to be known.

The program remains valid, but its assurance and optimisation level must reflect the available information.

These are semantic trade-offs, not arbitrary language restrictions.

21. Definition of a valid PatLang object implementation

An implementation is valid for independent compilation when the compiler can determine:

the object contract it claims to satisfy;
the contracts of its external dependencies;
the operations it exports;
how each boundary operation is invoked;
how values and ownership cross the boundary;
what runtime capabilities must be supplied;
which obligations are static, dynamic, assumed, or unsafe;
which target facilities are required.

The implementation does not need to be:

pure;
deterministic;
statically typed in every internal operation;
serialisable;
free from reflection;
closed to replacement;
statically verified;
known completely at compile time.
22. Implementation principle

The compiler should enforce semantic accountability rather than stylistic notions of “well-written” programs.

Use this rule:

Every external dependency must be named, supplied dynamically, represented by a capability, or conservatively included in the object’s contract.

Even a deliberately unrestricted object can satisfy this rule:

contract UnrestrictedPlugin {
    operation run(input: Dynamic) -> Dynamic

    effects {
        arbitrary
    }

    capabilities {
        filesystem
        network
        process
        reflection
        runtime_compilation
    }

    dispatch {
        dynamic
    }

    verification {
        implementation untrusted
        boundary runtime_checked
    }
}


This is a poor contract for optimisation, isolation, and static reasoning, but it remains a valid contract and a valid independently compiled object.

23. Non-negotiable design rule

Do not implement contract precision as a gate on language expressiveness.

Implement it as a spectrum:

More precise contract
    -> stronger checking
    -> stronger optimisation
    -> smaller recompilation scope
    -> more informative failures
    -> greater deployment confidence

Less precise contract
    -> more runtime mediation
    -> more conservative ownership handling
    -> broader invalidation
    -> fewer optimisation opportunities
    -> weaker static assurance


Both ends of the spectrum must remain programmable.

The compiler’s responsibility is to preserve the declared or inferred semantics at the chosen level of precision.

Conclusion

Independent object compilation should not define a restricted subset of PatLang.

It defines how dependencies are represented:

An object implementation is compiled from its own implementation, its own contract, the contracts it imports, and the target environment. It does not require access to imported implementations.

Highly dynamic programs remain possible. Their compiled representations will use broader contracts, runtime dispatch, explicit capabilities, dynamic checks, or unsafe boundaries where necessary.

The essential implementation policy is:

When static knowledge is insufficient, preserve the operation dynamically. Do not reject it merely because it cannot be resolved, proved, or optimised statically.

