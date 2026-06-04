require "../../spec_helper"
require "../../../lib/regex-automata/src/regex-automata"

module Regex::Automata::HybridSpec
  describe Regex::Automata::Hybrid::Regex do
    it "compiles patterns and finds matches" do
      hybrid = Regex::Automata::Hybrid::Regex.new("hello")
      cache = hybrid.create_cache

      match = hybrid.find(cache, "hello world")
      match.should_not be_nil
      match.not_nil!.start.should eq(0)
      match.not_nil!.end.should eq(5)
      match.not_nil!.pattern.should eq(Regex::Automata::PatternID.new(0))
    end

    it "supports byte input" do
      hybrid = Regex::Automata::Hybrid::Regex.new("ab")
      cache = hybrid.create_cache

      match = hybrid.find(cache, Bytes[97_u8, 98_u8, 99_u8])
      match.should_not be_nil
      match.not_nil!.start.should eq(0)
      match.not_nil!.end.should eq(2)
    end
  end

  describe Regex::Automata::Hybrid::DFA do
    it "supports anchored and unanchored start states" do
      builder = Regex::Automata::NFA::Builder.new
      anchored_ref = builder.build_literal("a".to_slice)
      unanchored_ref = builder.build_literal("b".to_slice)
      builder.set_start_anchored(anchored_ref.start)
      builder.set_start_unanchored(unanchored_ref.start)

      hybrid = Regex::Automata::Hybrid::Builder.new.build_from_nfa(builder.build)
      anchored = hybrid.universal_start_state(Regex::Automata::Anchored::Yes)
      unanchored = hybrid.universal_start_state(Regex::Automata::Anchored::No)

      anchored.should_not be_nil
      unanchored.should_not be_nil
    end
  end
end
