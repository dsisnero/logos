require "regex-syntax"
require "regex-automata"

module Logos
  # Macro for defining token enums with patterns
  macro define(name, &block)
    # Parse the block to extract token definitions
    {% token_defs = [] of NamedTuple %}
    {% regex_defs = [] of NamedTuple %}
    {% error_def = nil %}
    {% extras_type = ::Logos::NoExtras %}
    {% error_type = Nil %}

    # Process each node in the block
    {% nodes = [] of Crystal::Macros::ASTNode %}
    {% if block.body.is_a?(Expressions) %}
      {% nodes = block.body.expressions %}
    {% else %}
      {% nodes = [block.body] %}
    {% end %}

    {% for node in nodes %}
      {% if node.is_a?(Call) %}
        # Extract callback from block or named arguments
        {% callback = nil %}
        {% priority = nil %}
        {% if node.block %}
          {% callback = node.block %}
        {% elsif node.named_args %}
          {% found_callback = false %}
          {% found_priority = false %}
          {% for named_arg in node.named_args %}
            {% if named_arg.name == "callback" %}
              {% callback = named_arg.value %}
              {% found_callback = true %}
            {% elsif named_arg.name == "priority" %}
              {% priority = named_arg.value %}
              {% found_priority = true %}
            {% end %}
          {% end %}
        {% end %}

        {% if node.name == "token" && node.args.size == 2 %}
          {% token_defs << {variant: node.args[1].id, pattern: node.args[0], skip: false, callback: callback, priority: priority} %}
        {% elsif node.name == "regex" && node.args.size == 2 %}
          {% regex_defs << {variant: node.args[1].id, pattern: node.args[0], skip: false, callback: callback, priority: priority} %}
        {% elsif node.name == "skip_token" && node.args.size == 2 %}
          {% token_defs << {variant: node.args[1].id, pattern: node.args[0], skip: true, callback: callback, priority: priority} %}
        {% elsif node.name == "skip_regex" && node.args.size == 2 %}
          {% regex_defs << {variant: node.args[1].id, pattern: node.args[0], skip: true, callback: callback, priority: priority} %}
        {% elsif node.name == "error" && node.args.size == 1 %}
          {% error_def = {variant: node.args[0].id, callback: callback, priority: priority} %}
        {% elsif node.name == "extras" && node.args.size == 1 %}
          {% extras_type = node.args[0] %}
        {% elsif node.name == "error_type" && node.args.size == 1 %}
          {% error_type = node.args[0] %}
        {% else %}
          {% node.raise "Unknown directive or wrong number of arguments: #{node}" %}
        {% end %}
      {% end %}
    {% end %}

    {% all_defs = token_defs + regex_defs %}
    {% has_callbacks = all_defs.any? { |item| item[:callback] } %}



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
      @@dfa = nil.as(::Regex::Automata::DFA::DFA?)
      @@pattern_to_variant = nil.as(Array(self)?)
      @@pattern_is_skip = nil.as(Array(Bool)?)
      @@pattern_priority = nil.as(Array(Int32)?)
      @@error_variant = nil.as(self?)

      # DFA compilation method
      private def self.compile_dfa : ::Regex::Automata::DFA::DFA
        if ENV["LOGOS_DEBUG"]?
          puts "DEBUG: compile_dfa called"
        end
        hirs = [] of ::Regex::Syntax::Hir::Hir
        pattern_to_variant = [] of self
        pattern_is_skip = [] of Bool
        pattern_priority = [] of Int32

        # Token patterns (literals)
        {% for item, index in token_defs %}
          hir = ::Regex::Syntax::Hir::Hir.literal({{ item[:pattern] }}.to_slice)
          hirs << hir
          pattern_to_variant << {{ item[:variant] }}
          pattern_is_skip << {{ item[:skip] }}
          # Use explicit priority if set, otherwise Hir complexity
          {% if item[:priority] %}
            pattern_priority << {{ item[:priority] }}
          {% else %}
            pattern_priority << hir.complexity
          {% end %}
        {% end %}

        # Regex patterns
        {% for item, index in regex_defs %}
          hir = ::Regex::Syntax.parse({{ item[:pattern] }})
          hirs << hir
          pattern_to_variant << {{ item[:variant] }}
          pattern_is_skip << {{ item[:skip] }}
          # Use explicit priority if set, otherwise Hir complexity
          {% if item[:priority] %}
            pattern_priority << {{ item[:priority] }}
          {% else %}
            pattern_priority << hir.complexity
          {% end %}
        {% end %}

        # Store metadata in class variables
        @@pattern_to_variant = pattern_to_variant
        @@pattern_is_skip = pattern_is_skip
        @@pattern_priority = pattern_priority
        @@error_variant = {% if error_def %} {{ error_def[:variant] }} {% else %} nil {% end %}

        # DEBUG: Print priorities
        if ENV["LOGOS_DEBUG_PRIORITY"]?
          puts "Pattern priorities:"
          pattern_to_variant.each_with_index do |variant, i|
            puts "  Pattern #{i}: #{variant} = #{pattern_priority[i]}"
          end
        end

        # If no patterns, create a DFA that never matches
        if hirs.empty?
          # Create a single dead state with no transitions
          dead_state = ::Regex::Automata::DFA::State.new(::Regex::Automata::StateID.new(0), 256)
          256.times { |i| dead_state.set_transition(i, ::Regex::Automata::StateID.new(-1)) }
          return ::Regex::Automata::DFA::DFA.new([dead_state], ::Regex::Automata::StateID.new(0), 256)
        end

        # Compile NFA from multiple patterns
        hir_compiler = ::Regex::Automata::HirCompiler.new
        nfa = hir_compiler.compile_multi(hirs)

        # Build DFA from NFA
        dfa_builder = ::Regex::Automata::DFA::Builder.new(nfa)
        dfa = dfa_builder.build

        dfa
      end

      # Lazy-loaded DFA getter
      private def self.dfa : ::Regex::Automata::DFA::DFA
        @@dfa ||= compile_dfa
      end

      private def self.pattern_to_variant : Array(self)
        @@pattern_to_variant ||= [] of self
      end

      private def self.pattern_is_skip : Array(Bool)
        @@pattern_is_skip ||= [] of Bool
      end

      private def self.pattern_priority : Array(Int32)
        @@pattern_priority ||= [] of Int32
      end

      private def self.error_variant : self?
        @@error_variant
      end

      # Lex method
      def self.lex(lexer : ::Logos::Lexer(self, ::String, {{ extras_type }}, {{ error_type }})) : ::Logos::Result(self, {{ error_type }})?
        dfa = self.dfa
        pattern_to_variant = self.pattern_to_variant
        pattern_is_skip = self.pattern_is_skip
        pattern_priority = self.pattern_priority

        # DEBUG
        if ENV["LOGOS_DEBUG"]?
          puts "DEBUG: lexer remainder = '#{lexer.remainder.inspect}' (#{lexer.remainder.class})"
        end

        # Find longest match
        match = dfa.find_longest_match(lexer.remainder)
        if ENV["LOGOS_DEBUG"]?
          puts "DEBUG: find_longest_match returned: #{match.inspect}"
        end

        if match
          end_pos, pattern_ids = match

          # DEBUG
          if ENV["LOGOS_DEBUG"]?
            puts "DEBUG: matched at #{end_pos}, pattern_ids: #{pattern_ids.map(&.to_i)}"
            puts "DEBUG: matched substring: '#{lexer.remainder[0, end_pos]}'"
            if pattern_ids.empty?
              puts "DEBUG: WARNING: pattern_ids empty but match state accepting"
            end
          end

          # Determine which variant matched (take pattern with highest priority)
          pattern_id = if pattern_ids.size == 1
                         pattern_ids[0]
                       else
                         pattern_ids.max_by { |id| pattern_priority[id.to_i] }
                       end
          variant = pattern_to_variant[pattern_id.to_i]
          is_skip = pattern_is_skip[pattern_id.to_i]

          # Advance lexer by matched length
          lexer.bump(end_pos)

          # Call callback if any
          {% if has_callbacks %}
            case pattern_id.to_i
            {% for i in 0...all_defs.size %}
              {% item = all_defs[i] %}
              {% if item[:callback] %}
               {% puts "DEBUG: Generating callback for pattern #{i}: #{item[:variant]}" %}
                 {% puts "DEBUG: Callback body: #{item[:callback].body}" %}
                 {% cb = item[:callback] %}
             when {{ i }}
              {% if cb.args.size == 1 %}
                {{ cb.args[0].id }} = lexer
              {% end %}
              __callback_result = begin
                {{ cb.body }}
              end
              if ENV["LOGOS_DEBUG"]?
                puts "DEBUG: Callback result: #{__callback_result.inspect}, type: #{__callback_result.class}"
              end

              # Handle FilterResult::Error
              if __callback_result.is_a?(::Logos::FilterResult::Error)
                error_value = __callback_result.error
                if ENV["LOGOS_DEBUG"]?
                  puts "DEBUG: Callback returned FilterResult::Error, returning error: #{error_value.inspect}"
                end
                return ::Logos::Result(self, {{ error_type }}).error(error_value)
              end

              # Handle Skip types
              if __callback_result.is_a?(::Logos::Skip) ||
                 __callback_result.is_a?(::Logos::Filter::Skip) ||
                 __callback_result.is_a?(::Logos::FilterResult::Skip)
                if ENV["LOGOS_DEBUG"]?
                  puts "DEBUG: Callback returned Skip, skipping token"
                end
                return nil
              end

                # Handle Filter::Emit and FilterResult::Emit - ignore value for now
                if __callback_result.is_a?(::Logos::Filter::Emit) ||
                   __callback_result.is_a?(::Logos::FilterResult::Emit)
                  if ENV["LOGOS_DEBUG"]?
                    puts "DEBUG: Callback returned Emit with value, ignoring value for now"
                  end
                  # TODO: Store emitted value somewhere
                end
              {% end %}
            {% end %}
            end
          {% end %}

          # Return token unless it's a skip variant
          unless is_skip
            return ::Logos::Result(self, {{ error_type }}).ok(variant)
          else
            # Skip variant - return nil to continue lexing
            return nil
          end
        elsif error_variant = self.error_variant
          # No pattern matched, but we have an error variant
          # Match a single UTF-8 code point
          if char = lexer.remainder[0]?
            lexer.bump(char.bytesize)
            return ::Logos::Result(self, {{ error_type }}).ok(error_variant)
          else
            # End of input
            return nil
          end
         else
           # No match and no error variant
           if ENV["LOGOS_DEBUG"]?
             puts "DEBUG: no match for remainder: '#{lexer.remainder.inspect}' (bytes: #{lexer.remainder.to_slice.hexdump if lexer.remainder.responds_to?(:to_slice)})"
           end
           return nil
        end
      end
    end
    {% end %}
  end
end
