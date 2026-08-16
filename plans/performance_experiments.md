# Performance experiment ledger

This file is the source of truth for generated-lexer performance work. Each
experiment is made on its own branch from a committed baseline. A result is
kept only after focused correctness checks and a same-machine release
comparison. A winning branch is merged into `main`; this ledger records the
exact winning commit after that merge so its code can be reloaded directly.

**Completion rule:** do not start, report, or leave an experiment as active
until it has run its focused correctness gate and release benchmark, has been
explicitly accepted or rejected, its branch result is committed, and this
ledger update is committed on `main`. A winner must additionally be merged
into `main` before the next experiment starts.

## Measurement contract

- Build with `crystal build --release -Dprecompiled benchmarks/lexer_compare.cr`.
- Generate the matcher with `make prebuild` from
  `benchmarks/benchmark_token.logos.json`.
- Time with `hyperfine`, using `LOGOS_BENCH_ROUNDS=500` to amortize process
  startup and reduce scheduler noise.
- Run generated-matcher and affected priority/Unicode specs before measuring.
- Record a failure or flat result, then discard that branch; do not merge it.

## Baseline

| Item | Branch | Commit | Status |
| --- | --- | --- | --- |
| Current runtime baseline for new experiments | `main` | `137ddc94aad517635a6e756aab8efeace5ea9aca` | Includes the compact prebuilt DFA, stable benchmark harness, UTF-8 safety contract, cached source bytes, cached debug flags, allocation-free priority selection, and direct single-pattern generated matches. All future experiment branches start here. |
| Compact prebuilt DFA and offset scanning | `performance-prebuild` | `d02f4a3` | Existing baseline: eliminated runtime DFA construction and remainder-string allocation. |
| Stable benchmark control and generated UTF-8 safety contract | `performance-prebuild` | `f6b9b6ad2fc382ce27c7775cd25da807c8194954` | Base for all new isolated experiments; merged as a dependency of the first winner. |

## Rust comparison and diagnosis (2026-08-15)

The current target is **within 4x Rust runtime** for the identical benchmark
token set and source, measured on this machine in release mode. The baseline is
currently about **69x slower**, so representation-only micro-optimizations are
not enough.

| Implementation | Command workload | Mean | Notes |
| --- | --- | --- | --- |
| Crystal `main` prebuilt matcher | 2,000 rounds, 7 runs | 1.907 s ± 0.108 s | `crystal build --release -Dprecompiled benchmarks/lexer_compare.cr` at `main` `ea47131`. |
| Rust Logos 0.16.1 | same source/rules, 2,000 rounds, 20 runs | 27.7 ms ± 12.8 ms | Temporary local harness using the checked-out `logos_rust` crate and `#[derive(Logos)]`. |

The ratio is 68.8x by means; even the most favorable observed run variance does
not approach the 4x target.

The structural difference is decisive: Rust's proc macro sees the enum and
emits a specialized state machine whose accepting states directly call the
appropriate generated leaf action. Its generator also emits byte-range forks,
256-entry jump tables where appropriate, and an unrolled self-loop fast path.
Crystal's external manifest generator emits a generic compact-table walker;
then every token returns a pattern-ID representation to `Logos.define`, which
performs generic matcher lookup, constructs per-call metadata arrays, chooses a
priority, and only then maps the ID to a variant. The next experiments must
remove that generic post-DFA work on the generated path, rather than only
changing how pattern IDs are stored.

## Winners merged into main

| Experiment | Branch | Exact experiment commit | Main merge commit | Runtime result |
| --- | --- | --- | --- | --- |
| Cache generated matcher source bytes | `codex/perf-cache-source-bytes` | `5ca35d98681dd7a7e341aa8aa0e8452e17e9e2e5` | `cbef751d444910a5d11bd33043d833d89d6fecfb` | `LOGOS_BENCH_ROUNDS=500`, 10 runs: 7.404 s mean vs 8.060 s baseline (8.1% faster); median 6.910 s vs 7.985 s (13.5% faster). Focused generated-matcher specs passed. |
| Cache lexer debug flags | `codex/perf-cache-debug-flags` | `b726f38cc19bff81f888eae4df8c8d07c5379c92` | `2550530462cc99394a072a094f6ce16f263be22d` | `LOGOS_BENCH_ROUNDS=500`, 5 runs: 2.280 s mean vs 6.177 s current baseline (2.71x faster; 63.1% lower). Focused generated-matcher specs passed. |
| Allocation-free priority selection | `codex/perf-priority-loop-post-debug` | `ece0ab4bda216166247a9ce8d47c7673dacb099d` | `33cc9aa7c81e24c7d9f4b1c51c0ec323310e3c2e` | `LOGOS_BENCH_ROUNDS=500`, 5 runs: 2.880 s mean vs 3.494 s current baseline (17.6% faster); median 2.984 s vs 3.469 s (14.0% faster). Generated-matcher, ambiguity, and priority specs passed. |
| Direct single-pattern generated match | `codex/perf-single-pattern-fastpath` | `ee79cff110a219bb912932982225d0479345e898` | `137ddc94aad517635a6e756aab8efeace5ea9aca` | `LOGOS_BENCH_ROUNDS=500`, 5 runs: 2.165 s mean vs 2.465 s current baseline (12.2% faster); median 2.153 s vs 2.450 s (12.1% faster). Generated-matcher, ambiguity, and priority specs passed. |
| Direct dispatch for single generated matches | `codex/perf-direct-generated-dispatch` | `21f17e343b6c9f162e142addb95fc121ce2fcf76` | `9cf35cbb289065db8118f9fab5efbb006a2d32fc` | `LOGOS_BENCH_ROUNDS=500`, 5 runs: 536.1 ms ± 51.7 ms vs 1.788 s ± 0.302 s baseline (3.33x faster). Generated-matcher, diagnostics, and edge-case specs passed (26 examples). |
| Lazy multi-pattern generated result array | `codex/perf-lazy-pattern-result-post-dispatch` | `1bc454629603e5e97e7675c7a5d105d92d0da4d1` | `c12c54e6270b87a63055b306279dfc76d0d27d96` | `LOGOS_BENCH_ROUNDS=2,000`, 5 runs: 2.748 s ± 0.271 s vs 4.134 s ± 0.275 s baseline (33.5% faster). Generated-matcher, diagnostics, and edge-case specs passed (26 examples). |
| Inline exactly two generated pattern IDs | `codex/perf-generated-lexer-result-path` | `df199bc011dfa63c6825c1c12f8769108570a75c` | `ecb49188e5c437e6b773759b1bfec1f0045e4297` | `LOGOS_BENCH_ROUNDS=2,000`, 5 runs: 1.006 s ± 0.099 s vs 1.100 s ± 0.043 s baseline (9.3% faster). Focused generated-matcher, diagnostics, and edge-case specs passed (26 examples). |
| Cache empty prefix-DFA array for generated matches | `codex/perf-cache-empty-prefix-dfas` | `563a8a960bd4250a26e04779361329b1585a1788` | `b5b7efb9093202c8a645655bf2c2c7d508ca53a9` | `LOGOS_BENCH_ROUNDS=2,000`, 5 runs: 543.0 ms ± 47.7 ms vs 632.1 ms ± 38.2 ms baseline (16.4% faster). Focused generated-matcher, diagnostics, and edge-case specs passed (26 examples). |

## Active experiments

No active experiment. The next experiment must start from the documented baseline on its own branch.

## Rejected experiments

| Experiment | Branch | Commit | Result | Disposition |
| --- | --- | --- | --- | --- |
| Enum-level cached metadata arrays | pre-ledger `performance-prebuild` | no commit | 101.4 ms mean, slower than the prior generated baseline; also increased compile cost. | Reverted. |
| Cached accept-state pattern-ID arrays | pre-ledger `performance-prebuild` | no commit | 200.0 ms mean, 73.1 ms best; worse startup/cache behavior. | Reverted. |
| Allocation-free generic priority selection | pre-ledger `performance-prebuild` | no commit | Side-by-side control was 1.66x faster than the change. | Reverted. |
| Direct pattern-ID matcher result | pre-ledger `performance-prebuild` | no commit | About 136.8 ms mean versus the prior offset-generated result around 32–36 ms. | Reverted. |
| Capacity-two array, short harness | pre-ledger `performance-prebuild` | no commit | 1.05x nominal improvement with ±0.73 uncertainty; best run regressed. | Re-run under the stable harness as the active isolated experiment. |
| Pattern-ID capacity, long harness | `codex/perf-pattern-id-capacity` | `6a1e048adbb0b22537d454f95f735838aa2f1fdb` | `LOGOS_BENCH_ROUNDS=500`, 5 runs: baseline 5.986 s mean (min 5.235 s); capacity-two 6.268 s mean (min 5.489 s), 4.7% slower. Focused generated-matcher specs passed. | Rejected; branch intentionally not merged. |
| Compact UInt8 state tables, long harness | `codex/perf-compact-u8-tables` | `b63baca8c6f4835fbb7ebebbd7e9c19b91c0761a` | `LOGOS_BENCH_ROUNDS=500`, 5 runs: baseline 6.083 s mean (min 5.638 s); UInt8 tables 6.442 s mean (min 5.670 s), 5.9% slower. Focused generated-matcher specs passed. | Rejected; branch intentionally not merged. |
| Full-byte transition table, long harness | `codex/perf-full-byte-transition-table` | `47512238722a5faafc3b69293a8c3b36f74b2538` | `LOGOS_BENCH_ROUNDS=500`, 5 runs: baseline 7.291 s mean (σ 0.688 s); full-byte table 7.249 s mean (σ 0.242 s), 0.6% faster and not significant. Focused generated-matcher specs passed. | Rejected as runtime-flat; branch intentionally not merged. |
| Sparse direct state dispatch, long harness | `codex/perf-sparse-direct-dispatch` | `47c9a0dce23ee1603c54f0003a717ed2be54d1f9` | `LOGOS_BENCH_ROUNDS=500`, 5 runs: baseline 6.242 s mean (min 5.663 s); direct dispatch 9.264 s mean (min 6.409 s), 48% slower. Focused generated-matcher specs passed. | Rejected; branch intentionally not merged. |
| Enum metadata constants | `codex/perf-generated-metadata-constants` | `58d2b3d94c558b72f18a0583202d79cfa30d4bcd` | Red compile failed: Crystal rejects enum array constants (`invalid constant value`). The marker commit intentionally contains no invalid source. | Rejected before measurement; branch intentionally not merged. |
| Elide generated empty prefix-DFA allocation | `codex/perf-elide-generated-empty-prefix` | `7b1137deda708aacdb8575af04e25d8514d9b4cd` | `LOGOS_BENCH_ROUNDS=500`, 5 runs against the cached-byte winner: 6.719 s mean vs 6.766 s (0.7% nominal); median regressed, 6.759 s vs 6.741 s. Focused generated-matcher specs passed. | Rejected as runtime-flat; branch intentionally not merged. |
| Lazily allocate multi-pattern result arrays | `codex/perf-lazy-multi-pattern-array` | `40791c2ec26e2776e6a11e2f09f4a8757dfd5afd` | `LOGOS_BENCH_ROUNDS=500`, 5 runs: 1.688 s mean vs 1.720 s baseline (1.9% nominal); median 1.684 s vs 1.713 s, within machine variance. Generated-matcher, diagnostics, and edge-case specs passed (26 examples). | Rejected as runtime-flat; branch intentionally not merged. |
| Tuple fast path for exactly two generated pattern IDs | `codex/perf-two-pattern-fastpath` | `41845bb60e71de09ea659499fa3660f66a6225ee` | Initial 500-round run suggested 1.091 s vs 1.197 s (8.9% faster), but the longer confirmation at 2,000 rounds measured 3.172 s ± 0.459 s vs 1.907 s ± 0.108 s baseline (66.3% slower). Generated-matcher, diagnostics, and edge-case specs passed (27 examples). | Rejected: the longer benchmark disproved the initial noisy result; branch intentionally not merged. |
| Per-state generated transition tables | `codex/perf-generated-state-dispatch` | `14a9078427dfc38d8b98849af24ffc16ebc3f6cb` | Initial 500-round run: 503.9 ms ± 53.5 ms vs 580.1 ms ± 61.8 ms (15.1% faster); required 2,000-round confirmation: 2.873 s ± 0.464 s vs 2.827 s ± 0.447 s (1.6% slower). Focused generated-matcher, diagnostics, and edge-case specs passed (26 examples). | Rejected as runtime-flat after the longer confirmation; branch intentionally not merged. |
| Cache generated matcher registry lookup | `codex/perf-cache-generated-matcher` | `651c5019ba8a72bd3be44585827255951d54719d` | Initial 500-round run: 350.6 ms ± 42.8 ms vs 521.1 ms ± 72.4 ms (48.6% faster); required 2,000-round confirmation: 1.441 s ± 0.324 s vs 1.431 s ± 0.256 s (0.7% slower). Focused generated-matcher, diagnostics, and edge-case specs passed (26 examples). | Rejected as runtime-flat after the longer confirmation; branch intentionally not merged. |
| Direct static call to precompiled matcher | `codex/perf-static-precompiled-call` | `df406c1fe6a64748dc9f97a72469f556226ccffc` | `LOGOS_BENCH_ROUNDS=2,000`, 5 runs: 1.514 s ± 0.055 s vs 1.531 s ± 0.227 s baseline (1.1% nominal). Focused generated-matcher, diagnostics, and edge-case specs passed (26 examples). | Rejected as runtime-flat; branch intentionally not merged. |

## Queue

1. **Generated direct leaf dispatch (highest priority):** extend the manifest
   with variants, skip flags, priorities, and callback eligibility; generate a
   matcher that returns the token/skip action directly, bypassing pattern-ID
   arrays, priority scans, and per-token metadata arrays. First prove plain
   token/regex/skip parity, then callbacks and errors.
2. **Generated state-specialized control flow:** emit range-compressed `case`
   dispatch or direct state functions for the manifest DFA, retaining compact
   tables only when they benchmark faster. Add a self-loop bulk scan for common
   identifier, whitespace, and integer states, modeled on Rust's unrolled loop.
3. **Separate iterator/result overhead:** add an internal token-count benchmark
   that drives the generated matcher directly and compare it with `Lexer#next`.
   This quantifies the remaining Crystal abstraction cost after direct dispatch.
4. Re-profile the long-workload binary after each material winner and retain
   only improvements confirmed with a longer workload.
