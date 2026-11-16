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
