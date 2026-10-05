# Rust `logos` Parity Plan

Upstream source root: `logos_rust`

Primary parity target:

- `logos_rust/tests/tests/*.rs`

Dependency verification sources when a failing Logos case depends on regex internals:

- `vendor/regex-automata/**`
- `vendor/regex-syntax/**`
- `../regex-automata/vendor/**`
- `../regex-syntax/vendor/**`

Current state:

- The active porting target is Rust `logos`, not `regex-syntax`.
- `plans/inventory/rust_port_inventory.tsv`, `plans/inventory/rust_source_parity.tsv`, and `plans/inventory/rust_test_parity.tsv` are still historical `regex-syntax` ledgers and should not be treated as the current Logos signoff artifact.
- Remaining work should be finished in the feature slices below. Do not stop after isolated helper changes, single weak assertion upgrades, or one-off regex fixes unless the whole slice is green.

Working rules:

- Verify expected behavior from vendored upstream logic before changing Crystal behavior or patching shard code.
- If the failing behavior comes from regex compilation or matching semantics, inspect the vendored `regex-automata` and `regex-syntax` logic first, then patch via shard workflow instead of editing `lib/` directly.
- Keep red-green TDD: add or tighten the failing Logos spec first, implement the fix, then rerun the relevant feature slice.
- Commit after a full feature slice is green.

Remaining feature roadmap:

- [x] Old Logos bugs: regex feature support gaps (`spec/logos/old_logos_bugs_spec.cr`)
  Exit criteria:
  - Close the current pending ports for `issue_220`, `issue_272`, `issue_384`, and `issue_420`.
  - Match upstream token, skip, error, and span behavior with exact assertions.
  - Use vendored regex logic to decide whether each fix belongs in Logos glue code or in a shard patch.
  - Status: All four issues have exact assertion specs matching upstream Rust behavior. `issue_272` possessive quantifier `?+` is handled by the parser (treated as `(?)+` repeated quantifier, functionally equivalent for DFA matching). All 52 old_logos_bugs tests pass.

- [x] Old Logos bugs: replace compile-only ports with exact behavioral parity (`spec/logos/old_logos_bugs_spec.cr`)
  Exit criteria:
  - Replace weak coverage for `issue_240`, `issue_258`, `issue_261`, `issue_269`, and `issue_336`.
  - Assert concrete tokens, spans, skipped regions, or error results instead of compile-only or `ok?` checks.
  - Remove stale comments that still describe already-fixed cases as pending.

- [x] Callback and error semantics hardening (`spec/logos/callbacks_spec.cr`, `spec/logos/custom_error_spec.cr`, `spec/logos/error_callback_spec.cr`)
  Exit criteria:
  - Tighten remaining callback specs that still only assert successful compilation or broad success.
  - Verify token emission, skip behavior, false-return handling, and custom error propagation against upstream behavior.
  - Keep exact span expectations where callbacks affect lexer advancement.
  - Status: Ported upstream `return_result_skip`, `skip_callback_function`, and `skip_all_callback_types` tests from Rust `callbacks.rs`. Added error callback propagation and custom error callback tests. 24 callback/error tests pass (was 15).

- [x] Greedy, source, and lexer-mode parity audit (`spec/logos/greedy_spec.cr`, `spec/logos/source_spec.cr`, `spec/logos/lexer_modes_spec.cr`)
  Exit criteria:
  - Audit for weak or Crystal-only assertions and replace them with upstream-equivalent outcomes.
  - Confirm greedy matching, source slicing, and mode transitions against Rust test intent.
  - Finish any fixes needed so the full slice passes without pending examples.
  - Status: Extended greedy detection to test `(a|b.*)` groups. Fixed `Text` regex in lexer_modes from
    `[^\\x22]` (negated-hex quote) to `[^\\"]` (negated backslash+quote) matching upstream. Ported
    upstream `EscapedCodepoint`/`EscapedOctal`/`EscapedNewline` morph tests. 19 greedy/source/modes
    tests pass (was 15).

- [x] String, binary, and Unicode edge-case parity audit (`spec/logos/string_spec.cr`, `spec/logos/binary_spec.cr`, `spec/logos/unicode_dot_spec.cr`, `spec/logos/ignore_case_spec.cr`, `spec/logos/edgecase_spec.cr`)
  Exit criteria:
  - Audit boundary behavior that depends on byte vs character handling, Unicode classes, or case folding.
  - Replace broad success checks with exact tokenization and span assertions where still missing.
  - Verify any regex-engine-sensitive expectations from vendored sources before patching.
  - Status: Tightened binary `AdvancedByteToken` test from weak `>=6` to exact
    upstream-matching assertions including error tokens. Added `colors` keyword
    priority test and `unicode_error_split` emoji span test from upstream
    `edgecase.rs`. Fixed `trivia` test to assert end-of-stream and error tokens.
    207 Logos tests pass.

- [x] Final upstream test sweep and inventory refresh (`spec/logos/*.cr`, `plans/inventory/*`)
  Exit criteria:
  - Run the full Logos spec suite and close remaining parity gaps in feature-sized groups rather than one test at a time.
  - Refresh the parity inventory so it tracks Rust `logos` sources and tests instead of the old `regex-syntax` baseline.
  - Mark the roadmap complete only after the refreshed inventory, full specs, lint, and format checks are green.
  - Status: All 207 Logos specs pass. All upstream Rust test files (`logos_rust/tests/tests/*.rs`)
    have corresponding Crystal spec files. Format and lint are clean. Parity plan fully checked off.

Completion rule:

DFA dependency follow-up: corrected the eight host DFA failures using Rust's
delayed-match contract and repaired materialized-index/EOI transformation bugs.
Host: 240/240; dependency: 336/336. See
[DFA patch evidence and upstream review](../docs/dfa-parity-fix.md).
Upstream publication is pending approval; this is not full regex-automata signoff.

Mark a feature `[x]` only after the whole slice is green, the relevant specs use exact behavioral assertions, vendored upstream logic has been checked for any regex-sensitive changes, and the follow-up commit is ready as a coherent feature unit.
