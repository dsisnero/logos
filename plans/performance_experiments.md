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
| Compact prebuilt DFA and offset scanning | `performance-prebuild` | `d02f4a3` | Existing baseline: eliminated runtime DFA construction and remainder-string allocation. |
| Stable benchmark control and generated UTF-8 safety contract | `performance-prebuild` | `f6b9b6ad2fc382ce27c7775cd25da807c8194954` | Base for all new isolated experiments; not merged yet. |

## Active experiments

| Experiment | Branch | Base commit | Hypothesis | Result |
| --- | --- | --- | --- | --- |
| Pattern-ID capacity | `codex/perf-pattern-id-capacity` | `f6b9b6ad2fc382ce27c7775cd25da807c8194954` | Preallocate two pattern-ID slots, matching the common accept-state cardinality. | Baseline long-run timing in progress. |

## Rejected experiments

| Experiment | Branch | Commit | Result | Disposition |
| --- | --- | --- | --- | --- |
| Enum-level cached metadata arrays | pre-ledger `performance-prebuild` | no commit | 101.4 ms mean, slower than the prior generated baseline; also increased compile cost. | Reverted. |
| Cached accept-state pattern-ID arrays | pre-ledger `performance-prebuild` | no commit | 200.0 ms mean, 73.1 ms best; worse startup/cache behavior. | Reverted. |
| Allocation-free generic priority selection | pre-ledger `performance-prebuild` | no commit | Side-by-side control was 1.66x faster than the change. | Reverted. |
| Direct pattern-ID matcher result | pre-ledger `performance-prebuild` | no commit | About 136.8 ms mean versus the prior offset-generated result around 32–36 ms. | Reverted. |
| Capacity-two array, short harness | pre-ledger `performance-prebuild` | no commit | 1.05x nominal improvement with ±0.73 uncertainty; best run regressed. | Re-run under the stable harness as the active isolated experiment. |

## Queue

1. Generate sparse direct state dispatch only when it remains smaller than the
   compact-table source and has a compile-time budget.
2. Generate a specialized token dispatch path for manifest-compatible token
   definitions, preserving callbacks/errors with contract tests.
3. Profile the long-workload binary to distinguish matcher work from generic
   `Lexer#next`/`Result` overhead before attempting another representation
   change.
