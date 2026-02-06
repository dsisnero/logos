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
      start_id = builder.build_literal(bytes)
      start_id.should be_a(StateID)

      nfa = builder.build
      nfa.size.should be > 0
    end

    it "builds alternation" do
      builder = NFA::Builder.new
      left = builder.build_literal("a".to_slice)
      right = builder.build_literal("b".to_slice)
      union_id = builder.build_alternation(left, right)
      union_id.should be_a(StateID)
    end

    it "builds character class" do
      builder = NFA::Builder.new
      ranges = [('a'.ord.to_u8)..('z'.ord.to_u8)]
      state_id = builder.build_class(ranges)
      state_id.should be_a(StateID)
    end

    pending "builds concatenation" do
    end

    pending "builds repetition" do
    end
  end
end
