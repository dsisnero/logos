# DFA failure analysis and upstream patch

## Verified Rust behavior

Source: `vendor/regex-syntax/regex-automata`, revision
`d8761c00ed25c5899e3dcfb0f17e827b8e41530a`.
The `dfa/automaton.rs` next-state examples explicitly take the EOI transition;
its start-state contract says start states cannot be match states.

An executable built offline against this vendor, with byte classes enabled
and disabled, tested `a/a`, `ab/ab`, `a|b/b`, `[a-z]/z`, `a*/empty`,
and `a?/empty`. All twelve cases reported:
`start=false before_eoi=false eoi=true`.
Generated harness: `temp/dfa-oracle`.

## Causes and repair

Six tests confused ordinary indices with public strided IDs and/or expected
immediate acceptance. They now use public transitions, EOI, and exact offsets.
The dead-state fixture incorrectly put start/accept states in reserved dead/quit
slots 0/1. Its replacement adds a truly unreachable state to a valid built DFA
and verifies matching after removal.

Actual implementation defects:

- Reduction divided already-unmultiplied materialized transition indices by
  the table stride, turning valid byte/EOI transitions into dead transitions.
- Dead-state removal mixed those representations too, ignored EOI edges,
  omitted anchored/contextual roots, and could discard reserved slots.

Traversal/remapping now consistently uses ordinary indices, includes EOI,
preserves all start-table roots and dead/quit slots, and retains flags,
prefilter, and quit bytes. No immediate-acceptance override or lexer hot-loop
change was added. Runtime performance has not been remeasured for this fix.

## Red-green evidence

Original host reproduction: 16 examples, 8 failures.
Both new shard regressions failed before the fix (expected literal end offsets
1/2, got nil). After repair:

- Host: format, lint, full suite; 240 examples, 0 failures.
- Dependency: full suite; 336 examples, 0 failures.
- Dependency format check and changed-file lint pass.
- Repeated reduction covers seven patterns and eight inputs, including empty
  matches, alternation, classes, rejection, and EOI assertions.

A dependency spec's sibling-directory require was also corrected to require its
own source, preventing accidental loading of a different clone.
The host tracks its dependency snapshot under `lib/`; its patch is preserved
there. Isolated fork verification used `CRYSTAL_PATH` rather than reinstalling
over tracked source.

## Offline-ready upstream review

Title: Preserve materialized DFA indices and EOI during transformations.

Canonical upstream: `dsisnero/regex-automata`.
Branch: `codex/fix-dfa-transforms`.
Base: release 0.1.2, `73f4c2f3c88132536042b4c77364face3d24f6a6`
(matches the host dependency source).
Local patch commit: `cc6e8c920f522eb5afd0598137bbf49c16c3f4de`.
Workspace: `temp/dfa-parity-shard`.

Automatic review blocked publishing because external source-code export needs
explicit user approval. The branch is **not pushed**, no PR exists, and the host
has not been pointed at an unpublished branch. After approval, push the existing
commit, review the diff, and create a PR only with separate approval. Then pin
the published dependency revision.

Beads tracking is unavailable: `bd ready` reports no beads database found.
