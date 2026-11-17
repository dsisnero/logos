# Development

## Setup

### Prerequisites

- Crystal 1.19.1+ (check with `crystal --version`)
- Git
- Make

### Installation

```bash
# Clone the repository
git clone https://github.com/dsisnero/logos.git
cd logos

# Install dependencies
make install
```

### Development Dependencies

- **ameba**: Crystal linter (`brew install ameba` or `shards install ameba`)
- **rumdl**: Markdown formatter (`brew install rumdl` or `shards install rumdl`)

## Workflow

### Daily Development

1. **Sync with upstream**:

   ```bash
   git pull --rebase
   make update
   ```

2. **Run quality gates** (before committing):

   ```bash
   make format
   make lint
   make test
   make markdown-check
   ```

3. **Create feature branch**:

   ```bash
   git checkout -b feat/feature-name
   ```

### Prebuilding Lexer Matchers

`Logos.define` normally constructs its DFA lazily when the lexer first runs.
For an application with stable token definitions, generate a compact Crystal
matcher during its build instead. The generated source contains only reduced
byte-class transition tables: it performs no regex parsing, NFA construction,
or DFA deserialization at runtime.

Generated matchers scan the original source bytes at the lexer's current byte
offset. They do not create a new `String` for the remaining source on every
token, which is important for large inputs with many short tokens.

For resolved DFAs with one winner per accepting state, the generator checks
the constant table indices once and emits direct table reads. The scanner
still checks the input slice. Deferred ties use the general checked scanner.

A hand-authored manifest uses the enum name as `name` and follows the
matcher rule order. List `token` and `skip_token` literals first, followed by
`regex` and `skip_regex` patterns.

```json
{
  "name": "Token",
  "utf8": true,
  "subpatterns": {},
  "patterns": [
    {"kind": "token", "pattern": "let"},
    {"kind": "regex", "pattern": "[A-Za-z_][A-Za-z0-9_]*"}
  ]
}
```

Export a strict manifest from a declaration-only Crystal source file. Keep
argument parsing and application work in a separate entry point. This
workflow supports `Logos.define`. The annotation API builds runtime matchers.

```bash
mkdir -p temp
crystal eval '
  require "./examples/lexers/extras"
  Token.write_prebuild_manifest(STDOUT)
' > temp/extras.json
make prebuild MANIFEST=temp/extras.json OUT=temp/generated_token.cr
```

The exporter evaluates the declaration's metadata and leaves callbacks in
the consumer. It includes the optional variant, skip action, encoding and
declared priority for each rule. Invalid UTF-8 bytes are emitted as arrays.
The generator also accepts hand-authored manifests.

Require the same declaration and guard the generated file with a compile-time
flag so normal development builds retain the runtime fallback:

```crystal
require "./lexers/extras"

{% if flag?(:precompiled) %}
  require "generated_token"
{% end %}
```

Build the application with `-Dprecompiled` and include `temp/` on Crystal's
load path:

```bash
CRYSTAL_PATH="$PWD/temp:$(crystal env CRYSTAL_PATH)" \
  crystal build --release -Dprecompiled examples/extras.cr -o bin/extras
```

The prebuild command uses the sibling `../regex-automata` checkout when it is
available, so code generation follows its current DFA implementation. It does
not use Crystal macros to run external code. Regenerate the output whenever a
manifest, token definition, or regex-automata version changes; `make clean`
removes all generated files.

A generic manifest infers priority from each rule. A rule may supply an integer
`priority` as its fallback, and `Logos.define` still applies any priority
explicitly declared in the macro. Use `"utf8": false` for a byte-oriented
manifest.

Include `variant` on every rule to check generic manifest conflicts before
emitting source. Use the exact macro variant name, including for named skips.
Use `"variant": null` and `"skip": true` for anonymous skips. Mirror any explicit
macro priorities in the manifest. A `priority` value marks a rule explicit by
default. Set `priority_explicit` to record explicitness directly.

When every rule supplies an integer `resolved_priority`, those values govern
selection. Prebuild removes lower-priority candidates and reports conflicts
it can identify from the metadata. Remaining highest-priority ties reach the
lexer with their effective priorities so it can check the actual macro
variants. This preserves the declaration-order fallback for distinct legacy
rules. Macro declarations still supply the actions, callbacks, and error
handling. Regenerate existing matcher files to include deferred tie data.

Set `"validate_binding": true` at the manifest root to enable strict rule
binding checks. The consuming lexer verifies the source mode, rule count,
pattern order, token-versus-regex kind, pattern text, case flags, greedy
option, and each subpattern definition before the matcher runs. Add `skip`
and `variant` to a rule to check its action as well. Rule IDs follow the
macro's token rules first, followed by regex rules. Relative order within
each group follows the macro declarations.

Strict validation compares decoded pattern text exactly. A regex spelled
`\n` and a literal newline have different binding text. Use the same spelling
as the macro's evaluated string. Validation is opt-in so existing manifests
and manually registered matchers retain their current behavior. The
`emit_matcher` API exposes the same option as `validate_binding: true`.
A binding replacement is checked on the next lexing operation. Exported
manifests also detect changes to declared priorities.

Run `make test-prebuilt` to compile the shipped manifests with strict binding
and compare generated and runtime behavior. The gate checks the three example
programs and the benchmark token-and-span contract. It asserts custom-error
payloads and spans, word positions and newline extras, interpreter output,
and skipped non-operator characters. Scratch drivers and executables are
written under `temp/`.

The four shipped prebuilds export their strict manifests from the examples
and benchmark declarations. The benchmark passes `resolve_priorities: true`
to the exporter so code generation selects winners from the DSL's explicit
and inferred priorities. Existing manifests can still supply per-rule
`resolved_priority` values.

Run the focused generator specs with
`crystal spec -Dcodegen_library spec/logos/codegen_priority_spec.cr`. The flag
suppresses the generator command-line entry point when importing it for tests.

### Release performance baseline

Run `make benchmark-release` with Crystal and Cargo installed. The target
exports the strict benchmark manifest, builds the Crystal release lexer,
and builds Rust Logos from the pinned `logos_rust/` checkout. It compares
the exact token, byte-span and EOF streams with the Crystal runtime and
prebuilt lexers and checks that both timed binaries emit 5,000 tokens per
round. The target also builds a matcher-only control and checks its count.
Build outputs and stream reports live under `temp/`.

Both timed programs repeat the same checked-in input line 1,000 times per
round. See [the performance ledger](../plans/performance_experiments.md) for
the measured baseline and timing commands.

### Package qualification

Run `make test-package` to verify a working-tree snapshot under `temp/`.
The gate copies the cached repositories selected by `SHARDS_CACHE_PATH`
(or the default Shards cache) into the snapshot, then installs dependencies
with `shards install --frozen --local`. It checks that the lockfile is
unchanged and builds the `logos-codegen` target against those installed
sources.

A separate consumer installs Logos by path and executes the Quick Start
and annotation examples extracted from the README. The package's built
CLI then builds matchers from all four exported manifests. A separate
contract edits a consumer rule, checks the stale matcher error, and
regenerates. This gate requires the locked repositories in the local Shards
cache. Its generated files and compiler cache stay under `temp/`.

### Porting from Rust

The primary upstream is Rust `logos` (`logos_rust/`); regex-sensitive behavior
also comes from `vendor/regex-syntax/`.

1. **Examine Rust source first**:

   ```bash
   # Find relevant Rust code
   grep -rn "function_name" logos_rust/ vendor/regex-syntax/
   ```

2. **Understand the algorithm**:
   - Read Rust documentation
   - Trace through test cases
   - Note performance characteristics

3. **Port to Crystal**:
   - Match Rust logic exactly
   - Adapt to Crystal idioms
   - Preserve performance characteristics

4. **Write tests**:
   - Port Rust tests exactly
   - Add Crystal-specific edge cases
   - Ensure behavioral parity

### Porting from Go

This port currently has no Go upstream: `vendor/` only holds `regex-syntax`.
Keep the following guidance for any future Go-derived shard.

1. **Examine Go source**:

   ```bash
   grep -r "functionName" <go-upstream>/
   ```

2. **Handle type differences**:
   - Go interfaces → Crystal modules
   - Go structs → Crystal classes/structs
   - Go error handling → Crystal exceptions

3. **Test porting**:
   - Convert Go test tables to Crystal specs
   - Maintain exact assertions
   - Handle floating-point precision differences

## Porting status and parity index

Current state, roadmap, and gate results live in
[`plans/parity.md`](../plans/parity.md) — read its **Where we are** block first.

Upstream pins:

- Rust `logos` — `logos_rust`, release `v0.16.1`, commit `c7d40fa`
- Rust `regex-syntax` — `vendor/regex-syntax`, release `rure-0.2.5`

The regex layer itself comes from the `regex-syntax` and `regex-automata`
shards (tracked checkouts under `lib/`). Fix behavior there through the shard
workflow, never by editing `lib/` in place.

### Rust handbook parity index

Reference mapping from Rust handbook topics to Crystal docs/spec coverage:

- Getting started: [README](../README.md) (Quick Start) and
  `spec/logos/simple_spec.cr`
- Attributes / derive: [README](../README.md) (Annotation-based API) and
  `spec/logos/annotations_spec.cr` and `spec/logos/crate__spec.cr`
- Callbacks: `spec/logos/callbacks_spec.cr`
- Extras: `examples/extras.cr` and `spec/logos/custom_error_spec.cr`
- Common regex patterns: `spec/logos/advanced_spec.cr`,
  `spec/logos/properties_spec.cr`
- Context-dependent lexing: [README](../README.md) (Context-Dependent Lexing)
  and `spec/logos/lexer_modes_spec.cr`
- Token disambiguation: [README](../README.md) (Token Disambiguation and
  Priority) and `spec/logos/old_logos_bugs_spec.cr`
- Unicode support: `spec/logos/unicode_dot_spec.cr`,
  `spec/logos/ignore_case_spec.cr`
- Source and spans: `spec/logos/source_spec.cr`, `spec/logos/lexer_spec.cr`

### Rust derive UI fixture coverage

Rust's `derive.rs` runs the seven fixtures under `tests/ui` through `trybuild`.
Crystal checks the matching behavior with executable specs. Matcher diagnostics
surface when the Crystal runtime initializes the matcher or prebuild compiles
the manifest.

| Rust case | Crystal coverage |
| --- | --- |
| `ok/greedy.rs` | [Greedy opt-in](../spec/logos/greedy_spec.cr) checks the token and byte span. |
| `err/greedy-without-config.rs` | [Greedy](../spec/logos/greedy_spec.cr), [diagnostics](../spec/logos/diagnostics_spec.cr), and [codegen](../spec/logos/codegen_priority_spec.cr) check rejected patterns. |
| `err/priority-conflict.rs` | [Diagnostics](../spec/logos/diagnostics_spec.cr) check the same-variant priority conflict. |
| `err/subpattern-match-empty.rs` | [Diagnostics](../spec/logos/diagnostics_spec.cr) and [codegen](../spec/logos/codegen_priority_spec.cr) reject empty-matching subpatterns. |
| `err/regex-non-utf8.rs` | [Diagnostics](../spec/logos/diagnostics_spec.cr) check non-UTF-8 regex rules. Use `bytes: true` to select byte syntax. |
| `err/token-non-utf8.rs` | [Diagnostics](../spec/logos/diagnostics_spec.cr) reject an invalid UTF-8 token. |
| `err/multiple-export-dirs.rs` | Crystal prebuild takes one output file through `--out`. Rust's `export_dir` belongs to its derive API. |

The [crate-path fixture](../spec/logos/crate__spec.cr) uses a nested alias for
Crystal's Logos annotations and checks the complete Rust token stream. Rust
selects a crate path through a derive attribute.

### Completed port milestones

- [x] Source abstraction (`String` and `Slice(UInt8)`)
- [x] Basic lexer structure and state machine
- [x] Pattern AST and parsing
- [x] Result types and error handling
- [x] Regex pattern compilation
- [x] NFA/DFA construction
- [x] Code generation
- [x] Full test suite

### Hybrid automaton status

- `Regex::Automata::Hybrid::LazyDFA` performs lazy determinization and caches
  transitions on demand.
- It supports anchored/unanchored start states and reuses the same look-around
  semantics as the DFA builder.
- This hybrid path suits large regex sets where eager DFA construction has a
  higher startup cost.

## Debugging

### Lexer Debugging

```bash
# Enable debug logging
LOGOS_DEBUG=1 crystal run examples/simple.cr

# Debug DFA construction
LOGOS_DEBUG_DFA_BUILD=1 crystal spec
```

### Performance Profiling

```bash
# Build with debug symbols
crystal build --debug examples/simple.cr

# Run with perf (Linux)
perf record ./simple
perf report
```

### Memory Analysis

```bash
# Build with memory profiling
crystal build --release --no-debug examples/simple.cr

# Use valgrind (Linux/macOS)
valgrind --leak-check=full ./simple
```

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run specific test file
crystal spec spec/logos/lexer_spec.cr

# Run with verbose output
crystal spec -v

# Run with fail-fast
crystal spec --fail-fast
```

### Test Patterns

- **Unit tests**: Test individual functions and classes
- **Integration tests**: Test lexer generation and usage
- **Property tests**: Use Crystal's `Spec::Property` for randomized testing
- **Golden tests**: Compare output against expected results

### Test Porting Guidelines

When porting tests from Rust/Go:

1. **Exact assertions**: Don't adjust expected values
2. **Test structure**: Convert test tables to Crystal `it` blocks
3. **Pending tests**: Mark incomplete functionality as `pending`
4. **Edge cases**: Include all original edge cases

## Code Quality

### Formatting

```bash
# Check formatting
make format

# Auto-format (if tool supports it)
crystal tool format
```

### Linting

```bash
# Run linter with auto-fix
ameba --fix

# Verify linting
ameba
```

### Documentation

```bash
# Format markdown
make markdown

# Check markdown formatting
make markdown-check
```

## Release Process

1. **Update version** in `shard.yml`
2. **Run full test suite**:

   ```bash
   make clean
   make install
   make test
   ```

3. **Update CHANGELOG.md** with changes
4. **Create git tag**:

   ```bash
   git tag v1.2.3
   git push --tags
   ```

5. **Publish to GitHub Releases**

## Troubleshooting

### Common Issues

**"Shard not found"**:

```bash
make update
```

**"Formatting errors"**:

```bash
crystal tool format
```

**"Linter errors"**:

```bash
ameba --fix
ameba
```

**"Tests failing"**:

- Check test output for specific failures
- Verify ported logic matches source
- Ensure dependencies are up to date
