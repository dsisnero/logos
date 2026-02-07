require "regex-syntax"
require "regex-automata"

module Logos
  # Macro that generates lexer implementation for an enum
  macro extended
    # Gather token variants with annotations
    {% token_variants = [] of Nil %}
    {% regex_variants = [] of Nil %}
    {% error_variant = nil %}
    {% skip_variant = nil %}

    {% for variant in @type.constants %}
      {% ann = variant.annotation(Logos::Token) %}
      {% if ann %}
        {% token_variants << {variant, ann[0]} %}
      {% end %}
      {% ann = variant.annotation(Logos::Regex) %}
      {% if ann %}
        {% regex_variants << {variant, ann[0]} %}
      {% end %}
      {% if variant.annotation(Logos::ErrorToken) %}
        {% error_variant = variant %}
      {% end %}
      {% if variant.annotation(Logos::SkipToken) %}
        {% skip_variant = variant %}
      {% end %}
    {% end %}

    # Generate pattern arrays and mapping
    private PATTERN_COUNT = {{ token_variants.size + regex_variants.size }}
    private TOKEN_PATTERNS = [
      {% for variant, source in token_variants %}
        { {{ variant }}, {{ source }} },
      {% end %}
    ]
    private REGEX_PATTERNS = [
      {% for variant, source in regex_variants %}
        { {{ variant }}, {{ source }} },
      {% end %}
    ]

    # Generate DFA compilation method
    private def self.compile_dfa : Regex::Automata::DFA::DFA
      # Collect HIRs for all patterns
      hirs = [] of Regex::Syntax::Hir::Hir
      pattern_to_variant = [] of self

      # Token patterns (literals)
      {% for variant, source in token_variants %}
        hirs << Regex::Syntax::Hir::Hir.literal({{ source }}.to_slice)
        pattern_to_variant << self::{{ variant }}
      {% end %}

      # Regex patterns
      {% for variant, source in regex_variants %}
        hirs << Regex::Syntax.parse({{ source }})
        pattern_to_variant << self::{{ variant }}
      {% end %}

      # If no patterns, create a DFA that never matches
      if hirs.empty?
        # Create a single dead state with no transitions
        dead_state = Regex::Automata::DFA::State.new(Regex::Automata::StateID.new(0), 256)
        256.times { |i| dead_state.set_transition(i, Regex::Automata::StateID.new(-1)) }
        @@pattern_to_variant = pattern_to_variant
        return Regex::Automata::DFA::DFA.new([dead_state], Regex::Automata::StateID.new(0), 256)
      end

      # Compile NFA from multiple patterns
      hir_compiler = Regex::Automata::HirCompiler.new
      nfa = hir_compiler.compile_multi(hirs)

      # Build DFA from NFA
      dfa_builder = Regex::Automata::DFA::Builder.new(nfa)
      dfa = dfa_builder.build

      # Store pattern mapping in DFA metadata (TODO: need to attach mapping)
      # For now, we'll store in a class variable
      @@pattern_to_variant = pattern_to_variant

      dfa
    end

    # Lazy-loaded DFA
    @@dfa : Regex::Automata::DFA::DFA?
    @@pattern_to_variant : Array(self)?

    private def self.dfa : Regex::Automata::DFA::DFA
      @@dfa ||= compile_dfa
    end

    private def self.pattern_to_variant : Array(self)
      @@pattern_to_variant ||= [] of self
    end

    # Generate lex method
    def self.lex(lexer : Lexer(self, String, NoExtras, Nil)) : Result(self, Nil)?
      dfa = self.dfa

      # Find longest match
      match = dfa.find_longest_match(lexer.remainder)
      return nil unless match

      end_pos, pattern_ids = match

      # Determine which variant matched (take smallest pattern ID for priority)
      pattern_id = pattern_ids.min_by(&.to_i)
      variant = pattern_to_variant[pattern_id.to_i]

      # Advance lexer by matched length
      lexer.bump(end_pos)

      # Return token
      Result(self, Nil).ok(variant)
    end
  end
end
