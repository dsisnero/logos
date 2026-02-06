# Logos for Crystal

A fast lexer generator for Crystal, ported from Rust's [Logos](https://github.com/maciejhirsz/logos) library.

## Overview

Logos allows you to create ridiculously fast lexers by defining tokens as an enum with attributes. The library generates an optimized lexer at compile time with zero runtime overhead.

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

enum Token
  # Literal tokens
  #[token("fn")]
  KeywordFn
  #[token("let")]
  KeywordLet

  # Regex patterns
  #[regex("[a-zA-Z_][a-zA-Z0-9_]*")]
  Identifier

  #[regex("[0-9]+")]
  Number

  # Operators
  #[token("+")]
  Plus
  #[token("-")]
  Minus

  # Skip whitespace
  #[regex("\\s+", ignore: true)]
  Ignored
end

lexer = Logos::Lexer(Token).new("fn hello = 42")
lexer.each do |token, slice|
  puts "#{token}: #{slice}"
end
```

## Status

⚠️ **Work in Progress**: This is an active port from Rust. Core functionality is being implemented.

### Current Progress

- [x] Source abstraction (`String` and `Slice(UInt8)`)
- [x] Basic lexer structure and state machine
- [x] Pattern AST and parsing
- [x] Result types and error handling
- [ ] Regex pattern compilation
- [ ] NFA/DFA construction (in progress)
- [ ] Code generation
- [ ] Full test suite

### Dependencies

The project includes two companion shards being ported from Rust:
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