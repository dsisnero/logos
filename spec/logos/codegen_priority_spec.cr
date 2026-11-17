require "../spec_helper"
{% if flag?(:codegen_library) %}
  require "../../src/logos_codegen"

  describe Logos::Codegen do
    it "resolves the highest priority independently of pattern order" do
      patterns = JSON.parse(%([{"resolved_priority":1},{"resolved_priority":3}])).as_a
      Logos::Codegen.resolve_accept([0, 1], patterns).should eq(1)
      Logos::Codegen.resolve_accept([1, 0], patterns).should eq(1)
      Logos::Codegen.resolve_accept([] of Int32, patterns).should be_nil
    end

    it "emits inferred literal and regexp priorities for generic matchers" do
      patterns = JSON.parse(%([{"kind":"token","pattern":"é"},{"kind":"regex","pattern":"é"}])).as_a
      source = Logos::Codegen.emit_matcher(patterns, {} of String => String, true, "UnicodePriority")
      source.should end_with(", [4, 2] of Int32)")
    end

    it "groups subpattern alternatives while compiling the manifest" do
      patterns = JSON.parse(%([{"kind":"regex","pattern":"~(?&part)+"},{"kind":"token","pattern":"(?&part)"}])).as_a
      dfa = Logos::Codegen.compile_dfa(patterns, {"part" => "a|b"}, true)

      dfa.find_longest_match_at_start("~abba").should eq({5, [Regex::Automata::PatternID.new(0)]})
      dfa.find_longest_match_at_start("bbb").should be_nil
      dfa.find_longest_match_at_start("(?&part)").should eq({8, [Regex::Automata::PatternID.new(1)]})
    end

    it "preserves first-match ties and rejects explicit ambiguity" do
      patterns = JSON.parse(%([{"resolved_priority":3},{"resolved_priority":3}])).as_a
      Logos::Codegen.resolve_accept([1, 0], patterns).should eq(1)
      patterns = JSON.parse(%([{"resolved_priority":3,"priority_explicit":true},{"resolved_priority":3,"priority_explicit":true}])).as_a
      expect_raises(Exception, /can match simultaneously/) { Logos::Codegen.resolve_accept([0, 1], patterns) }
    end
  end
{% end %}
