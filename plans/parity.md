# Rust `logos` Parity Plan

## Where we are

- **Current focus** — [Phase 2, Logos parity inventory and coverage](#phase-2-logos-parity-inventory-and-coverage).
  The derive UI fixtures and generated/runtime priority checks have
  evidence. The remaining tokenization and legacy regression audit is next.
- **Next up**
  1. **Tokenization and legacy regression coverage.** Compare the
     `advanced.rs`, `simple.rs`, `edgecase.rs`, and `old_logos_bugs.rs`
     fixtures with Crystal token, payload, skip, error, and byte-span
     assertions. Port missing behavior in groups around the matcher or lexer
     contract it exercises.
  2. **Remaining source and fixture review.** Finish outstanding option,
     Unicode and binary matching, and backend dispositions, then run the
     inventory drift and full Logos gates for phase signoff.
- **Status by area** — Payload examples, dependency qualification, source
  boundaries, callbacks, lexer navigation, and the derive UI and matching
  slice are verified. The [Logos inventory](inventory/README.md) records
  pending reviews and intentional differences.
- **Gates** — Format, lint, and 273 specs pass with installed
  `regex-automata` 0.2.1. The flagged codegen specs, all three inventory
  drift checks, and the vendored and prebuilt matcher checks pass.
- **Last feature commit** — `fix: align derive diagnostics and matcher priorities`.

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
dispositions. Tokenization and legacy regression coverage are next. See
the ordered work in **Where we are** and the
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
  retain the existing variant/error semantics.
- **Example output:** The extras example reports one-based lines and
  zero-based byte columns. Rust reports both from zero. The borrowed JSON
  example uses read-only byte slices for source views, with string conversion
  for pretty printing. Rust uses `&str`.
- **Annotation placement:** Crystal cannot introspect per-variant annotations,
  so `Logos::Token` / `Logos::Regex` mappings are declared at the enum type
  level instead of on individual variants.
- **Priority diagnostics:** Rust rejects all highest-priority ties during
  derive. Crystal reports ambiguous explicit rules and duplicate winners
  for the same variant when initializing a runtime matcher. Its legacy
  first-match fallback remains for different variants when fewer than two
  winners declare their priorities.
- **Byte-oriented patterns:** Rust infers non-UTF-8 patterns and rejects them in
  the `regex-non-utf8` UI test; the Crystal port requires the explicit
  `bytes: true` flag.
- **`export_dir`:** the Rust-only `export_dir` derive option is not implemented;
  the Crystal equivalent is `make prebuild MANIFEST=... OUT=...`.
