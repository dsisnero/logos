require "./dfa"
require "./hir_compiler"

module Regex::Automata::Hybrid
  # Compatibility wrapper for regex-automata's hybrid API surface.
  # This currently delegates to the eager DFA builder.
  class LazyDFA
    getter dfa : Regex::Automata::DFA::DFA

    def initialize(nfa : Regex::Automata::NFA::NFA, byte_classes : Regex::Automata::ByteClasses | Int32 = 256)
      @dfa = Regex::Automata::DFA::Builder.new(nfa, byte_classes).build
    end

    def self.compile(hir : Regex::Syntax::Hir::Hir, utf8 : Bool = true, byte_classes : Regex::Automata::ByteClasses | Int32 = 256) : LazyDFA
      nfa = Regex::Automata::HirCompiler.new(utf8: utf8).compile(hir)
      new(nfa, byte_classes)
    end

    def find_longest_match(input : String) : Tuple(Int32, Array(Regex::Automata::PatternID))?
      @dfa.find_longest_match(input)
    end

    def find_longest_match(input : Bytes) : Tuple(Int32, Array(Regex::Automata::PatternID))?
      @dfa.find_longest_match(input)
    end

    def size : Int32
      @dfa.size
    end
  end
end
