# Architecture

## Overview

Logos for Crystal is a fast lexer generator that creates optimized tokenizers at compile time.
The architecture combines Crystal's macro system with efficient finite automata to provide
zero-copy parsing with minimal runtime overhead.

## Core Components

### 1. Lexer System (`src/logos/lexer.cr`)

The main lexer struct that tokenizes input sources:

- **Generic design**: `Lexer(Token, Source, Extras, Error)` with type-safe parameters
- **Zero-copy parsing**: Works with `Source` slices to avoid allocations
- **Callback system**: `callback_value` stores parsed data for token variants
- **Extras support**: Custom context data passed through parsing

**Key types**:

- `Lexer`: Main lexer class with generic type parameters
- `Span`: `Range(Int32, Int32)` for token position tracking
- `CallbackValue(T)`: Boxed values for token payloads
- `NoExtras`: Default empty extras type

### 2. Annotation System (`src/logos/annotations.cr`)

Crystal annotations for declarative token definitions:

- `@[Logos::Options]`: Class-level options (skip, extras, error_type, utf8)
- `@[Logos::Subpattern]`: Reusable regex subpatterns
- `@[Logos::Token]`: Literal string token patterns
- `@[Logos::Regex]`: Regex token patterns
- `@[Logos::ErrorToken]`: Mark variant as error token
- `@[Logos::SkipToken]`: Mark variant as skip token

### 3. Macro System (`src/logos/macros.cr`, `src/logos/define_macro.cr`)

Compile-time code generation for lexer optimization:

- **`Logos.define` macro**: Main entry point for token definition
- **Pattern compilation**: Transforms annotations into optimized state machines
- **DFA generation**: Creates deterministic finite automata for fast matching
- **Disambiguation**: Resolves overlapping patterns with priority rules

### 4. Result Types (`src/logos/result.cr`)

Rust-inspired result and option types:

- `Result(T, E)`: Similar to Rust's `Result<T, E>` for error handling
- `Option(T)`: Optional value container
- `Filter::Emit(T)` / `Filter::Skip`: Callback return types
- `FilterResult` types: `Emit(T)`, `Skip`, `Error(E)` for extended results

### 5. Pattern System (`src/logos/pattern.cr`, `src/logos/pattern/parser.cr`)

Regex pattern parsing and compilation:

- **Pattern parsing**: Converts regex strings to internal representations
- **Character class handling**: Supports Unicode and custom character classes
- **Look-around assertions**: Basic support for word boundaries and anchors
- **Optimization**: Pattern simplification and DFA minimization

## Design Decisions

### Crystal-First Architecture

Unlike a direct port, Crystal Logos embraces Crystal's unique features:

1. **Annotation-based API**: Uses Crystal's annotation system for declarative definitions
2. **Generic lexer**: Type-safe `Lexer` class with configurable type parameters
3. **Callback values**: Workaround for Crystal's enum payload limitations
4. **Macro-based generation**: Leverages Crystal's powerful macro system

### Performance Strategy

- **Compile-time optimization**: Pattern logic generated at compile time
- **Zero allocations**: Works with source slices, avoids string copying
- **DFA-based matching**: Deterministic finite automata for O(n) tokenization
- **Inline caching**: Frequently used paths optimized with inline expansions

### Error Handling

- **Configurable error types**: User-defined error enums via `error_type` option
- **Error tokens**: Special token variants for parse errors
- **Skip tokens**: Automatic skipping of whitespace/comments
- **Result types**: Rust-inspired `Result` and `Option` for callback returns

## Core Data Flow

```text
Input Source → Lexer.next() → Token Enum + Callback Value
     ↓               ↓               ↓
  String       State Machine     Payload Data
  Slice           Matching      (via callback_value)
```

1. **Source input**: String or byte slice passed to lexer
2. **Pattern matching**: DFA determines which token pattern matches
3. **Callback execution**: Optional callback processes matched text
4. **Value storage**: Callback result stored in `lexer.callback_value`
5. **Token return**: Enum variant returned from `lexer.next()`

## Directory Structure

```text
src/
├── logos.cr                    # Main module entry point
└── logos/                      # Core implementation
    ├── annotations.cr          # Annotation definitions
    ├── define_macro.cr         # Logos.define macro implementation
    ├── lexer.cr               # Lexer class and core logic
    ├── macros.cr              # Supporting macros
    ├── pattern.cr             # Pattern matching utilities
    ├── pattern/parser.cr      # Regex pattern parser
    ├── result.cr              # Result/Option types
    └── source.cr              # Source abstraction

lib/
├── regex-automata/            # Ported regex engine (for advanced features)
└── regex-syntax/              # Regex parsing library

examples/                      # Usage examples
spec/                          # Test suite
vendor/                        # Source language references
```

## Example Usage

```crystal
enum Token
  @[Logos::Token("fn")]
  KeywordFn

  @[Logos::Regex("[a-zA-Z_][a-zA-Z0-9_]*")]
  Identifier

  @[Logos::Regex("[0-9]+")]
  Number
end

lexer = Token.lexer("fn main 123")
lexer.next  # => Token::KeywordFn
lexer.next  # => Token::Identifier
lexer.next  # => Token::Number
lexer.callback_value_as(String)  # => "main" (for Identifier)
```
