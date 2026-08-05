# Performance experiment ledger

This file is the source of truth for generated-lexer performance work. Each
experiment is made on its own branch from a committed baseline. A result is
kept only after focused correctness checks and a same-machine release
comparison. A winning branch is merged into `main`; this ledger records the
exact winning commit after that merge so its code can be reloaded directly.

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
| Current runtime baseline for new experiments | `main` | `690b3e5b27639012e4fb34b7603fbdb510442a77` | Includes the compact prebuilt DFA, stable benchmark harness, UTF-8 safety contract, and cached generated-matcher source bytes winner. All future experiment branches start here. |
| Compact prebuilt DFA and offset scanning | `performance-prebuild` | `d02f4a3` | Existing baseline: eliminated runtime DFA construction and remainder-string allocation. |
| Stable benchmark control and generated UTF-8 safety contract | `performance-prebuild` | `f6b9b6ad2fc382ce27c7775cd25da807c8194954` | Base for all new isolated experiments; merged as a dependency of the first winner. |

## Winners merged into main

| Experiment | Branch | Exact experiment commit | Main merge commit | Runtime result |
| --- | --- | --- | --- | --- |
| Cache generated matcher source bytes | `codex/perf-cache-source-bytes` | `5ca35d98681dd7a7e341aa8aa0e8452e17e9e2e5` | `cbef751d444910a5d11bd33043d833d89d6fecfb` | `LOGOS_BENCH_ROUNDS=500`, 10 runs: 7.404 s mean vs 8.060 s baseline (8.1% faster); median 6.910 s vs 7.985 s (13.5% faster). Focused generated-matcher specs passed. |

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

## Queue

1. Generate sparse direct state dispatch and judge it on runtime only.
2. Generate a specialized token dispatch path for manifest-compatible token
   definitions, preserving callbacks/errors with contract tests.
3. Profile the long-workload binary to distinguish matcher work from generic
   `Lexer#next`/`Result` overhead before attempting another representation
   change.
