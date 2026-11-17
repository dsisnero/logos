# Logos for Crystal

A fast lexer generator for Crystal, ported from Rust's [Logos](https://github.com/maciejhirsz/logos) library.

## Overview

Logos allows you to create fast lexers by defining tokens in a `Logos.define` block. The library generates an optimized lexer at compile time with zero runtime overhead.

This is a Crystal port of the Rust Logos library, aiming to provide similar functionality and performance characteristics while following Crystal idioms.

## Features

- **Zero-copy parsing** - Work with slices of your input
- **Built-in error recovery** - Skip invalid tokens and continue parsing
- **Token disambiguation** - Automatic priority resolution for overlapping patterns
- **UTF-8 safe** - Proper handling of Unicode boundaries
- **No runtime dependencies** - Pure Crystal implementation
- **Fast compile times** - Minimal macro overhead

## Installation

Add this to your `shard.yml`:

```yaml
dependencies:
  logos:
    github: dsisnero/logos
```

Then run:

```bash
shards install
```

## Quick Start

```crystal
require "logos"

Logos.define Token do
  error_type Nil

  token "fn", :KeywordFn
  token "let", :KeywordLet

  regex "[a-zA-Z_][a-zA-Z0-9_]*", :Identifier
  regex "[0-9]+", :Number

  token "+", :Plus
  token "-", :Minus

  skip_regex "\\s+", :Whitespace
end

lexer = Token.lexer("fn hello = 42")

loop do
  result = lexer.next
  break if result.is_a?(Iterator::Stop)
  result = result.as(Logos::Result(Token, Nil))
  puts "#{result.unwrap}: #{lexer.slice}"
end
```

## Context-Dependent Lexing

Use `Lexer#morph` to switch token modes while preserving cursor position.

```crystal
require "logos"

Logos.define OuterToken do
  token "{", :Open
  regex "[^\\{]+", :Text
end

Logos.define InnerToken do
  token "}", :Close
  regex "[^\\}]+", :Body
end

outer = OuterToken.lexer("prefix{inside}suffix")

token = outer.next.as(Logos::Result(OuterToken, Nil))
token.unwrap # => :Text

token = outer.next.as(Logos::Result(OuterToken, Nil))
if token.unwrap == OuterToken::Open
  inner = outer.morph(InnerToken)
  inner_token = inner.next.as(Logos::Result(InnerToken, Nil))
  puts inner_token.unwrap # => InnerToken::Body
end
```

Use `#spanned` when you need `(token, span)` tuples:

```crystal
lexer = OuterToken.lexer("ab{cd}")
lexer.spanned.each do |result, span|
  puts "#{result.unwrap} @ #{span}"
end
```

## Token Disambiguation and Priority

When multiple patterns can match at the same position:

- Logos prefers the longest match.
- If multiple matches have the same length, higher `priority` wins.
- If same-length and same-priority patterns overlap, Logos raises a compile-time diagnostic.

Example:

```crystal
Logos.define Token do
  token "===", :StrictEq
  token "==", :Eq
  token "=", :Assign
  regex "[a-zA-Z_][a-zA-Z0-9_]*", :Ident
end
```

Explicit priorities:

```crystal
Logos.define Token do
  regex "[a-z]+", :Word, priority: 10
  token "if", :If, priority: 50
end
```

If you hit ambiguity diagnostics, either:

- Raise priority for the intended winner, or
- Refine regex patterns so they no longer overlap at equal priority.

## Annotation-based API

For a Rust-style attribute-driven setup, use type-level annotations and `logos_derive`:

```crystal
require "logos"

@[Logos::Options(skip: "\\s+", error: Nil)]
@[Logos::Subpattern("xdigit", "[0-9a-fA-F]")]
@[Logos::Token(:KeywordLet, "let")]
@[Logos::Regex(:Hex, "0x(?&xdigit)+")]
@[Logos::Regex(:Number, "[0-9]+")]
enum Token
  KeywordLet
  Hex
  Number
end

logos_derive(Token)

lexer = Token.lexer("let 0x10 42")
```

Notes:

- Crystal cannot introspect per-enum-variant annotations the same way Rust proc-macros do, so mappings are declared at the enum type level.
- `Logos::Token` and `Logos::Regex` support both `(:Variant, "pattern")` and `(pattern, variant: :Variant)` forms.

### Subpatterns

```crystal
Logos.define Token do
  error_type Nil

  subpattern :xdigit, "[0-9a-fA-F]"
  regex "0[xX](?&xdigit)+", :Hex
end
```

## Examples

Crystal ports of the Rust Logos examples are available in `examples/`:

- `examples/brainfuck.cr`
- `examples/calculator.cr`
- `examples/custom_error.cr`
- `examples/extras.cr`
- `examples/json.cr`
- `examples/json_borrowed.cr`
- `examples/string_interpolation.cr`
- `examples/token_values.cr`

## Porting Status

This is a Crystal port, so parity with Rust `logos` is tracked separately from
the user-facing API:

- Current parity state and roadmap: [plans/parity.md](plans/parity.md)
- Handbook topic → spec mapping, Rust UI error parity table, and dependency
  status: [docs/development.md](docs/development.md#porting-status-and-parity-index)
- Enum payload plan: [docs/enum_payload_parity.md](docs/enum_payload_parity.md)

## Documentation

For detailed documentation on development, architecture, and contributing:

- **[Resuming Work](docs/resuming.md)** - Start here in a new session: state, baseline, next feature
- **[Architecture](docs/architecture.md)** - System architecture and design decisions
- **[Development Guide](docs/development.md)** - Development workflow and setup
- **[Coding Guidelines](docs/coding-guidelines.md)** - Code style and conventions
- **[Testing Strategy](docs/testing.md)** - Testing patterns and porting guidelines
- **[PR Workflow](docs/pr-workflow.md)** - Pull request and review process
- **[Enum Payload Parity](docs/enum_payload_parity.md)** - Plan for enum payload support
- **[DFA Parity Fix](docs/dfa-parity-fix.md)** - DFA dependency fix evidence and upstream review

## Development

```bash
# Install dependencies
make install

# Update dependencies
make update

# Format code
make format

# Lint code
make lint

# Run tests
make test

# Format markdown
make markdown

# Check markdown formatting
make markdown-check

# Clean temporary files
make clean
```

## Contributing

1. Fork it (<https://github.com/dsisnero/logos/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT - see LICENSE file

## Acknowledgments

- [maciejhirsz/logos](https://github.com/maciejhirsz/logos) - The original Rust implementation
- [BurntSushi/regex-automata](https://github.com/BurntSushi/regex-automata) - Rust regex engine used as reference
- [rust-lang/regex](https://github.com/rust-lang/regex) - Rust regex library used as reference
