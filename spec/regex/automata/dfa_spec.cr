require "../../spec_helper"
require "regex-automata"

module Regex::Automata::DFASpec
  def self.literal_dfa(literal : String) : DFA::DFA
    builder = NFA::Builder.new
    fragment = builder.build_literal(literal.to_slice)
    builder.set_start_unanchored(fragment.start)
    builder.set_start_anchored(fragment.start)
    DFA::Builder.from_nfa(builder.build).build
  end

  def self.assert_eoi_match(dfa : DFA::DFA, input : String) : Nil
    state = dfa.start
    dfa.is_match_state?(state).should be_false
    input.each_byte { |byte| state = dfa.next_state(state, byte) }
    dfa.is_dead_state?(state).should be_false
    dfa.is_match_state?(dfa.next_eoi_state(state)).should be_true
  end

  describe DFA::Builder do
    it "creates DFA builder" do
      DFA::Builder.new(nfa: NFA::Builder.new.build).should be_a(DFA::Builder)
    end

    it "builds DFA from simple literal NFA" do
      dfa = DFASpec.literal_dfa("a")
      dfa.size.should be > 0
      dfa[dfa.start].should be_a(DFA::State)
    end

    it "delays a literal match until the EOI transition, like Rust" do
      dfa = DFASpec.literal_dfa("a")
      after_byte = dfa.next_state(dfa.start, 'a'.ord.to_u8)
      dfa.is_match_state?(after_byte).should be_false
      DFASpec.assert_eoi_match(dfa, "a")
      dfa.find_longest_match("a").should eq({1, [PatternID.new(0)]})
    end

    it "builds DFA for multiple characters" do
      dfa = DFASpec.literal_dfa("ab")
      DFASpec.assert_eoi_match(dfa, "ab")
      dfa.find_longest_match("ab").should eq({2, [PatternID.new(0)]})
      dfa.find_longest_match("a").should be_nil
    end

    it "removes unreachable states without losing delayed matches" do
      original = DFASpec.literal_dfa("ab")
      table = original.tt.as(DFA::TransitionTable)
      states = original.states.dup
      states << DFA::State.new(StateID.new(states.size), original.byte_classes)
      extended = DFA::DFA.new(states, nil, StateID.new(table.to_index(original.start)),
        original.byte_classifier, StateID.new(table.to_index(original.start_anchored)))
      optimized = extended.remove_dead_states
      optimized.size.should be < extended.size
      DFASpec.assert_eoi_match(optimized, "ab")
      optimized.find_longest_match("ab!").should eq({2, [PatternID.new(0)]})
      optimized.find_longest_match("!").should be_nil
      optimized.is_dead_state?(DFA::DEAD_STATE_ID).should be_true
    end

    it "reduces byte classes and preserves behavior" do
      original = DFASpec.literal_dfa("a")
      reduced = original.reduce_byte_classes
      # Context-sensitive states can distinguish word/non-word bytes too.
      reduced.byte_classes.should be < 256
      DFASpec.assert_eoi_match(reduced, "a")
      reduced.find_longest_match("a").should eq({1, [PatternID.new(0)]})
      reduced.find_longest_match("b").should be_nil
    end

    it "builds DFA for alternation" do
      builder = NFA::Builder.new
      alternate = builder.build_alternation(builder.build_literal("a".to_slice),
        builder.build_literal("b".to_slice), PatternID.new(0))
      builder.set_start_unanchored(alternate.start)
      builder.set_start_anchored(alternate.start)
      dfa = DFA::Builder.from_nfa(builder.build).build
      DFASpec.assert_eoi_match(dfa, "a")
      DFASpec.assert_eoi_match(dfa, "b")
      dfa.find_longest_match("c").should be_nil
    end

    it "builds DFA for character class" do
      builder = NFA::Builder.new
      fragment = builder.build_class(['a'.ord.to_u8..'z'.ord.to_u8])
      builder.set_start_unanchored(fragment.start)
      builder.set_start_anchored(fragment.start)
      dfa = DFA::Builder.from_nfa(builder.build).build
      ('a'..'z').each { |char| DFASpec.assert_eoi_match(dfa, char.to_s) }
      dfa.find_longest_match("0").should be_nil
    end

    {"kleene star" => {nil, "aaa", 3}, "optional" => {1, "aa", 1}}.each do |name, fixture|
      it "builds DFA for #{name} repetition with delayed empty acceptance" do
        builder = NFA::Builder.new
        fragment = builder.build_repetition(builder.build_literal("a".to_slice), 0, fixture[0])
        builder.set_start_unanchored(fragment.start)
        builder.set_start_anchored(fragment.start)
        dfa = DFA::Builder.from_nfa(builder.build).build
        DFASpec.assert_eoi_match(dfa, "")
        DFASpec.assert_eoi_match(dfa, "a")
        dfa.find_longest_match("").should eq({0, [PatternID.new(0)]})
        dfa.find_longest_match(fixture[1]).should eq({fixture[2], [PatternID.new(0)]})
      end
    end
  end

  describe DFA do
    it "returns distinct anchored and unanchored universal start states" do
      builder = NFA::Builder.new
      builder.set_start_anchored(builder.build_literal("a".to_slice).start)
      builder.set_start_unanchored(builder.build_literal("b".to_slice).start)
      dfa = DFA::Builder.from_nfa(builder.build).build
      unanchored = dfa.universal_start_state(Anchored::No).as(StateID)
      anchored = dfa.universal_start_state(Anchored::Yes).as(StateID)
      dfa.is_dead_state?(dfa.next_state(unanchored, 'b'.ord.to_u8)).should be_false
      dfa.is_dead_state?(dfa.next_state(anchored, 'a'.ord.to_u8)).should be_false
      dfa.universal_start_state(Anchored::Pattern).should be_nil
    end

    it "finds longest match for literal" do
      DFASpec.literal_dfa("hello").find_longest_match("hello world").should eq({5, [PatternID.new(0)]})
    end

    it "returns nil for no match" do
      DFASpec.literal_dfa("hello").find_longest_match("goodbye").should be_nil
    end

    it "matches empty string for optional pattern" do
      DFA::Builder.new.build("a?").find_longest_match("").should eq({0, [PatternID.new(0)]})
    end

    it "finds longest match for kleene star" do
      DFA::Builder.new.build("a*").find_longest_match("aaa").should eq({3, [PatternID.new(0)]})
    end

    it "preserves matching through repeated byte-class reduction" do
      ["a", "ab", "a|b", "[a-z]", "a*", "a?", "a$"].each do |pattern|
        original = DFA::Builder.new.build(pattern)
        reduced = original.reduce_byte_classes
        reduced.byte_classes.should be < 256
        ["", "a", "ab", "b", "z", "aa", "!", "a!"].each do |input|
          reduced.find_longest_match(input).should eq(original.find_longest_match(input))
          reduced.reduce_byte_classes.find_longest_match(input).should eq(original.find_longest_match(input))
        end
      end
    end
  end
end
