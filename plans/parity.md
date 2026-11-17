# Rust `logos` Parity Plan

## Where we are

- **Current focus** — [Phase 6, Shipped prebuild manifest qualification](#phase-6-shipped-prebuild-manifest-qualification)
  is complete. The three example manifests and benchmark manifest enable
  strict binding with exact pattern strings and declared variant and skip
  actions.
- **Next up**
  1. **Package and documentation qualification.** Verify the locked package
     and CLI from an isolated checkout, run the strict shipped contracts
     through the installed entry point, and reconcile the public usage and
     status documentation with the completed parity phases.
- **Status by area** — All 269 source and 249 test-tree items retain their
  dispositions. Generated and runtime examples agree on callback payloads,
  extras, skip actions, error spans, and output. The benchmark token-and-span
  contract checks that strict metadata is present.
- **Gates** — Format, lint, and 299 specs pass with `regex-automata` 0.2.1.
  `make test-prebuilt` passes all 15 generator and shipped-program specs.
  Markdown and all three inventory drift checks pass. The pinned Rust
  extras, custom-error, and brainfuck example executables pass their
  corresponding output or assertion checks.
- **Last feature commit** — `test: qualify shipped strict prebuild manifests`.

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

**Complete.** The ledgers cover 269 discovered source items, 122 Rust
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
links each Rust case to its Crystal disposition. The final compiler audit
records Crystal's dense-table implementation, validates graph diagnostics,
and verifies delayed acceptance on the real next transition. See the
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

### Phase 4. Prebuild rule identity and priority parity

**Complete.** Generic manifests can declare priorities and variant names for
build-time conflict checks. Resolved matchers retain the highest tied rules
and pass the priority metadata to the lexer. Both forms preserve compatibility
with distinct legacy ties and manual matcher registrations.

- Verify diagnostics and winners for explicit ties, duplicate variants,
  tied skip rules, and shadowed candidates in both manifest forms.
- Preserve compatibility with existing manifest fields and generated matcher
  registrations while carrying enough metadata to reproduce runtime checks.

**Exit criteria.** Runtime and emitted matchers agree for the specified rule
metadata, with legacy manifest behavior covered by executable specs.

### Phase 5. Prebuild manifest binding validation

**Complete.** Strict prebuilds emit source and rule metadata that the macro
checks before running the matcher. Binding validation is opt-in to preserve
existing manifests whose equivalent regexes use different textual spellings.
The metadata checks optional variant and skip fields when supplied.

- Detect mismatches in declared rule order, pattern kind, source encoding,
  and skipped actions using validation metadata from the generated matcher.
- Verify the same token, callback payload, and span streams in generated and
  runtime mode, including legacy manifests and manual registration.

**Exit criteria.** A strict mismatched manifest yields a diagnostic that
identifies its rule or option. Existing manifests and registrations retain
their behavior.

### Phase 6. Shipped prebuild manifest qualification

**Complete.** All four shipped manifests enable strict binding. Their
patterns match the evaluated macro strings, every rule declares its variant
and skip action, and brainfuck's fallback carries its explicit zero priority.
The generated benchmark retains its resolved priority policy.

- Adopt strict binding with exact pattern strings, skip flags, and variant
  identities in the shipped manifests.
- Compile and execute the corresponding generated examples and compare
  payloads, extras, error behavior, and spans with their runtime builds.

**Exit criteria.** Every shipped manifest passes strict binding and its
executable generated/runtime contract on the recorded dependencies.

### Phase 7. Package and documentation qualification

**Next.** The strict contracts have been verified in the development checkout.

- Verify a locked install and built CLI in an isolated checkout under `temp/`.
- Exercise the strict shipped manifests using the built entry point and check
  the public build and usage commands against the qualified package.
- Reconcile README status and user documentation with the completed phases.

**Exit criteria.** The installed package and documented commands reproduce
the strict example and benchmark contracts with the pinned dependencies.

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
  winners declare their priorities. Resolved prebuild matchers defer tied
  candidates to the macro variant check whenever the manifest permits the tie.
- **Source types:** Generated Crystal constructors select `String` or `Bytes`.
  Rust exposes a generic associated `Source` and borrowed slices.
- **Graph code generation:** Rust emits per-state functions or state-machine
  arms and offers DOT and Mermaid exports. Crystal prebuild emits dense
  byte-class tables and one scanner. Crystal initialization or prebuild
  reports matcher errors as exceptions.
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
