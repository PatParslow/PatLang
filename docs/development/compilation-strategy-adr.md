# Architecture Decision Record: Compilation Strategy Selection

## Status
**PROPOSED** - Awaiting strategic decision approval

## Context

Patlang has reached a critical decision point regarding compilation strategy for achieving self-hosting. With v0.5.0 Functions Week 1 complete and the project ahead of schedule, we must choose the compilation approach that best serves our strategic objectives.

### Current State
- ✅ v0.4.0 String Operations: COMPLETE
- ✅ v0.5.0 Functions Week 1: COMPLETE (ahead of schedule)
- 🔄 Self-hosting timeline: Originally 5-6 months, now 4-5 months achievable
- 📊 Test coverage: 74.55% with excellent quality metrics

### Strategic Requirements
1. **Fastest path to self-hosting**: Achieve language milestone quickly
2. **Maintain development velocity**: Continue rapid feature iteration
3. **Minimize implementation risk**: Choose proven, low-risk approach
4. **Enable future flexibility**: Allow alternative targets post-self-hosting
5. **Align with current codebase**: Leverage existing Ruby implementation (95%+ compatible)

## Decision

**We choose Ruby transpilation as the primary compilation strategy for achieving self-hosting by v0.9.0.**

### Rationale

#### Primary Factors
1. **Implementation Speed**: 2-3 weeks to basic transpilation vs. 3-6 months for native compilation
2. **Risk Mitigation**: Ruby runtime is mature, proven, and compatible with existing codebase
3. **Development Velocity**: Maintains rapid iteration without major architectural shifts
4. **Strategic Timing**: Enables self-hosting achievement while language completeness is the priority

#### Supporting Evidence
- Existing Ruby implementation provides 95%+ translation patterns
- Ruby ecosystem offers excellent debugging and development tools
- Transpilation approach allows incremental validation against Ruby reference
- Post-self-hosting flexibility to add alternative compilation targets

## Alternatives Considered

### Option 1: C Compilation
- **Pros**: Excellent performance, minimal dependencies, universal compatibility
- **Cons**: 2-3 months implementation time, complex memory management, delayed self-hosting
- **Decision**: Defer to post-v1.0.0 for performance-critical applications

### Option 2: LLVM/Native Machine Code
- **Pros**: Maximum performance, advanced optimizations, industry standard
- **Cons**: 4-6 months implementation time, high complexity, significant risk
- **Decision**: Defer to v2.0+ for ultimate performance targets

### Option 3: .NET IL Compilation
- **Pros**: Enterprise integration, excellent tooling, cross-platform
- **Cons**: 3-4 months implementation, platform dependency, learning curve
- **Decision**: Consider for v1.2.0 enterprise integration

### Option 4: JVM Bytecode Compilation
- **Pros**: Java ecosystem integration, mature JIT, rich libraries
- **Cons**: 3-4 months implementation, JVM dependency, memory overhead
- **Decision**: Consider for v1.3.0 Java ecosystem integration

## Implementation Plan

### Phase 1: Ruby Transpilation Foundation (v0.5.0 - v0.9.0)

#### v0.5.0 Functions (3 weeks remaining)
- Complete natural language function syntax
- Establish function transpilation patterns
- Test Ruby code generation for functions

#### v0.6.0 Arrays (3-4 weeks)
- Implement collection data structures
- Array transpilation to Ruby arrays
- Token and AST storage capabilities

#### v0.7.0 File I/O (3-4 weeks)
- Source file reading and processing
- Output file generation for transpiled code
- File-based compilation workflow

#### v0.8.0 Objects (4-5 weeks)
- Class and object system implementation
- Clean AST node hierarchy in Patlang
- Object-oriented transpilation patterns

#### v0.9.0 Self-Hosting (3-4 weeks)
- Complete Patlang-in-Patlang lexer, parser, evaluator
- Ruby code generator implemented in Patlang
- Bootstrap validation and cross-verification
- **Self-hosting milestone achieved**

### Phase 2: Alternative Targets (Post-v1.0.0)

#### Prioritized Implementation Order
1. **C Backend (v1.1.0)**: Performance optimization, 2-3 months
2. **.NET IL (v1.2.0)**: Enterprise integration, 3-4 months  
3. **JVM Bytecode (v1.3.0)**: Java ecosystem, 3-4 months
4. **LLVM Backend (v2.0.0)**: Maximum performance, 4-6 months

## Success Criteria

### Ruby Transpilation Success Metrics

#### Functional Requirements
- [ ] All Patlang language features transpile correctly to valid Ruby
- [ ] Generated Ruby code is readable and maintainable
- [ ] Performance within 10x of hand-written Ruby (acceptable for development)
- [ ] Complete test suite passes on transpiled code without modification

#### Self-Hosting Validation
- [ ] Patlang lexer implemented in Patlang successfully compiles itself
- [ ] Patlang parser implemented in Patlang successfully compiles itself  
- [ ] Ruby code generator implemented in Patlang successfully compiles itself
- [ ] Bootstrap process completes automatically without manual intervention
- [ ] Generated Ruby functionally equivalent to hand-written Ruby implementation

#### Quality Assurance
- [ ] Generated Ruby code follows Ruby community best practices
- [ ] Error messages and stack traces map clearly back to Patlang source
- [ ] Debugging workflow through Ruby tools is effective
- [ ] Performance profiling identifies optimization opportunities

### Timeline Success Metrics
- [ ] v0.9.0 self-hosting achieved by November 2025
- [ ] Development velocity maintained throughout implementation
- [ ] No major architectural rework required
- [ ] Feature development continues during transpilation implementation

## Consequences

### Positive Consequences
1. **Rapid Self-Hosting**: Achieves strategic milestone 3-6 months faster than alternatives
2. **Maintained Velocity**: Development continues at current pace
3. **Risk Mitigation**: Proven Ruby runtime eliminates technology risk
4. **Ecosystem Benefits**: Access to Ruby gems and tools during development
5. **Future Flexibility**: Foundation established for alternative compilation targets

### Negative Consequences
1. **Runtime Dependency**: Generated code requires Ruby installation
2. **Performance Overhead**: Interpreted language performance characteristics
3. **Deployment Complexity**: Ruby ecosystem dependencies must be managed

### Risk Mitigation Strategies
1. **Performance Monitoring**: Establish benchmarks and optimization targets
2. **Incremental Validation**: Test each language feature against Ruby reference
3. **Alternative Target Planning**: Prepare for post-self-hosting compilation options
4. **Deployment Solutions**: Document Ruby dependency management strategies

## Monitoring and Review

### Key Performance Indicators
- **Implementation Speed**: Weeks to basic transpilation functionality
- **Code Quality**: Generated Ruby readability and maintainability scores
- **Performance Overhead**: Transpiled vs. hand-written Ruby benchmarks
- **Self-Hosting Timeline**: Progress toward v0.9.0 milestone

### Review Points
1. **v0.5.0 Completion**: Evaluate function transpilation patterns
2. **v0.7.0 Completion**: Assess file I/O and compilation workflow
3. **v0.9.0 Completion**: Validate self-hosting achievement
4. **Post-v1.0.0**: Consider alternative compilation targets based on use cases

### Decision Reversal Criteria
- Implementation time exceeds 6 weeks for basic transpilation
- Performance overhead exceeds 20x of hand-written Ruby
- Ruby ecosystem dependencies become unmanageable
- Self-hosting timeline extends beyond December 2025

## Documentation and Communication

### Stakeholder Communication
- **Development Team**: Technical implementation details and timelines
- **Users**: Deployment requirements and Ruby dependency management
- **Community**: Strategic direction and alternative target roadmap

### Documentation Requirements
- [ ] Ruby transpilation implementation guide
- [ ] Generated code examples and patterns
- [ ] Performance benchmarking methodology
- [ ] Alternative target evaluation framework

---

**Decision Made**: June 1, 2025  
**Decision Maker**: Development Team  
**Review Date**: Post-v0.9.0 Self-Hosting Achievement  
**Document Status**: Proposed - Awaiting Approval  

This ADR establishes Ruby transpilation as the strategic path to self-hosting while providing clear criteria for success, risk mitigation, and future alternative target implementation. The decision prioritizes rapid self-hosting achievement while maintaining development velocity and minimizing implementation risk.