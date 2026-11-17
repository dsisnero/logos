# Logos for Crystal

A fast lexer generator for Crystal, ported from Rust's [Logos](https://github.com/maciejhirsz/logos) library.

## Overview

Define tokens in a `Logos.define` block or with enum annotations. The macros generate the lexer API, and the runtime builds its matcher on first use. The optional `logos-codegen` target emits a matcher before application compilation.

This is a Crystal port of the Rust Logos library, aiming to provide similar functionality and performance characteristics while following Crystal idioms.

## Features

- **Zero-copy parsing** - Work with slices of your input
- **Built-in error recovery** - Skip invalid tokens and continue parsing
- **Token disambiguation** - Automatic priority resolution for overlapping patterns
- **UTF-8 safe** - Proper handling of Unicode boundaries
- **Crystal implementation** - Uses the `regex-automata` and `regex-syntax` shards
- **Source prebuild** - Generate a matcher before compiling the application

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
  token "fn", :KeywordFn
  token "let", :KeywordLet

  regex "[a-zA-Z_][a-zA-Z0-9_]*", :Identifier
  regex "[0-9]+", :Number

  token "+", :Plus
  token "-", :Minus
  token "=", :Assign

  skip_regex "\\s+"
end

lexer = Token.lexer("fn hello = 42")

lexer.each do |result|
  if result.error?
    puts "Unexpected input at #{lexer.span}: #{lexer.slice}"
  else
    puts "#{result.unwrap}: #{lexer.slice}"
  end
end
```

Pass a block to an anonymous skip to update lexer extras as it consumes input.
Use `lexer.spanned.each` when you need results paired with byte spans.

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
- Ambiguous explicit priorities and duplicate winning rules for one variant raise a matcher initialization or prebuild error.
- Distinct variants with implicit tied priorities retain declaration-order selection. See the [parity plan](plans/parity.md#intentional-divergences) for the exact policy.

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

## Typed callback payloads

Declare `payload:` on an emitting rule to return the captured value directly.
The lexer compiler checks the callback's return type, and the generated
accessor reads the value from the saved result even after the lexer advances.

```crystal
Logos.define Token do
  skip_regex "[ ]+"
  regex "[0-9]+", :Integer, payload: Int64 do |lex|
    lex.slice.to_i64
  end
end

first, second = Token.lex_all("42 7")
Token.integer_value!(first)  # => 42
Token.integer_value!(second) # => 7
```

Use `payload:` with `Logos::Token` and `Logos::Regex` annotations as well.
Use the same payload type spelling when several rules emit the same variant.
An accessor raises if given an error or a result for a different variant.
For callbacks that can skip or return a lexing error, use an untyped rule
and return `Logos::FilterResult::Emit.new(value)`, `Logos::FilterResult::Skip.new`,
or `Logos::FilterResult::Error.new(error)` as appropriate. Read a value from
those rules with `result.payload_for!(Token::Integer, Int64)`.

## Prebuilt matchers

In a Logos checkout, export the manifest from the extras lexer declaration and build the application:

```bash
shards install --frozen
shards build logos-codegen
mkdir -p temp
crystal eval 'require "./examples/lexers/extras"; Token.write_prebuild_manifest(STDOUT)' > temp/extras.json
bin/logos-codegen --manifest temp/extras.json --out temp/generated_token.cr
CRYSTAL_PATH="$PWD/temp:$(crystal env CRYSTAL_PATH)" \
  crystal build -Dprecompiled examples/extras.cr -o temp/extras
```

Run `temp/extras` with a file path to report word positions. Exported manifests
validate their rule bindings against the same declaration at runtime. See the
[development guide](docs/development.md#prebuilding-lexer-matchers) for manifest
options and the generated/runtime verification gates.

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

Parity targets Rust `logos` v0.16.1 (`c7d40fa`). The source and test inventories
record the verified behavior and intentional Crystal differences. Runtime,
prebuild, and shipped strict manifest checks have dedicated gates.

The detailed records are available here:

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

# Verify shipped generated matchers
make test-prebuilt

# Qualify a frozen package and its built CLI from cached dependencies
make test-package

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
