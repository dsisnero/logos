# Resuming Work

This is the first thing to read in a new session. It takes a few minutes to get
back to a known-good state.

## 1. Read where we are

- `plans/parity.md` — start at the **Where we are** block. It names the current
  focus, the ordered "Next up" list, per-area status, scoping notes and gotchas,
  the last commit, and the recorded gate results. Do not re-derive state from
  git history.
- [Logos parity inventory](../plans/inventory/README.md) contains the source
  and test ledgers for the pinned Rust Logos release.
- [DFA parity fix](dfa-parity-fix.md) records the dependency fix and the
  qualification of regex-automata 0.2.1.

## 2. Confirm the working tree

```bash
git log --oneline -10
git status
```

Use the log to confirm the previous feature commit and identify separate
documentation or dependency commits. Check the scope of any local changes
before editing.

Note that `lib/regex-automata` and `lib/regex-syntax` are tracked shard
checkouts and are frequently modified. That diff changes `Hir#complexity` and
DFA internals, so a red suite may come from `lib/`, not from `src/logos/`.
Check `git diff --stat lib/` before blaming the port.

## 3. Confirm a clean baseline

```bash
make format
make lint
make test
```

`make format` and `make lint` must pass before changing anything. `make test`
should match the gate results recorded in the **Where we are** block; if it is
worse, find out why before writing code.

## 4. Pick the next feature

Take the first unchecked item in the **Next up** list (or the next `[ ]` item in
the current phase). For each feature:

1. Read the upstream source under `logos_rust` (tests under
   `logos_rust/tests/tests/*.rs`) and, for regex-sensitive behavior, the
   vendored `vendor/regex-syntax` / `lib/regex-automata` logic.
2. Port the tests first (red → green); never weaken assertions.
3. Satisfy the **Definition of done** in `CLAUDE.md` (API, tests, gates,
   inventory rows, `plans/parity.md` status + **Where we are** refresh,
   divergences).
4. Commit atomically with the message format from `CLAUDE.md`.

## If the plan is split

When `plans/parity.md` grows too large it is split into `plans/<area>.md` files
(see `plans/performance_experiments.md` for the existing example). In that case
every split file is linked from `plans/parity.md`, and `plans/parity.md` marks
each file complete/in-progress and names the file being worked on plus the next
file/phase to start.

## Environment notes

This checkout lives on an exFAT volume (`/Volumes/extreme_ssd`), so macOS writes
AppleDouble `._*` sidecars next to real files. They are harmless in most places
but can confuse tooling:

- sidecars appear under `src/`, `spec/`, and `docs/` (for example
  `spec/regex/automata/._dfa_spec.cr`);
- a git pack operation can print
  `non-monotonic index .../._pack-*.idx`, fixed with
  `find .git -name '._*' -delete`;
- if a sidecar ever breaks spec discovery or formatting, clean the source trees
  with `find src spec examples -name '._*' -delete`.
