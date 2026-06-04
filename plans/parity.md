# Rust `regex-syntax` Parity Plan

Upstream source root: `vendor/regex-syntax/regex-syntax`

Validated inventory baseline:

- `./scripts/ensure_parity_plan.sh . vendor/regex-syntax/regex-syntax rust auto 0`
- `plans/inventory/rust_port_inventory.tsv`: 1035 tracked source items
- `plans/inventory/rust_source_parity.tsv`: 877 tracked API items
- `plans/inventory/rust_test_parity.tsv`: 158 tracked upstream tests

Current ledger snapshot:

- `ported`: 693 rows
- `partial`: 1 row
- `skipped`: 4 rows
- `missing`: 337 rows
- All tracked upstream tests are currently `missing`

Feature roadmap:

- [ ] AST core model and assertion semantics (`src/ast/mod.rs`)
- [ ] AST parser parity (`src/ast/parse.rs`)
- [x] AST printing and visitor support (`src/ast/print.rs`, `src/ast/visitor.rs`)
- [ ] HIR core data model and interval operations (`src/hir/mod.rs`, `src/hir/interval.rs`)
- [ ] HIR translation pipeline (`src/hir/translate.rs`)
- [x] HIR literals, printing, and visitor utilities (`src/hir/literal.rs`, `src/hir/print.rs`, `src/hir/visitor.rs`)
- [x] Parser facade, crate API, and error surface (`src/parser.rs`, `src/lib.rs`, `src/error.rs`, `src/either.rs`)
- [x] Unicode property tables: general categories and boolean properties (`src/unicode_tables/general_category.rs`, `src/unicode_tables/property_bool.rs`)
- [x] Unicode query helpers, Perl classes, and case folding (`src/unicode.rs`, `src/unicode_tables.cr`)
- [x] Unicode property tables: scripts and script extensions (`src/unicode_tables/script.rs`, `src/unicode_tables/script_extension.rs`)
- [x] Unicode property tables: ages, Perl classes, property names/values, and case folding (`src/unicode_tables/age.rs`, `src/unicode_tables/perl_decimal.rs`, `src/unicode_tables/perl_space.rs`, `src/unicode_tables/perl_word.rs`, `src/unicode_tables/property_names.rs`, `src/unicode_tables/property_values.rs`, `src/unicode_tables/case_folding_simple.rs`)
- [x] Unicode boundary tables and UTF-8 helpers (`src/unicode_tables/word_break.rs`, `src/unicode_tables/sentence_break.rs`, `src/unicode_tables/grapheme_cluster_break.rs`, `src/utf8.rs`)
- [ ] Upstream regression and spec parity sweep (`plans/inventory/rust_test_parity.tsv`)

Completion rule:

Mark a feature `[x]` only after its mapped inventory rows are updated with real
`crystal_refs`, the relevant Crystal specs are green, and the three parity
checks still pass.
