require "../../spec_helper"
require "../../../lib/regex-automata/src/regex-automata"

module Regex::Automata::NFASpec
  describe NFA::Builder do
    it "creates empty builder" do
      builder = NFA::Builder.new
      builder.should be_a(NFA::Builder)
    end

    it "builds literal NFA" do
      builder = NFA::Builder.new
      bytes = "hello".to_slice
      ref = builder.build_literal(bytes)
      ref.should be_a(NFA::ThompsonRef)
      ref.start.should be_a(StateID)
      ref.end.should be_a(StateID)

      nfa = builder.build
      nfa.size.should be > 0
    end

    it "builds alternation" do
      builder = NFA::Builder.new
      left = builder.build_literal("a".to_slice)
      right = builder.build_literal("b".to_slice)
      union_ref = builder.build_alternation(left, right, PatternID.new(0))
      union_ref.should be_a(NFA::ThompsonRef)
      union_ref.start.should be_a(StateID)
      union_ref.end.should be_a(StateID)
    end

    it "builds character class" do
      builder = NFA::Builder.new
      ranges = [('a'.ord.to_u8)..('z'.ord.to_u8)]
      ref = builder.build_class(ranges)
      ref.should be_a(NFA::ThompsonRef)
      ref.start.should be_a(StateID)
      ref.end.should be_a(StateID)
    end

    it "builds concatenation" do
      builder = NFA::Builder.new
      a_ref = builder.build_literal("a".to_slice)
      b_ref = builder.build_literal("b".to_slice)
      concat_ref = builder.build_concatenation(a_ref, b_ref)
      concat_ref.should be_a(NFA::ThompsonRef)
      concat_ref.start.should be_a(StateID)
      concat_ref.end.should be_a(StateID)
      # The end of concatenation should be the end of b
      concat_ref.end.should eq(b_ref.end)
      # The start should be start of a
      concat_ref.start.should eq(a_ref.start)
    end

    it "builds kleene star repetition" do
      builder = NFA::Builder.new
      a_ref = builder.build_literal("a".to_slice)
      star_ref = builder.build_repetition(a_ref, 0, nil)
      star_ref.should be_a(NFA::ThompsonRef)
      star_ref.start.should be_a(StateID)
      star_ref.end.should be_a(StateID)
      star_ref.start.should_not eq(star_ref.end)
    end

    it "builds plus repetition" do
      builder = NFA::Builder.new
      a_ref = builder.build_literal("a".to_slice)
      plus_ref = builder.build_repetition(a_ref, 1, nil)
      plus_ref.should be_a(NFA::ThompsonRef)
      plus_ref.start.should be_a(StateID)
      plus_ref.end.should be_a(StateID)
    end

    it "builds optional repetition" do
      builder = NFA::Builder.new
      a_ref = builder.build_literal("a".to_slice)
      opt_ref = builder.build_repetition(a_ref, 0, 1)
      opt_ref.should be_a(NFA::ThompsonRef)
      opt_ref.start.should be_a(StateID)
      opt_ref.end.should be_a(StateID)
    end
  end
end
