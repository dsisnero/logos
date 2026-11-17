# Logos parity inventory

The manifests cover the vendored Rust Logos v0.16.1 tree at
`c7d40fa64dfea9f3b746ecb8f5fe0a0ab8a6ff2f`. The source scope is
`src/`, `logos-codegen/src/`, and `logos-derive/src/`. The test tree
includes executable tests, helper declarations, and compile-time UI fixtures.
The counts describe discovery scope.

`in_progress` means the item is in the review queue. `missing` records a
confirmed gap. Use `ported` for verified equivalents with concrete Crystal
references. Use `partial`, `intentional_divergence`, or `skipped` with the
specific remaining behavior, adaptation, or exclusion.

## Reproduce the discovery and drift checks

Set `skill_scripts` to the `scripts/` directory from the installed
`cross-language-crystal-parity` skill. Run from the Logos root. The discovery
snapshot was generated with Chiasmus 0.3.2 in strict Tree-sitter mode.

```sh
"$skill_scripts/verify_skill_install.sh" "$PWD" rust tree-sitter
export PORT_PARSER=tree-sitter
source_scope=src,logos-codegen/src,logos-derive/src

PORT_SCOPE_INCLUDE="$source_scope" "$skill_scripts/check_port_inventory.sh" \
  "$PWD" plans/inventory/rust_port_inventory.tsv logos_rust rust
PORT_SCOPE_INCLUDE="$source_scope" "$skill_scripts/check_source_parity.sh" \
  "$PWD" plans/inventory/rust_source_parity.tsv logos_rust rust
PORT_SCOPE_INCLUDE=tests/tests "$skill_scripts/check_test_parity.sh" \
  "$PWD" plans/inventory/rust_test_parity.tsv logos_rust rust
```

For a fresh discovery snapshot, use the same scopes and parser with
`generate_port_inventory.sh`, `generate_source_parity_manifest.sh`, and
`generate_test_parity_manifest.sh`. Pass a new output path under `temp/`
as the second argument and compare IDs before updating the curated statuses.

## Evidence

The checked source-range cases were verified by compiling a standalone Rust
driver directly against `logos_rust/src/source.rs` at the pinned revision.
The driver checked byte length, UTF-8 boundaries, empty EOF slices, invalid
binary ranges, and out-of-bounds reads. Crystal's signed invalid arguments
also have explicit regression coverage in
[the source specs](../../spec/logos/source_spec.cr).

The cross-API [callback specs](../../spec/logos/callback_dispatch_spec.cr) use
the same input and expected variants, payloads, error spans, and extras as a
Rust driver built against pinned `logos_rust`. Its reference implementations
are `logos_rust/src/internal.rs` and
`logos_rust/logos-codegen/src/generator/leaf.rs`.

The [navigation specs](../../spec/logos/navigation_spec.cr) check the same
clone, extras, morph, error, and byte-span behavior as a Rust driver linked
against pinned `logos_rust`. The driver observed the original and cloned
iterators independently through a Unicode token, skipped input, an error,
and EOF. Crystal additionally tests that failed navigation leaves a usable
cursor, and uses an explicit `SpannedIter#lexer` getter for Rust's dereference
access.

All seven Rust UI fixtures under `logos_rust/tests/tests/ui/` were built
individually against the pinned crate. The six error fixtures failed with
their expected diagnostic categories and `ok/greedy.rs` built. An
executable Rust driver also passed the exact skip-priority fixture and
checked shadowed ties and Unicode regex weights. The Crystal counterparts
are in [diagnostics](../../spec/logos/diagnostics_spec.cr),
[greedy](../../spec/logos/greedy_spec.cr), and
[matcher priority](../../spec/logos/matcher_priority_spec.cr) specs.
The prebuild check compared the same skip stream with the runtime matcher
and verified that a byte manifest matches `0xff` at `0...1`.

The compiler and graph audit compared the pinned `logos-codegen` parser,
leaf, graph, and generator sources with the Crystal macro and prebuild
implementations. Crystal receives parsed macro AST nodes, builds a shard
DFA from HIR, and emits byte-class rows and acceptance tables. The Rust
`Graph` builds a separate representation with back edges, early acceptance,
state rewrites, and named generated control flow. Its Rust token-stream
handling and DOT and Mermaid exports have intentional difference rows.

[Graph diagnostics](../../spec/logos/diagnostics_spec.cr) and the
[generated matcher fixture](../../spec/fixtures/generated_error_prefix.cr)
check EOF and newline context, rejection of nullable rules, and the
universal-start constraint. The same boundary cases ran against the pinned
Rust crate. The other supporting fixture rows point to their parent Crystal
behavior specs, including the alternate compile-only rules from issues 185
and 259. The [prebuild priority specs](../../spec/logos/codegen_priority_spec.cr)
check duplicate and explicit ties, shadowed rules, and legacy declarations
against emitted matchers. The [binding fixture](../../spec/fixtures/generated_binding.cr)
checks strict manifest metadata before actions run and compares generic and
resolved callback payload streams with the runtime lexer. Shipped manifest
qualification passes through
[the shipped-program specs](../../spec/logos/prebuilt_examples_spec.cr) and
`make test-prebuilt`. All four shipped manifests enable strict binding.
The Rust extras, custom-error, and brainfuck executables were run against
the pinned crate. Crystal's one-based extras line numbers remain documented
in [the parity plan](../parity.md).
