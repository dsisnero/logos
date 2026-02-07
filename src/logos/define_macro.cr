require "regex-syntax"
require "regex-automata"

module Logos
  # Macro for defining token enums with patterns
  macro define(name, &block)
    # Parse the block to extract token definitions
    {% token_defs = [] of NamedTuple %}
    {% regex_defs = [] of NamedTuple %}
    {% error_def = nil %}

    # Process each node in the block
    {% for node in block.body.expressions %}
      {% if node.is_a?(Call) %}
        {% if node.name == "token" && node.args.size == 2 %}
          {% token_defs << {variant: node.args[1].id, pattern: node.args[0], skip: false} %}
        {% elsif node.name == "regex" && node.args.size == 2 %}
          {% regex_defs << {variant: node.args[1].id, pattern: node.args[0], skip: false} %}
        {% elsif node.name == "skip_token" && node.args.size == 2 %}
          {% token_defs << {variant: node.args[1].id, pattern: node.args[0], skip: true} %}
        {% elsif node.name == "skip_regex" && node.args.size == 2 %}
          {% regex_defs << {variant: node.args[1].id, pattern: node.args[0], skip: true} %}
        {% elsif node.name == "error" && node.args.size == 1 %}
          {% error_def = {variant: node.args[0].id} %}
        {% else %}
          {% node.raise "Unknown directive or wrong number of arguments: #{node}" %}
        {% end %}
      {% end %}
    {% end %}

    # Generate the enum with all methods
    {% begin %}
    enum {{ name }}
      # Variants
      {% for item in token_defs %}
        {{ item[:variant] }}
      {% end %}
      {% for item in regex_defs %}
        {{ item[:variant] }}
      {% end %}
      {% if error_def %}
        {{ error_def[:variant] }}
      {% end %}

      # Class variables
      @@dfa = nil.as(Regex::Automata::DFA::DFA?)
      @@pattern_to_variant = nil.as(Array(self)?)
      @@pattern_is_skip = nil.as(Array(Bool)?)
      @@error_variant = nil.as(self?)

      # DFA compilation method
      private def self.compile_dfa : Regex::Automata::DFA::DFA
        hirs = [] of ::Regex::Syntax::Hir::Hir
        pattern_to_variant = [] of self
        pattern_is_skip = [] of Bool

        # Token patterns (literals)
        {% for item in token_defs %}
          {% puts "DEBUG: token #{item[:variant]} = #{item[:pattern]}" %}
          hirs << ::Regex::Syntax::Hir::Hir.literal({{ item[:pattern] }}.to_slice)
          pattern_to_variant << {{ item[:variant] }}
          pattern_is_skip << {{ item[:skip] }}
        {% end %}

        # Regex patterns
        {% for item in regex_defs %}
          hirs << ::Regex::Syntax.parse({{ item[:pattern] }})
          pattern_to_variant << {{ item[:variant] }}
          pattern_is_skip << {{ item[:skip] }}
        {% end %}

        # Store metadata in class variables
        @@pattern_to_variant = pattern_to_variant
        @@pattern_is_skip = pattern_is_skip
        @@error_variant = {% if error_def %} {{ error_def[:variant] }} {% else %} nil {% end %}

        # If no patterns, create a DFA that never matches
        if hirs.empty?
          # Create a single dead state with no transitions
          dead_state = Regex::Automata::DFA::State.new(Regex::Automata::StateID.new(0), 256)
          256.times { |i| dead_state.set_transition(i, Regex::Automata::StateID.new(-1)) }
          return Regex::Automata::DFA::DFA.new([dead_state], Regex::Automata::StateID.new(0), 256)
        end

        # Compile NFA from multiple patterns
        hir_compiler = Regex::Automata::HirCompiler.new
        nfa = hir_compiler.compile_multi(hirs)

        # Build DFA from NFA
        dfa_builder = Regex::Automata::DFA::Builder.new(nfa)
        dfa = dfa_builder.build

        dfa
      end

      # Lazy-loaded DFA getter
      private def self.dfa : Regex::Automata::DFA::DFA
        @@dfa ||= compile_dfa
      end

      private def self.pattern_to_variant : Array(self)
        @@pattern_to_variant ||= [] of self
      end

      private def self.pattern_is_skip : Array(Bool)
        @@pattern_is_skip ||= [] of Bool
      end

      private def self.error_variant : self?
        @@error_variant
      end

      # Lex method
      def self.lex(lexer : ::Logos::Lexer(self, String, ::Logos::NoExtras, Nil)) : ::Logos::Result(self, Nil)?
        dfa = self.dfa

        # DEBUG
        if ENV["LOGOS_DEBUG"]?
          puts "DEBUG: lexer remainder = '#{lexer.remainder.inspect}' (#{lexer.remainder.class})"
        end

        # Find longest match
        match = dfa.find_longest_match(lexer.remainder)

        if match
          end_pos, pattern_ids = match

          # DEBUG
          if ENV["LOGOS_DEBUG"]?
            puts "DEBUG: matched at #{end_pos}, pattern_ids: #{pattern_ids.map(&.to_i)}"
            puts "DEBUG: matched substring: '#{lexer.remainder[0, end_pos]}'"
          end

          # Determine which variant matched (take smallest pattern ID for priority)
          pattern_id = pattern_ids.min_by(&.to_i)
          variant = pattern_to_variant[pattern_id.to_i]
          is_skip = pattern_is_skip[pattern_id.to_i]

          # Advance lexer by matched length
          lexer.bump(end_pos)

          # Return token unless it's a skip variant
          unless is_skip
            return ::Logos::Result(self, Nil).ok(variant)
          else
            # Skip variant - return nil to continue lexing
            return nil
          end
        elsif error_variant = self.error_variant
          # No pattern matched, but we have an error variant
          # Match a single UTF-8 code point
          if char = lexer.remainder[0]?
            lexer.bump(char.bytesize)
            return ::Logos::Result(self, Nil).ok(error_variant)
          else
            # End of input
            return nil
          end
        else
          # No match and no error variant
          return nil
        end
      end
    end
    {% end %}
  end
end
