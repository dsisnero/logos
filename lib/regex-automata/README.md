# regex-automata

`regex-automata` is the Crystal port of Rust's `regex-automata` crate used by Logos.
It compiles `regex-syntax` HIR into Thompson NFA and DFA (plus a lazy Hybrid engine)
for fast token matching.

## Installation

Add to `shard.yml`:

```yaml
dependencies:
  regex-automata:
    github: dsisnero/logos
    path: lib/regex-automata
```

Then run:

```bash
shards install
```

## Usage

```crystal
require "regex-syntax"
require "regex-automata"

hir = Regex::Syntax.parse("[a-z]+")
nfa = Regex::Automata::HirCompiler.new.compile(hir)
dfa = Regex::Automata::DFA::Builder.new(nfa).build

match = dfa.find_longest_match("abc123")
pp match # => {3, [PatternID(0)]}
```

### Lazy hybrid matching

```crystal
hybrid = Regex::Automata::Hybrid::LazyDFA.compile(Regex::Syntax.parse("foo|bar"))
pp hybrid.find_longest_match("bar!") # => {3, [PatternID(0)]}
```

## Current feature scope

- Thompson NFA builder for Logos-supported regex features
- DFA subset construction with look-around support used by Logos
- Anchored/unanchored start-state support
- EOI-aware transitions and longest-match search
- Lazy hybrid state expansion (`Hybrid::LazyDFA`)

## Development

From this directory:

```bash
crystal tool format src spec
crystal spec
```

For full-repo checks, run from repository root:

```bash
ameba src spec
crystal spec
```

## Upstream reference

- Rust source of truth: `vendor/regex-syntax/regex-automata/`
- Main consumer: `src/logos/macros.cr`

## License

MIT
