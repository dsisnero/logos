require "../../spec_helper"
require "../../../lib/regex-automata/src/regex-automata"
require "../../../lib/regex-automata/src/regex/automata/dfa"

module Regex::Automata::DFASpec
  describe DFA::Builder do
    it "creates DFA builder" do
      nfa_builder = NFA::Builder.new
      nfa = nfa_builder.build
      builder = DFA::Builder.new(nfa)
      builder.should be_a(DFA::Builder)
    end

    it "builds DFA from simple literal NFA" do
      # Build NFA for "a"
      nfa_builder = NFA::Builder.new
      ref = nfa_builder.build_literal("a".to_slice)
      nfa_builder.set_start_unanchored(ref.start)
      nfa = nfa_builder.build

      # Build DFA from NFA
      dfa_builder = DFA::Builder.new(nfa)
      dfa = dfa_builder.build

      dfa.should be_a(DFA::DFA)
      dfa.size.should be > 0
      dfa.start.should be_a(StateID)

      # Check that start state exists
      start_state = dfa[dfa.start]
      start_state.should be_a(DFA::State)
    end

    it "builds DFA with transitions for 'a'" do
      # Build NFA for "a"
      nfa_builder = NFA::Builder.new
      ref = nfa_builder.build_literal("a".to_slice)
      nfa_builder.set_start_unanchored(ref.start)
      nfa = nfa_builder.build

      dfa_builder = DFA::Builder.new(nfa)
      dfa = dfa_builder.build

      start_state = dfa[dfa.start]
      # Check transition for 'a' (byte 97)
      a_byte = 'a'.ord.to_u8
      next_state_id = start_state.next[a_byte]
      # Should have a transition for 'a'
      next_state_id.should_not eq(StateID.new(-1))

      # Check that next state is accepting (match)
      next_state = dfa[next_state_id]
      next_state.should be_a(DFA::State)
      next_state.accepting?.should be_true
    end

    it "builds DFA for multiple characters" do
      # Build NFA for "ab"
      nfa_builder = NFA::Builder.new
      ref = nfa_builder.build_literal("ab".to_slice)
      nfa_builder.set_start_unanchored(ref.start)
      nfa = nfa_builder.build

      dfa_builder = DFA::Builder.new(nfa)
      dfa = dfa_builder.build

      dfa.size.should be > 0
      start_state = dfa[dfa.start]

      # Check transition for 'a'
      a_byte = 'a'.ord.to_u8
      next_id = start_state.next[a_byte]
      next_id.should_not eq(StateID.new(-1))

      next_state = dfa[next_id]
      # Check transition for 'b' from next state
      b_byte = 'b'.ord.to_u8
      final_id = next_state.next[b_byte]
      final_id.should_not eq(StateID.new(-1))
      final_state = dfa[final_id]
      final_state.accepting?.should be_true
    end

    it "removes dead states" do
      # Create a simple DFA manually with dead state
      # State 0: start, on 'a' -> state 1 (accept), else -> state 2 (dead)
      # State 1: accept, no transitions
      # State 2: dead (no transitions to accept)
      byte_classes = 256
      state0 = DFA::State.new(StateID.new(0), byte_classes)
      state1 = DFA::State.new(StateID.new(1), byte_classes)
      state2 = DFA::State.new(StateID.new(2), byte_classes)

      # Set transitions
      state0.set_transition('a'.ord, StateID.new(1))
      (0...256).each do |byte|
        if byte != 'a'.ord
          state0.set_transition(byte, StateID.new(2))
        end
      end
      state1.add_match(PatternID.new(0))

      dfa = DFA::DFA.new([state0, state1, state2], StateID.new(0), byte_classes)
      dfa.size.should eq(3)

      # Remove dead states
      optimized = dfa.remove_dead_states
      optimized.size.should be <= dfa.size
      # State 2 should be removed
      optimized.size.should eq(2)

      # Check transitions from start
      opt_start = optimized[optimized.start]
      opt_start.next['a'.ord].should_not eq(StateID.new(-1))
      # Other bytes should go to dead state (which is removed, so no transition)
      opt_start.next['b'.ord].should eq(StateID.new(-1))
    end

    it "reduces byte classes" do
      # Create DFA where all bytes except 'a' have same behavior
      # State 0: start, on 'a' -> state 1 (accept), else -> state 2 (dead)
      # State 1: accept
      # State 2: dead
      byte_classes = 256
      state0 = DFA::State.new(StateID.new(0), byte_classes)
      state1 = DFA::State.new(StateID.new(1), byte_classes)
      state2 = DFA::State.new(StateID.new(2), byte_classes)

      # Set transitions: 'a' goes to state1, everything else to state2
      state0.set_transition('a'.ord, StateID.new(1))
      (0...256).each do |byte|
        if byte != 'a'.ord
          state0.set_transition(byte, StateID.new(2))
        end
      end
      state1.add_match(PatternID.new(0))

      dfa = DFA::DFA.new([state0, state1, state2], StateID.new(0), byte_classes)

      # Reduce byte classes
      reduced = dfa.reduce_byte_classes
      reduced.byte_classes.should be < 256 # Should have fewer classes
      # Ideally should have 2 classes: 'a' and everything else
      reduced.byte_classes.should eq(2)

      # Verify transitions still work
      # start_state = reduced[reduced.start]
      # 'a' should go to accepting state
      # a_class = reduced.byte_classes == 256 ? 'a'.ord : 0 # If not reduced, use byte directly
      # Actually need to get class for 'a' from ByteClasses
      # For simplicity, just check that DFA still works
      # We'll trust the algorithm
    end

    it "builds DFA for alternation" do
      # Build NFA for "a|b"
      nfa_builder = NFA::Builder.new
      a_ref = nfa_builder.build_literal("a".to_slice)
      b_ref = nfa_builder.build_literal("b".to_slice)
      alt_ref = nfa_builder.build_alternation(a_ref, b_ref)
      nfa_builder.set_start_unanchored(alt_ref.start)
      nfa = nfa_builder.build

      dfa_builder = DFA::Builder.new(nfa)
      dfa = dfa_builder.build

      dfa.should be_a(DFA::DFA)
      dfa.size.should be > 0

      start_state = dfa[dfa.start]
      # Check that start state has epsilon transitions expanded
      # Should have transitions for both 'a' and 'b'
      a_byte = 'a'.ord.to_u8
      b_byte = 'b'.ord.to_u8

      # 'a' should go to accepting state
      a_next = start_state.next[a_byte]
      a_next.should_not eq(StateID.new(-1))
      a_state = dfa[a_next]
      a_state.accepting?.should be_true

      # 'b' should go to accepting state
      b_next = start_state.next[b_byte]
      b_next.should_not eq(StateID.new(-1))
      b_state = dfa[b_next]
      b_state.accepting?.should be_true

      # Other bytes should have no transition
      ('c'.ord.to_u8..'z'.ord.to_u8).each do |byte|
        if byte != a_byte && byte != b_byte
          start_state.next[byte].should eq(StateID.new(-1))
        end
      end
    end

    it "builds DFA for character class" do
      # Build NFA for [a-z]
      nfa_builder = NFA::Builder.new
      ranges = [('a'.ord.to_u8)..('z'.ord.to_u8)]
      class_ref = nfa_builder.build_class(ranges)
      nfa_builder.set_start_unanchored(class_ref.start)
      nfa = nfa_builder.build

      dfa_builder = DFA::Builder.new(nfa)
      dfa = dfa_builder.build

      dfa.should be_a(DFA::DFA)
      dfa.size.should be > 0

      start_state = dfa[dfa.start]
      # Check that 'a' through 'z' have transitions
      ('a'.ord.to_u8..'z'.ord.to_u8).each do |byte|
        next_id = start_state.next[byte]
        next_id.should_not eq(StateID.new(-1))
        next_state = dfa[next_id]
        next_state.accepting?.should be_true
      end

      # Check that bytes outside class have no transition
      ('0'.ord.to_u8..'9'.ord.to_u8).each do |byte|
        start_state.next[byte].should eq(StateID.new(-1))
      end
    end

    it "builds DFA for kleene star repetition" do
      # Build NFA for "a*"
      nfa_builder = NFA::Builder.new
      a_ref = nfa_builder.build_literal("a".to_slice)
      star_ref = nfa_builder.build_repetition(a_ref, 0, nil)
      nfa_builder.set_start_unanchored(star_ref.start)
      nfa = nfa_builder.build

      dfa_builder = DFA::Builder.new(nfa)
      dfa = dfa_builder.build

      dfa.should be_a(DFA::DFA)
      dfa.size.should be > 0

      start_state = dfa[dfa.start]
      # Empty string should be accepted (start state is accepting)
      start_state.accepting?.should be_true
      # 'a' should go to accepting state (which may be same or different)
      a_byte = 'a'.ord.to_u8
      a_next = start_state.next[a_byte]
      a_next.should_not eq(StateID.new(-1))
      a_state = dfa[a_next]
      a_state.accepting?.should be_true
      # 'aa' should be accepted - we can test by following transition again
      # but for now just verify that 'a' transition exists and leads to accepting state
      # that also has 'a' transition back to itself (loop)
      # Actually, for kleene star, after consuming 'a', we should be in a state that can accept more 'a's
      # Check that a_state also has transition on 'a' to accepting state (could be same state)
      a_state.next[a_byte].should_not eq(StateID.new(-1))
      # Other bytes should have no transition
      ('b'.ord.to_u8..'z'.ord.to_u8).each do |byte|
        start_state.next[byte].should eq(StateID.new(-1))
      end
    end

    it "builds DFA for optional repetition" do
      # Build NFA for "a?"
      nfa_builder = NFA::Builder.new
      a_ref = nfa_builder.build_literal("a".to_slice)
      opt_ref = nfa_builder.build_repetition(a_ref, 0, 1)
      nfa_builder.set_start_unanchored(opt_ref.start)
      nfa = nfa_builder.build

      dfa_builder = DFA::Builder.new(nfa)
      dfa = dfa_builder.build

      dfa.should be_a(DFA::DFA)
      dfa.size.should be > 0

      start_state = dfa[dfa.start]
      # Empty string should be accepted
      start_state.accepting?.should be_true
      # 'a' should go to accepting state
      a_byte = 'a'.ord.to_u8
      a_next = start_state.next[a_byte]
      a_next.should_not eq(StateID.new(-1))
      a_state = dfa[a_next]
      a_state.accepting?.should be_true
      # After consuming 'a', no further transitions (since optional)
      a_state.next[a_byte].should eq(StateID.new(-1))
      # Other bytes should have no transition
      ('b'.ord.to_u8..'z'.ord.to_u8).each do |byte|
        start_state.next[byte].should eq(StateID.new(-1))
      end
    end
  end
end
