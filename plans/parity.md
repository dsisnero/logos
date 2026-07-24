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

- [ ] Old Logos bugs: regex feature support gaps (`spec/logos/old_logos_bugs_spec.cr`)
  Exit criteria:
  - Close the current pending ports for `issue_220`, `issue_272`, `issue_384`, and `issue_420`.
  - Match upstream token, skip, error, and span behavior with exact assertions.
  - Use vendored regex logic to decide whether each fix belongs in Logos glue code or in a shard patch.

- [x] Old Logos bugs: replace compile-only ports with exact behavioral parity (`spec/logos/old_logos_bugs_spec.cr`)
  Exit criteria:
  - Replace weak coverage for `issue_240`, `issue_258`, `issue_261`, `issue_269`, and `issue_336`.
  - Assert concrete tokens, spans, skipped regions, or error results instead of compile-only or `ok?` checks.
  - Remove stale comments that still describe already-fixed cases as pending.

- [ ] Callback and error semantics hardening (`spec/logos/callbacks_spec.cr`, `spec/logos/custom_error_spec.cr`, `spec/logos/error_callback_spec.cr`)
  Exit criteria:
  - Tighten remaining callback specs that still only assert successful compilation or broad success.
  - Verify token emission, skip behavior, false-return handling, and custom error propagation against upstream behavior.
  - Keep exact span expectations where callbacks affect lexer advancement.

- [ ] Greedy, source, and lexer-mode parity audit (`spec/logos/greedy_spec.cr`, `spec/logos/source_spec.cr`, `spec/logos/lexer_modes_spec.cr`)
  Exit criteria:
  - Audit for weak or Crystal-only assertions and replace them with upstream-equivalent outcomes.
  - Confirm greedy matching, source slicing, and mode transitions against Rust test intent.
  - Finish any fixes needed so the full slice passes without pending examples.

- [ ] String, binary, and Unicode edge-case parity audit (`spec/logos/string_spec.cr`, `spec/logos/binary_spec.cr`, `spec/logos/unicode_dot_spec.cr`, `spec/logos/ignore_case_spec.cr`, `spec/logos/edgecase_spec.cr`)
  Exit criteria:
  - Audit boundary behavior that depends on byte vs character handling, Unicode classes, or case folding.
  - Replace broad success checks with exact tokenization and span assertions where still missing.
  - Verify any regex-engine-sensitive expectations from vendored sources before patching.

- [ ] Final upstream test sweep and inventory refresh (`spec/logos/*.cr`, `plans/inventory/*`)
  Exit criteria:
  - Run the full Logos spec suite and close remaining parity gaps in feature-sized groups rather than one test at a time.
  - Refresh the parity inventory so it tracks Rust `logos` sources and tests instead of the old `regex-syntax` baseline.
  - Mark the roadmap complete only after the refreshed inventory, full specs, lint, and format checks are green.

Completion rule:

Mark a feature `[x]` only after the whole slice is green, the relevant specs use exact behavioral assertions, vendored upstream logic has been checked for any regex-sensitive changes, and the follow-up commit is ready as a coherent feature unit.
