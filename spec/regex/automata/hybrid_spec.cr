require "../../spec_helper"
require "../../../lib/regex-automata/src/regex-automata"

module Regex::Automata::HybridSpec
  describe Regex::Automata::Hybrid::LazyDFA do
    it "compiles HIR and finds matches" do
      hir = Regex::Syntax.parse("hello")
      hybrid = Regex::Automata::Hybrid::LazyDFA.compile(hir)

      match = hybrid.find_longest_match("hello world")
      match.should_not be_nil
      end_pos, pattern_ids = match.as(Tuple(Int32, Array(Regex::Automata::PatternID)))
      end_pos.should eq(5)
      pattern_ids.should eq([Regex::Automata::PatternID.new(0)])
    end

    it "supports byte input" do
      hir = Regex::Syntax.parse("ab")
      hybrid = Regex::Automata::Hybrid::LazyDFA.compile(hir)

      match = hybrid.find_longest_match(Bytes[97_u8, 98_u8, 99_u8])
      match.should_not be_nil
      end_pos, _ = match.as(Tuple(Int32, Array(Regex::Automata::PatternID)))
      end_pos.should eq(2)
    end

    it "builds states lazily on demand" do
      hir = Regex::Syntax.parse("a|ab|abc")
      hybrid = Regex::Automata::Hybrid::LazyDFA.compile(hir)
      initial_size = hybrid.size
      initial_size.should be <= 2

      hybrid.find_longest_match("abc")
      hybrid.size.should be > initial_size
    end

    it "supports anchored and unanchored start states" do
      builder = Regex::Automata::NFA::Builder.new
      anchored_ref = builder.build_literal("a".to_slice)
      unanchored_ref = builder.build_literal("b".to_slice)
      builder.set_start_anchored(anchored_ref.start)
      builder.set_start_unanchored(unanchored_ref.start)

      hybrid = Regex::Automata::Hybrid::LazyDFA.new(builder.build)
      anchored = hybrid.universal_start_state(Regex::Automata::Hybrid::LazyDFA::Anchored::Yes.value)
      unanchored = hybrid.universal_start_state(Regex::Automata::Hybrid::LazyDFA::Anchored::No.value)

      anchored.should_not be_nil
      unanchored.should_not be_nil

      hybrid.find_longest_match("a", Regex::Automata::Hybrid::LazyDFA::Anchored::Yes).should_not be_nil
      hybrid.find_longest_match("a", Regex::Automata::Hybrid::LazyDFA::Anchored::No).should be_nil
      hybrid.find_longest_match("b", Regex::Automata::Hybrid::LazyDFA::Anchored::No).should_not be_nil
    end
  end
end
