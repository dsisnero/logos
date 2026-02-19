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
  end
end
