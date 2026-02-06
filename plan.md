# Logos Crystal Port - Implementation Plan

## 1. Project Overview

**Goals:**
- Port Rust's logos library to Crystal with similar API semantics and performance characteristics
- Create a compile-time lexer generator that produces optimized deterministic finite automata (DFA)
- Maintain feature parity with Rust version (tokens, regex patterns, callbacks, extras, custom errors)
- Provide an idiomatic Crystal API that leverages Crystal's strengths while respecting its constraints

**Success Criteria:**
- All Rust test cases pass in Crystal implementation
- Performance within 2x of Rust implementation for comparable workloads
- API feels natural to Crystal developers while maintaining logos philosophy
- Compile-time validation and helpful error messages

## 2. Architecture Analysis of Rust Logos

### Key Components
1. **`Logos` trait** - Implemented by token enums, defines lexing behavior
2. **`Source` trait** - Abstraction over input types (`&str`, `&[u8]`)
3. **`Lexer` struct** - Stateful iterator that produces tokens
4. **`logos-derive`** - Procedural macro attribute `#[derive(Logos)]`
5. **`logos-codegen`** - DFA construction and code generation engine
6. **`logos-cli`** - Optional command-line tool for code inspection

### Code Generation Pipeline
```
Token Enum Definition 
  → logos-derive (attribute parsing) 
  → logos-codegen (pattern compilation)
  → NFA construction (regex-automata) 
  → DFA optimization 
  → Rust code generation
  → Compiled lexer
```

### Performance Optimizations
- **Compile-time DFA construction** - All regex compilation happens during compilation
- **Lookup tables** - 256-byte arrays for dense state transitions
- **Byte classification** - Group bytes with identical next states
- **Fast loops** - Loop unrolling for self-transitions
- **Batch reads** - Minimize bounds checking via `read::<&[u8; N]>()`
- **Early acceptance** - States where all children accept the same token

## 3. Crystal Language Assessment

### Strengths for Port
- **Macro system** - Can parse AST and generate code at compile time (though less powerful than Rust's procedural macros)
- **Compile-time execution** - Can run arbitrary Crystal code during compilation
- **String handling** - Built-in UTF-8 support with efficient slicing
- **Type system** - Union types can handle variant returns elegantly

### Challenges
- **No procedural macros** - Cannot use `#[derive(Logos)]` attribute syntax directly
- **Limited unsafe operations** - Crystal's safety model restricts pointer arithmetic
- **Different regex engine** - Crystal's stdlib `Regex` uses PCRE, not DFA-based
- **GC vs ownership** - Reference counting vs borrow checker affects memory patterns

### API Design Constraints
Crystal doesn't support:
- Custom derive attributes
- Generic associated types (GATs)
- Trait objects with associated types
- Unsafe pointer operations without `unsafe` blocks (which are more restricted)

## 4. Design Decisions

### API Design Options

**Option 1: Annotation-based (Recommended)**
```crystal
@[Logos::Lexer]
enum Token
  @[Logos::Token("fast")]
  Fast
  
  @[Logos::Token(".")]
  Period
  
  @[Logos::Regex("[a-zA-Z]+")]
  Text
  
  @[Logos::Skip(" |abc")]
  Ignored
end
```

**Option 2: Macro DSL**
```crystal
Logos.define_lexer Token do
  token "fast", Fast
  token ".", Period
  regex "[a-zA-Z]+", Text
  skip " |abc", :ignored
end
```

**Option 3: Mix of both**
```crystal
class Token
  extend Logos::Lexer
  
  token "fast", Fast
  token ".", Period
  regex "[a-zA-Z]+", Text
end
```

**Recommendation**: Option 1 (annotation-based) as it:
- Most closely matches Rust semantics
- Leverages Crystal's annotation system
- Provides clear type definitions
- Allows for compile-time validation

### Source Abstraction Design
```crystal
module Logos::Source
  abstract def slice(range : Range(Int32, Int32)) : String | Bytes
  abstract def read(offset : Int32, size : Int32) : Bytes?
  abstract def length : Int32
  abstract def is_boundary(index : Int32) : Bool
end

# Implementations for String and Bytes
class String
  include Logos::Source
  # ...
end

struct Bytes
  include Logos::Source
  # ...
end
```

### DFA Construction Strategy

**Approach**: Port essential parts of `regex-automata` logic to Crystal
- Implement NFA construction from regex patterns
- Build DFA with subset construction algorithm
- Apply optimization passes (dead state elimination, state merging)
- Generate Crystal code with lookup tables and transition logic

**Alternative**: Use Crystal's `Regex` engine for pattern matching but build custom DFA
- Parse regex with Crystal's `Regex::Parser` (if available)
- Convert to custom NFA representation
- Proceed with DFA construction as above

### Error Handling Approach
```crystal
# Custom errors via union types
alias LexerResult = Token | LexerError

enum LexerError
  InvalidToken
  CustomError(MyErrorType)
end

# Or use exception hierarchy
class LexerError < Exception
  # ...
end
```

### Callback System Design
```crystal
@[Logos::Regex("[0-9]+")]
def number_token(lexer : Lexer) : UInt64?
  lexer.slice.to_u64?
end

@[Logos::Regex("[a-z]+", callback: :process_text)]
def text_token(lexer : Lexer) : String
  lexer.slice.downcase
end
```

## 5. Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
- [ ] Set up Crystal project structure mirroring Rust layout
- [ ] Implement `Logos::Source` trait and implementations for `String`/`Bytes`
- [ ] Create `Lexer` base class with iterator interface
- [ ] Implement `Span` type and basic position tracking
- [ ] Write basic spec tests for core functionality

### Phase 2: Pattern Compilation (Weeks 3-4)
- [ ] Design pattern representation (literal tokens, regex patterns)
- [ ] Implement token literal compilation to byte sequences
- [ ] Create regex parser (or adapt Crystal's regex syntax)
- [ ] Build NFA construction from patterns
- [ ] Implement priority system for disambiguation

### Phase 3: DFA Construction (Weeks 5-6)
- [ ] Port subset construction algorithm from Rust
- [ ] Implement DFA optimization passes
- [ ] Create byte classification and lookup table generation
- [ ] Design state machine representation for code generation
- [ ] Add validation for no backtracking, no empty matches

### Phase 4: Macro/Annotation Processor (Weeks 7-8)
- [ ] Create macro that reads enum annotations
- [ ] Parse `@[Logos::Token]`, `@[Logos::Regex]`, `@[Logos::Skip]` attributes
- [ ] Generate lexer class with DFA-based `next_token` method
- [ ] Implement compile-time error reporting for invalid patterns
- [ ] Test with simple token definitions

### Phase 5: Advanced Features (Weeks 9-10)
- [ ] Implement callback system with block support
- [ ] Add `extras` functionality for lexer context
- [ ] Support custom error types and error propagation
- [ ] Implement `Filter` and `FilterResult` equivalents
- [ ] Add `logos::skip` helper function

### Phase 6: Performance Optimizations (Weeks 11-12)
- [ ] Implement fast loops and loop unrolling
- [ ] Optimize lookup table generation for common cases
- [ ] Add batch reading for multi-byte patterns
- [ ] Profile and benchmark against Rust implementation
- [ ] Memory usage optimization

### Phase 7: Test Porting and Validation (Weeks 13-14)
- [ ] Port all Rust integration tests to Crystal spec
- [ ] Port UI tests (compile-fail scenarios)
- [ ] Port example applications (brainfuck, calculator, JSON)
- [ ] Create comprehensive documentation
- [ ] Performance benchmarking suite

## 6. Testing Strategy

### Test Categories
1. **Unit Tests** - Individual components (Source, Lexer, DFA construction)
2. **Integration Tests** - Full lexer behavior (port Rust's `tests/tests/`)
3. **UI Tests** - Compile-time error messages (port Rust's `tests/ui/`)
4. **Example Tests** - Example applications from Rust
5. **Performance Tests** - Benchmarks comparing to Rust

### Test Porting Approach
- Maintain exact test assertions from Rust
- Adapt Rust-specific idioms to Crystal equivalents
- Use `pending` for tests requiring features not yet implemented
- Verify behavior matches Rust implementation exactly

### Validation Methodology
1. **Behavioral equivalence** - Same input → same tokens (modulo type differences)
2. **Performance targets** - Within 2x of Rust speed for benchmark cases
3. **Memory safety** - No memory leaks, proper bounds checking
4. **UTF-8 correctness** - Proper handling of Unicode boundaries

## 7. Performance Considerations

### Critical Optimizations to Preserve
1. **Compile-time DFA construction** - Must happen during compilation
2. **Lookup tables** - Essential for dense state transitions
3. **Byte classification** - Reduces transition table size
4. **Minimal bounds checking** - Batch reads where possible
5. **Cache locality** - Pack transition tables efficiently

### Crystal-Specific Optimizations
1. **Use `Pointer` for unsafe operations** where performance critical
2. **Leverage Crystal's `String` byte indexing** for UTF-8 safety
3. **Precompute character classes** using Crystal's `Char` utilities
4. **Use `StaticArray` for fixed-size lookup tables**

### Expected Performance Profile
- **Worst-case**: 3-5x slower than Rust (GC overhead, safer bounds checking)
- **Best-case**: 1.5-2x slower than Rust (optimized hot paths)
- **Memory usage**: Similar to Rust for DFA tables, higher for runtime due to GC

## 8. Risks and Mitigations

### Technical Risks
1. **DFA construction complexity** - Regex to DFA algorithm is non-trivial
   - *Mitigation*: Start with simplified NFA/DFA, iterate
   - *Fallback*: Use Crystal's Regex engine with custom matching logic

2. **Macro limitations** - Crystal macros may not support needed AST transformations
   - *Mitigation*: Prototype macro early to validate approach
   - *Fallback*: Use code generation via separate compilation step

3. **Performance gaps** - Crystal's GC and safety may limit optimization
   - *Mitigation*: Focus on algorithmic optimizations first
   - *Fallback*: Accept reasonable performance degradation (2-3x)

### Timeline Risks
- **Estimated duration**: 14-16 weeks for complete port
- **Critical path**: DFA construction and code generation
- **Buffer**: Add 4 weeks for unexpected complexities

### Quality Risks
1. **Behavioral differences** - Crystal's regex semantics may differ from Rust
   - *Mitigation*: Test extensively with edge cases
   - *Documentation*: Clearly document any differences

2. **Memory safety** - Manual memory management in performance-critical sections
   - *Mitigation*: Extensive testing with valgrind/address sanitizer
   - *Code review*: Careful review of unsafe blocks

## 9. Success Metrics

### Primary Metrics
- ✅ All ported Rust tests pass
- ✅ Performance within 2x of Rust for benchmark suite
- ✅ API feels idiomatic to Crystal developers
- ✅ Comprehensive documentation and examples

### Secondary Metrics
- ✅ Compile-time error messages are helpful
- ✅ Memory usage is reasonable for typical workloads
- ✅ Library is usable without understanding internal DFA details
- ✅ Easy integration with existing Crystal projects

## 10. Next Steps

### Immediate Actions (Week 1)
1. **Set up development environment** with proper tooling
2. **Create detailed issue tracking** in beads for each phase
3. **Implement Phase 1 foundation** (Source, Lexer, Span)
4. **Establish testing framework** with initial specs
5. **Begin Rust test analysis** for behavioral specification

### Decision Points
- **Week 4**: Evaluate DFA construction approach feasibility
- **Week 8**: Assess macro system limitations and adjust design
- **Week 12**: Review performance benchmarks and optimization needs

### Deliverables
- **Weekly**: Progress updates with completed tasks
- **Phase gates**: Review and validation at each phase completion
- **Final**: Production-ready Crystal logos library with full documentation

---

*This plan provides a comprehensive roadmap for porting Rust's logos library to Crystal while addressing the unique constraints and opportunities of the Crystal language. The approach balances fidelity to the original design with pragmatic adaptation to Crystal's capabilities.*