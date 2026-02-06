require "./spec_helper"
require "../../regex-syntax/src/regex-syntax"

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
end