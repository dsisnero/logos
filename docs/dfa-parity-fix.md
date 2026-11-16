# DFA failure analysis and upstream patch

See the [0.2.0 follow-up](#follow-up-for-regex-automata-020) for the
current blocker and patch. The original 0.1.2 analysis follows.

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

## Follow-up for regex-automata 0.2.0

The old patch targets 0.1.2's materialized row indices. Version 0.2.0
materializes public premultiplied IDs, so the old implementation cannot be
applied as-is. The release's byte-class reduction passes the host parity specs.

The host dead-state fixture now converts cloned transitions and EOI targets to
ordinary row indices before constructing an extended DFA. With this valid
fixture, the 0.2.0 release raises `ArgumentError: invalid 'to' state` inside
`remove_dead_states` when rebuilding the transition table. A delayed match
requires the EOI edge to participate in both reachability and remapping.

The follow-up patch traverses public IDs from all start states, includes EOI
edges, preserves paths to quit, and remaps the compact DFA back to row indices
for construction. The regression verifies that pruning reduces the DFA,
preserves the EOI match for `ab`, and still rejects `!`.

- Shard release base `babe0f378e1191c2c851be5e2ebf7d4d759b4e00`.
- Local commit `e27d6a9524686efee526326b132b892558edbc2e` on
  `codex/fix-dfa-dead-state-removal` in `temp/regex-automata-v020`.
- The shard's DFA suite passed 197 specs, including the focused regression.
  Changed-file format and lint passed. Host format and lint passed.
  Host tests with the installed release yielded 239 passes and one error.
  With the local patch first on `CRYSTAL_PATH`, all 240 host specs passed.
- A generated ASCII matcher compiled and tokenized `abc!` as a word and
  punctuation. The Unicode extras example generated source and passed type
  checking. Crystal 1.22.3 with LLVM 23.1.5 crashed at default optimization
  during machine-code generation for that example.

Reproduce the host run with the local patch from the Logos root:

```bash
mkdir -p temp/crystal-cache
CRYSTAL_CACHE_DIR="$PWD/temp/crystal-cache" \
  CRYSTAL_PATH="$PWD/temp/regex-automata-v020/src:$(crystal env CRYSTAL_PATH)" \
  make test
```

The follow-up commit is local. Logos remains locked to the installed 0.2.0
release, which can be checked against the local fix using the command above.
