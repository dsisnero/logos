require "./spec_helper"
require "../../regex-syntax/src/regex-syntax"
require "../../regex-automata/src/regex/automata/dfa"

describe Regex::Automata::HirCompiler do
  it "compiles literal" do
    hir = Regex::Syntax.parse("hello")
    compiler = Regex::Automata::HirCompiler.new
    nfa = compiler.compile(hir)
    nfa.should be_a(Regex::Automata::NFA::NFA)
    nfa.size.should be > 0
  end

  it "compiles alternation" do
    hir = Regex::Syntax.parse("a|b")
    compiler = Regex::Automata::HirCompiler.new
    nfa = compiler.compile(hir)
    nfa.should be_a(Regex::Automata::NFA::NFA)
    nfa.size.should be > 0
  end

  it "compiles character class" do
    hir = Regex::Syntax.parse("[a-z]")
    compiler = Regex::Automata::HirCompiler.new
    nfa = compiler.compile(hir)
    nfa.should be_a(Regex::Automata::NFA::NFA)
    nfa.size.should be > 0
  end

  it "compiles repetition" do
    hir = Regex::Syntax.parse("a*")
    compiler = Regex::Automata::HirCompiler.new
    nfa = compiler.compile(hir)
    nfa.should be_a(Regex::Automata::NFA::NFA)
    nfa.size.should be > 0
  end

  it "compiles concatenation" do
    hir = Regex::Syntax.parse("ab")
    compiler = Regex::Automata::HirCompiler.new
    nfa = compiler.compile(hir)
    nfa.should be_a(Regex::Automata::NFA::NFA)
    nfa.size.should be > 0
  end

  it "compiles dot" do
    hir = Regex::Syntax.parse(".")
    compiler = Regex::Automata::HirCompiler.new
    nfa = compiler.compile(hir)
    nfa.should be_a(Regex::Automata::NFA::NFA)
    nfa.size.should be > 0
  end

  it "compiles escape sequences" do
    hir = Regex::Syntax.parse("\\n")
    compiler = Regex::Automata::HirCompiler.new
    nfa = compiler.compile(hir)
    nfa.should be_a(Regex::Automata::NFA::NFA)
    nfa.size.should be > 0
  end

  it "compiles multiple patterns with unique IDs" do
    hirs = ["a", "b", "c"].map { |pat| Regex::Syntax.parse(pat) }
    compiler = Regex::Automata::HirCompiler.new
    nfa = compiler.compile_multi(hirs)
    nfa.should be_a(Regex::Automata::NFA::NFA)
    nfa.size.should be > 0
    nfa.start_pattern.size.should eq(3)
  end

  it "matches correct pattern IDs with DFA" do
    hirs = ["a", "b", "c"].map { |pat| Regex::Syntax.parse(pat) }
    compiler = Regex::Automata::HirCompiler.new
    nfa = compiler.compile_multi(hirs)
    
    dfa_builder = Regex::Automata::DFA::Builder.new(nfa)
    dfa = dfa_builder.build
    
    # Test each pattern
    match = dfa.find_longest_match("a")
    match.should_not be_nil
    end_pos, pattern_ids = match.not_nil!
    end_pos.should eq(1)
    pattern_ids.should eq([Regex::Automata::PatternID.new(0)])
    
    match = dfa.find_longest_match("b")
    match.should_not be_nil
    end_pos, pattern_ids = match.not_nil!
    pattern_ids.should eq([Regex::Automata::PatternID.new(1)])
    
    match = dfa.find_longest_match("c")
    match.should_not be_nil
    end_pos, pattern_ids = match.not_nil!
    pattern_ids.should eq([Regex::Automata::PatternID.new(2)])
    
    match = dfa.find_longest_match("d")
    match.should be_nil
  end
end