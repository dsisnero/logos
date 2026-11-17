# Logos for Crystal

> **How to resume:** read `plans/parity.md` first and use its **Where we are**
> block (current focus + ordered "Next up"), then run `make lint` and
> `make test`. Details: [docs/resuming.md](docs/resuming.md). Do not re-derive
> state from git.

A fast lexer generator for Crystal: the Crystal port of the Rust `logos` crate
from [maciejhirsz/logos](https://github.com/maciejhirsz/logos), vendored at
`logos_rust` (release `v0.16.1`, commit
`c7d40fa64dfea9f3b746ecb8f5fe0a0ab8a6ff2f`). The regex layer comes from the
`regex-syntax` / `regex-automata` shards, with `vendor/regex-syntax` as the Rust
reference (release `rure-0.2.5`).

## Commands

```bash
make install        # shards install (BEADS_DIR pinned to ./.beads)
make update         # shards update
make format         # crystal tool format --check src spec examples benchmarks
make lint           # ameba --fix, then ameba
make test           # crystal spec
make markdown       # rumdl fmt docs/development.md docs/resuming.md
make markdown-check # rumdl check docs/development.md docs/resuming.md --check
make clean          # rm -rf ./temp
```

`make prebuild MANIFEST=<json> OUT=temp/<file>.cr` generates a prebuilt matcher;
see [docs/development.md](docs/development.md).

## Docs

- [Resuming work](docs/resuming.md)
- [Architecture](docs/architecture.md)
- [Development](docs/development.md)
- [Coding Guidelines](docs/coding-guidelines.md)
- [Testing](docs/testing.md)
- [PR Workflow](docs/pr-workflow.md)
- [Enum Payload Parity](docs/enum_payload_parity.md)
- [DFA Parity Fix](docs/dfa-parity-fix.md)

## Principles

1. Upstream behavior is the source of truth; `logos_rust` wins over local
   preference. For regex-sensitive failures, check the vendored
   `regex-automata` / `regex-syntax` logic before changing Crystal behavior.
2. Port behavior, not style: Crystal idioms are fine, Rust semantics are not
   negotiable.
3. Port upstream tests early (`logos_rust/tests/tests/*.rs` →
   `spec/logos/*.cr`) and never weaken assertions.
4. Zero-copy parsing: keep the Rust `logos` performance characteristics.
5. Track parity in `plans/parity.md`; per-symbol state belongs in
   `plans/inventory/`.
6. Commit one completed feature at a time.

## Session continuity (read this first)

`plans/parity.md` is the single source of truth for where we are. At the start
of every session:

1. Read `plans/parity.md` and use its **Where we are** block to find the current
   focus, the ordered "Next up" list, per-area status, and the recorded gate
   results. Do not re-derive state from git history.
2. Skim `git log --oneline -10` and `git status` to confirm the working tree.
   `lib/` holds tracked shard checkouts (`lib/regex-automata`,
   `lib/regex-syntax`) that are often dirty; know their state before you trust a
   red test run.
3. Run `make lint` and `make test` before changes to confirm a clean baseline.

See [docs/resuming.md](docs/resuming.md) for the full resume checklist.

### Keeping `plans/parity.md` resumable

- `plans/parity.md` starts with a **Where we are** block (`Current focus`,
  `Next up`, status by area, gotchas, last commit, gates). Keep it accurate
  after every feature.
- Work items are feature-sized (roughly one commit). Per-symbol state lives in
  `plans/inventory/*.tsv`, not in the plan.
- If the plan grows too large, split it into `plans/<area>.md` files, link each
  from `plans/parity.md`, and mark each split file complete/in-progress plus the
  file being worked on next.

### Definition of done for every feature (required)

A feature is complete only when all of the following are true, and all of it
must be committed as **one** atomic commit before starting the next feature:

1. the API surface is implemented in `src/logos/`;
2. upstream tests (or equivalent characterization specs) exist in
   `spec/logos/` and pass;
3. gates pass: `make format`, `make lint`, `make test`;
4. the [Logos parity ledgers](plans/inventory/README.md) capture the
   upstream source and test dispositions for the feature;
5. `plans/parity.md` status is updated and the **Where we are** block refreshed
   (current focus + next up + gate results);
6. any intentional divergence is documented in `plans/parity.md` under
   **Intentional divergences** and/or in the commit message.

### Commit messages

The repository follows conventional commits (`git log` shows `feat:`, `fix:`,
`perf:`, `docs:`, `merge:`):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes (formatting, etc.)
- `refactor:` Code refactoring
- `test:` Test changes
- `perf:` Performance change
- `chore:` Maintenance tasks

For parity work, follow the summary line with bullets for what changed (files,
behavior, divergences) and the upstream revision
(`maciejhirsz/logos v0.16.1 (c7d40fa)`), plus the gate results, so a new session
can resume from the commit alone.

## Project conventions

- **Upstream sources**: Rust `logos` at `logos_rust/`; Rust `regex-syntax` at
  `vendor/regex-syntax/`. Check upstream logic before changing Crystal behavior.
- **Dependency fixes**: never edit `lib/` directly. Patch through the shard
  workflow (`crystal-shard-lib-patch`) and push the fix upstream.
- **Test porting**: convert Rust tests to Crystal specs in `spec/logos/` with
  exact token, span, skip, and error assertions — no compile-only checks.
- **Temporary files**: all generated or scratch files go in `./temp/`
  (git-ignored, removed by `make clean`).
- **Quality gates**: run `make format`, `make lint`, `make test` before
  committing.
- **Work tracking**: `plans/parity.md` is authoritative. `bd` (beads) is
  configured in `.beads/`, but its `issues.jsonl` export is a stale Phase 1–7
  snapshot — do not treat it as the current roadmap.
