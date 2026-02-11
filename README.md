# Logos for Crystal

A fast lexer generator for Crystal, ported from Rust's [Logos](https://github.com/maciejhirsz/logos) library.

## Overview

Logos allows you to create fast lexers by defining tokens in a `Logos.define` block. The library generates an optimized lexer at compile time with zero runtime overhead.

This is a Crystal port of the Rust Logos library, aiming to provide similar functionality and performance characteristics while following Crystal idioms.

## Features

* **Zero-copy parsing** - Work with slices of your input
* **Built-in error recovery** - Skip invalid tokens and continue parsing
* **Token disambiguation** - Automatic priority resolution for overlapping patterns
* **UTF-8 safe** - Proper handling of Unicode boundaries
* **No runtime dependencies** - Pure Crystal implementation
* **Fast compile times** - Minimal macro overhead

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

## Annotation-based API

For a Rust-style attribute-driven setup, use type-level annotations and `logos_derive`:

```crystal
require "logos"

@[Logos::Options(skip: "\\s+", error: Nil)]
@[Logos::Subpattern("xdigit", "[0-9a-fA-F]")]
@[Logos::Token("let", variant: :KeywordLet)]
@[Logos::Regex("0x(?&xdigit)+", variant: :Hex)]
@[Logos::Regex("[0-9]+", variant: :Number)]
enum Token
  KeywordLet
  Hex
  Number
end

logos_derive(Token)

lexer = Token.lexer("let 0x10 42")
```

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

* `examples/brainfuck.cr`
* `examples/calculator.cr`
* `examples/custom_error.cr`
* `examples/extras.cr`
* `examples/json.cr`
* `examples/json_borrowed.cr`
* `examples/string_interpolation.cr`
* `examples/token_values.cr`

## Status

✅ **Port Complete**: The Crystal port is feature-complete and the full spec suite passes.

### Current Progress

- [x] Source abstraction (`String` and `Slice(UInt8)`)
- [x] Basic lexer structure and state machine
- [x] Pattern AST and parsing
- [x] Result types and error handling
- [x] Regex pattern compilation
- [x] NFA/DFA construction
- [x] Code generation
- [x] Full test suite

### Dependencies

The project includes two companion shards ported from Rust:
- `regex-syntax` - Regular expression parser
- `regex-automata` - Automata construction library

## Development

```bash
# Install dependencies
make install

# Run tests
make test

# Format code
crystal tool format --check

# Lint code
make lint
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

* [maciejhirsz/logos](https://github.com/maciejhirsz/logos) - The original Rust implementation
* [BurntSushi/regex-automata](https://github.com/BurntSushi/regex-automata) - Rust regex engine used as reference
* [rust-lang/regex](https://github.com/rust-lang/regex) - Rust regex library used as reference
