# Rust `logos` Parity Plan

## Where we are

- **Current focus** — [Phase 2, Logos parity inventory and coverage](#phase-2-logos-parity-inventory-and-coverage).
  The executable upstream fixtures have dispositions. Compiler and graph
  inventory signoff is next.
- **Next up**
  1. **Compiler and graph inventory signoff.** Review the remaining parser,
     graph, and generator contracts against the Crystal backend. Map
     compiled-table equivalents, document structural differences, and
     resolve public behavior gaps with targeted failing specs. Close the
     supporting fixture dispositions and rerun the inventory and full
     Logos gates before marking Phase 2 complete.
- **Status by area** — The test ledger covers all 122 upstream test functions.
  It records 117 ports, four intentional differences, and one exclusion.
  The last fixture review covers Unicode string payloads, cloned cursors,
  CSS tokenization, crate qualification, and the derive UI case map.
  [The Logos inventory](inventory/README.md) tracks outstanding source and
  supporting fixture reviews.
- **Gates** — Format, lint, and 293 specs pass with the tracked
  `regex-automata` 0.2.1 snapshot. Flagged codegen specs, the compile check,
  Markdown check, and all three inventory drift checks pass. The six
  vendored lexer tests and a malformed-escape characterization pass. All
  seven vendored UI files were checked individually against the pinned
  crate, with the successful build and expected diagnostic messages verified.
- **Last feature commit** — `test: finish lexer and derive fixture parity`.

## Scope and verification

- Logos parity targets `maciejhirsz/logos` v0.16.1 (`c7d40fa`) under
  `logos_rust/`, including the runtime, derive and codegen behavior,
  `tests/tests/*.rs`, and examples.
- The [inventory](inventory/README.md) tracks pinned Logos. Items marked
  `in_progress` still require a contract review. The beads export is a stale
  Phase 1–7 snapshot. Keep per-symbol and per-test decisions in the inventory.
- The installed lock selects `regex-automata` 0.2.1 and `regex-syntax` 0.5.0
  at `1623e24`. Verify the resolved shard sources before reporting a gate
  result. The tracked `lib/` snapshots can contain local upgrades.
- For regex-sensitive behavior, compare the pinned Rust code in
  `vendor/regex-syntax/` or the sibling shard repositories with the Crystal
  source loaded for the test. Use the shard patch workflow for dependency
  fixes. Add or tighten a failing behavioral spec before changing behavior.
- Each phase ends in a coherent commit after its exit criteria and the
  applicable format, lint, and test gates pass. Refresh **Where we are** with
  the evidence and any remaining dependency conditions.

## Feature roadmap

### Phase 1. Payload-driven examples

**Complete.** All seven payload-oriented Crystal examples read from results.
The executable checks cover Rust-style integer division, raw JSON key
equality and error spans, per-character non-ASCII diagnostics, byte columns,
and nested interpolation. The generated custom-error matcher also passed.
See [enum payload parity](../docs/enum_payload_parity.md).

- Migrate calculator and token values, owned and borrowed JSON, custom errors,
  extras, and string interpolation to extract callback data from the result
  that emitted it. Use the existing Crystal examples as the starting point
  and compare their behavior with the corresponding Rust examples.
- Verify the features together through executable examples. Check calculator
  answers, parsed JSON values, custom error output, word positions, and
  interpolation output. Preserve error handling, spans where reported, and
  mode transitions. Verify the borrowed JSON example's handling of raw string
  slices against the Rust example and document any representation difference.
- Update usage docs to show typical result payload extraction and explain the
  existing lexer accessor for current-token reads.

**Exit criteria.** Each migrated example runs with representative input and
produces the expected result or diagnostic. Both macro entry points retain
their payload regression coverage, and the full Logos gates pass with the
recorded shard revision.

### Phase 2. Logos parity inventory and coverage

**In progress.** The ledgers cover 269 discovered source items, 122 Rust
test functions, and 127 supporting or UI fixture items from the test tree.
Checked source ranges, the non-UTF-8 stream, callback dispatch, lexer
navigation, and the seven derive UI fixtures have evidence-backed
dispositions. The tokenization and legacy review mapped 83 test functions
across `advanced.rs`, `simple.rs`, `edgecase.rs`, and
`old_logos_bugs.rs`. It added generated matcher and macro coverage for
subpattern expansion and name collisions, plus exact byte-span fixtures for
escaped strings, Unicode trivia, Cyrillic, and long quoted input. Unicode
and binary coverage adds exact upstream case-folding, script-property and
mixed-dot streams. Pattern options and subpatterns are shared across runtime
and codegen. Generated matchers also report failed prefixes, both runtime
APIs round incomplete UTF-8 prefixes to the next boundary, and the exact
custom-error streams verify callback payloads and cumulative extras. The final
lexer fixtures verify exact decoded Unicode payloads, five clone cursors,
CSS tokens, and nested Logos annotation qualification. The
[derive UI case map](../docs/development.md#rust-derive-ui-fixture-coverage)
links each Rust case to its Crystal disposition. See the ordered work in
**Where we are** and the
[inventory verification instructions](inventory/README.md).

- Use the generated source and test IDs for pinned Logos runtime, derive and
  codegen sources and the upstream test suite. Map each in-scope
  test or API contract to its Crystal implementation and behavioral evidence,
  or record a specific divergence or exclusion.
- Check that upstream token, skip, error, and span assertions have Crystal
  equivalents where relevant. Close gaps found by the audit, grouping fixes
  with the contract they cover.
- Record how to reproduce the manifests and run drift checks against the
  pinned upstream. Include the example evidence from Phase 1 in the signoff.

**Exit criteria.** The current ledgers describe Logos, with a disposition and
evidence for every in-scope item. Drift checks and the full Logos gates pass
with the recorded shard revision.

### Phase 3. Installed dependency and generated matcher qualification

**Complete.** Shard release 0.2.1 includes the DFA fix. The clean frozen
install, full test suite, and generated matcher comparisons passed.
The Unicode extras example compiled and agreed with the runtime matcher.
See the [qualification evidence](../docs/dfa-parity-fix.md#regex-automata-021-qualification).

- Adopt a released shard containing the fix and verify a clean install using
  the committed lockfile. Exercise delayed EOI acceptance, dead-state
  removal, byte-class reduction, and the HIR class and priority expectations
  on the installed shards.
- Build generated matcher source and compare its token and span output with
  the runtime matcher on representative ASCII and Unicode inputs. Recheck
  the recorded LLVM crash on the Unicode extras example and record the
  compiler version and verified behavior. The shard's native DFA binary
  format change applies to persisted DFA blobs. Logos prebuild emits Crystal
  source.
- Record the installed versions and gate results in the parity plan so a
  fresh checkout can reproduce the signoff.

**Exit criteria.** A clean install passes the full Logos suite without a
local shard override. The generated matcher checks pass on a verified
toolchain, with any remaining compiler limitation documented against its
reproduction.

## Completed feature phases

- **Core lexer semantics and regression coverage.** Ported the legacy Logos
  bug cases, including regex gaps in issues 220, 272, 384, and 420 and exact
  assertion upgrades for 240, 258, 261, 269, and 336. Verified greedy matching,
  source slicing, mode transitions, byte inputs, Unicode handling, priority,
  and error spans. The upstream test-file sweep had 207 passing Logos specs.
- **Callback, error, and result contracts.** Covered callback emission,
  skips, false returns, custom errors, and span advancement. Both Crystal
  macro entry points now attach each typed callback payload to its emitted
  result with regression coverage for consecutive results of the same
  variant. See [enum payload parity](../docs/enum_payload_parity.md).

## Intentional divergences

- **Enum payloads:** Rust `logos` attaches data to enum variants. Crystal
  keeps the enum tag and a boxed callback value in `Logos::Result`.
  Typed access uses the variant and expected type. Result equality and hashing
  retain the existing variant/error semantics. The Rust derive fixture
  specializes generic enum variants. Crystal uses typed result payloads with a
  non-generic enum.
- **Example output:** The extras example reports one-based lines and
  zero-based byte columns. Rust reports both from zero. The borrowed JSON
  example uses read-only byte slices for source views, with string conversion
  for pretty printing. Rust uses `&str`.
- **Annotation placement:** Crystal cannot introspect per-variant annotations,
  so `Logos::Token` / `Logos::Regex` mappings are declared at the enum type
  level instead of on individual variants.
- **Crate qualification:** Rust derive selects an alternate crate path through
  `#[logos(crate = ...)]`. Crystal qualifies the annotations directly, including
  through a nested alias of the Logos module.
- **Priority diagnostics:** Rust rejects all highest-priority ties during
  derive. Crystal reports ambiguous explicit rules and duplicate winners
  for the same variant when initializing a runtime matcher. Its legacy
  first-match fallback remains for different variants when fewer than two
  winners declare their priorities.
- **Pattern encoding:** Rust uses each literal's type. Crystal defaults each
  pattern and subpattern to the lexer's `utf8` mode for compatibility. Set
  `bytes: true` for byte regex syntax or `bytes: false` for Unicode syntax in
  either lexer mode. A string lexer accepts byte rules whose HIR can only
  match valid UTF-8. The Crystal `ignore_ascii_case: true` option selects
  ASCII folding for tokens and starts regex parsing in byte mode. Rust uses
  `ignore(case)` with byte literals or scoped regex flags for ASCII folding.
- **Manifest encoding:** Each pattern can specify `bytes`, `ignore_case`, or
  `ignore_ascii_case`. An array of octets in `pattern` defaults to byte mode.
  Subpatterns can use a string value or an object with `pattern` and `bytes`.
  Definitions may refer to earlier entries in declaration order. Set
  `allow_greedy: true` to opt in to unbounded greedy dot rules, as with the
  runtime macros. Regenerated matchers report failed prefixes. Legacy
  registered matchers returning `nil` use the single-character or byte fallback.
- **`export_dir`:** the Rust-only `export_dir` derive option is not implemented;
  the Crystal equivalent is `make prebuild MANIFEST=... OUT=...`.
