# DFA dead-state removal raises on an end-of-input match in v0.2.0

### Affected release

`dsisnero/regex-automata` v0.2.0
(`babe0f378e1191c2c851be5e2ebf7d4d759b4e00`), with
`regex-syntax` 0.5.0 at `1623e24`. Reproduced with Crystal 1.22.3.

### Resolution

Fixed in `regex-automata` v0.2.1
(`d5c9ed47f8da084858131d60609f7ae3016fe58d`). The reproduction below and the
full Logos suite pass with the installed release.

## Reproduction

Run this with the released shard on the Crystal load path. The constructor
takes ordinary row indices. The fixture converts the public premultiplied IDs
before adding a valid unreachable row.

```crystal
require "regex-automata"

alias RA = Regex::Automata

original = RA::DFA::Builder.new.build("ab")
rows = original.states.map_with_index do |state, index|
  row = state.dup(RA::StateID.new(index))
  row.next.map! { |id| RA::StateID.new(original.to_index(id)) }
  row.eoi_next = RA::StateID.new(original.to_index(row.eoi_next))
  row
end
rows << RA::DFA::State.new(RA::StateID.new(rows.size), original.byte_classes)
extended = RA::DFA::DFA.new(
  rows, nil, RA::StateID.new(original.to_index(original.start)),
  original.byte_classifier,
  RA::StateID.new(original.to_index(original.start_anchored))
)

expected = {2, [RA::PatternID.new(0)]}
raise "invalid fixture" unless extended.find_longest_match("ab") == expected

pruned = extended.remove_dead_states
raise "unreachable row survived" unless pruned.size < extended.size
raise "lost the match at EOI" unless pruned.find_longest_match("ab") == expected
raise "lost the match before trailing input" unless pruned.find_longest_match("ab!") == expected
raise "unexpected match" if pruned.find_longest_match("!")
```

### Actual behavior

`remove_dead_states` raises `ArgumentError: invalid 'to' state` in
`TransitionTable#ensure_valid_state!` while rebuilding EOI transitions.

### Expected behavior

Pruning removes the unused row and preserves the delayed match for `ab`.
The state immediately after the last byte is nonaccepting. Its EOI transition
leads to the match state.

## Fix and evidence

In `src/regex/automata/dfa.cr`, dead-state removal traverses and remaps byte
edges while leaving EOI edges out of reachability and remapping. The rebuild
can then receive an old premultiplied EOI ID where it expects a compact row
index.

The local fix includes EOI edges and contextual start states in traversal,
retains paths to quit, and remaps byte and EOI targets into the new row space.
The regression lives in `spec/dfa_transform_spec.cr` in the shard checkout
and `spec/regex/automata/dfa_spec.cr` in Logos. With the patch, 197 shard DFA
specs and all 253 Logos specs passed.

The patch is available in the Logos workspace as commit
`e27d6a9524686efee526326b132b892558edbc2e` in
`temp/regex-automata-v020`. To export it from the Logos root:

```sh
git -C temp/regex-automata-v020 format-patch -1 e27d6a9 --stdout
```
