require "regex-syntax"
require "regex-automata"
require "set"

module Logos
  # Macro for defining token enums with patterns
  macro define(name, &block)
    # Parse the block to extract token definitions
    {% token_defs = [] of NamedTuple %}
    {% regex_defs = [] of NamedTuple %}
    {% subpatterns = [] of NamedTuple %}
    {% error_def = nil %}
    {% error_callback = nil %}
    {% extras_type = ::Logos::NoExtras %}
    {% error_type = Nil %}
    {% utf8_flag = true %}

    # Process each node in the block
    {% nodes = [] of Crystal::Macros::ASTNode %}
    {% if block.body.is_a?(Expressions) %}
      {% nodes = block.body.expressions %}
    {% else %}
      {% nodes = [block.body] %}
    {% end %}

    # Helper to parse variant definition
    {% def parse_variant(variant_node)
         # variant_node could be SymbolLiteral (:Else) or Call (Integer(Int64))
         if variant_node.is_a?(SymbolLiteral)
           {name: variant_node.id, type: nil, ast: variant_node.id}
         elsif variant_node.is_a?(Call)
           # Call like Integer(Int64)
           # Extract type argument (first argument)
           type = variant_node.args[0] if variant_node.args.size > 0
           {name: variant_node.name.id, type: type, ast: variant_node}
         else
           # Assume it's already an identifier
           {name: variant_node.id, type: nil, ast: variant_node}
         end
       end %}

    {% for node in nodes %}
      {% if node.is_a?(Call) %}
        # Extract callback from block or named arguments
        {% callback = nil %}
        {% priority = nil %}
        {% ignore_case = false %}
        {% allow_greedy = false %}
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
            {% elsif named_arg.name == "ignore_case" || named_arg.name == "ignore_ascii_case" %}
              {% ignore_case = named_arg.value %}
            {% elsif named_arg.name == "allow_greedy" %}
              {% allow_greedy = named_arg.value %}
            {% end %}
          {% end %}
        {% end %}

        {% if node.name == "subpattern" && node.args.size == 2 %}
          {% name_node = node.args[0] %}
          {% pattern_node = node.args[1] %}
          {% subpattern_name = name_node.stringify %}
          {% if subpattern_name.starts_with?(":") %}
            {% subpattern_name = subpattern_name[1..-1] %}
          {% end %}
          {% if subpattern_name.starts_with?("\"") && subpattern_name.ends_with?("\"") %}
            {% subpattern_name = subpattern_name[1..-2] %}
          {% end %}
          {% subpattern_name = subpattern_name.split("\"").join("") %}
          {% subpattern_name = subpattern_name.split("\\\\").join("") %}
          {% unless pattern_node.is_a?(StringLiteral) %}
            {% node.raise "subpattern pattern must be a string literal" %}
          {% end %}
          {% pattern_value = pattern_node.stringify[1..-2] %}
          {% subpatterns << {name: subpattern_name, pattern: pattern_value} %}
        {% elsif node.name == "token" && node.args.size == 2 %}
          {% variant = node.args[1] %}
          {% if variant.is_a?(SymbolLiteral) %}
            {% variant = variant.id %}
          {% end %}
          {% token_defs << {variant: variant, pattern: node.args[0], skip: false, callback: callback, priority: priority, ignore_case: ignore_case, allow_greedy: allow_greedy} %}
        {% elsif node.name == "regex" && node.args.size == 2 %}
          {% variant = node.args[1] %}
          {% if variant.is_a?(SymbolLiteral) %}
            {% variant = variant.id %}
          {% end %}
          {% regex_defs << {variant: variant, pattern: node.args[0], skip: false, callback: callback, priority: priority, ignore_case: ignore_case, allow_greedy: allow_greedy} %}
        {% elsif node.name == "skip_token" && node.args.size == 2 %}
          {% variant = node.args[1] %}
          {% if variant.is_a?(SymbolLiteral) %}
            {% variant = variant.id %}
          {% end %}
          {% token_defs << {variant: variant, pattern: node.args[0], skip: true, callback: callback, priority: priority, ignore_case: ignore_case, allow_greedy: allow_greedy} %}
        {% elsif node.name == "skip_regex" && node.args.size == 2 %}
          {% variant = node.args[1] %}
          {% if variant.is_a?(SymbolLiteral) %}
            {% variant = variant.id %}
          {% end %}
          {% regex_defs << {variant: variant, pattern: node.args[0], skip: true, callback: callback, priority: priority, ignore_case: ignore_case, allow_greedy: allow_greedy} %}
        {% elsif node.name == "error" && node.args.size == 1 %}
          {% variant = node.args[0] %}
          {% if variant.is_a?(SymbolLiteral) %}
            {% variant = variant.id %}
          {% end %}
          {% error_def = {variant: variant, callback: callback, priority: priority} %}
        {% elsif node.name == "extras" && node.args.size == 1 %}
          {% extras_type = node.args[0] %}
        {% elsif node.name == "error_type" && node.args.size == 1 %}
          {% error_type = node.args[0] %}
          {% if callback %}
            {% error_callback = callback %}
          {% end %}
        {% elsif node.name == "utf8" && node.args.size == 1 %}
          {% utf8_flag = node.args[0] %}
        {% else %}
          {% node.raise "Unknown directive or wrong number of arguments: #{node}" %}
        {% end %}
      {% end %}
    {% end %}

    {% all_defs = token_defs + regex_defs %}
    {% has_callbacks = all_defs.any? { |item| item[:callback] } %}

    # Collect unique variants (outside begin block to avoid nested macro issues)
    {% unique_variant_ids = [] of String %}
    {% unique_variants = [] of Crystal::ASTNode %}
    {% for item in token_defs %}
      {% variant = item[:variant] %}
      {% if variant.is_a?(Call) %}
        {% variant_id = variant.name.id.stringify %}
      {% else %}
        {% variant_id = variant.id.stringify %}
      {% end %}
      {% unless unique_variant_ids.includes?(variant_id) %}
        {% unique_variant_ids << variant_id %}
        {% unique_variants << variant %}
      {% end %}
    {% end %}
    {% for item in regex_defs %}
      {% variant = item[:variant] %}
      {% if variant.is_a?(Call) %}
        {% variant_id = variant.name.id.stringify %}
      {% else %}
        {% variant_id = variant.id.stringify %}
      {% end %}
      {% unless unique_variant_ids.includes?(variant_id) %}
        {% unique_variant_ids << variant_id %}
        {% unique_variants << variant %}
      {% end %}
    {% end %}
    {% if error_def %}
      {% variant = error_def[:variant] %}
      {% if variant.is_a?(Call) %}
        {% variant_id = variant.name.id.stringify %}
      {% else %}
        {% variant_id = variant.id.stringify %}
      {% end %}
      {% unless unique_variant_ids.includes?(variant_id) %}
        {% unique_variant_ids << variant_id %}
        {% unique_variants << variant %}
      {% end %}
    {% end %}

    # Generate the enum with all methods
    {% begin %}

    enum {{ name }}
      # Variants (deduplicated)
      {% for variant in unique_variants %}
        {{ variant }}
      {% end %}

      {% if subpatterns.size > 0 %}
        private def self.subpatterns : Array(Tuple(String, String))
          [
            {% for sub in subpatterns %}
              { {{ sub[:name] }}, {{ sub[:pattern] }} },
            {% end %}
          ]
        end

        private def self.substitute_subpatterns(pattern : String) : String
          expanded = [] of Tuple(String, String)
          subpatterns.each do |entry|
            name = entry[0]
            pat = entry[1]
            expanded_pat = pat
            expanded.each do |prev|
              expanded_pat = expanded_pat.gsub("(?&#{prev[0]})", "(?:#{prev[1]})")
            end
            expanded << {name, expanded_pat}
          end

          result = pattern
          expanded.each do |entry|
            result = result.gsub("(?&#{entry[0]})", "(?:#{entry[1]})")
          end

          if result.includes?("(?&")
            raise "unknown subpattern reference in pattern: #{result}"
          end

          result
        end
      {% end %}

      private def self.greedy_pattern_message : ::String
        "This pattern contains an unbounded greedy dot repetition, i.e. `.*` or `.+` (or an equivalent class). This can consume the entire input for each token. Prefer a non-greedy repetition or a more specific class. If intentional, set allow_greedy: true."
      end

      private def self.patterns_overlap?(left_hir : ::Regex::Syntax::Hir::Hir, right_hir : ::Regex::Syntax::Hir::Hir) : Bool
        left_nfa = ::Regex::Automata::HirCompiler.new(utf8: {{ utf8_flag }}).compile(left_hir)
        right_nfa = ::Regex::Automata::HirCompiler.new(utf8: {{ utf8_flag }}).compile(right_hir)
        left_dfa = ::Regex::Automata::DFA::Builder.new(left_nfa).build
        right_dfa = ::Regex::Automata::DFA::Builder.new(right_nfa).build

        queue = [{left_dfa.start, right_dfa.start}]
        visited = Set(Tuple(::Regex::Automata::StateID, ::Regex::Automata::StateID)).new

        until queue.empty?
          left_id, right_id = queue.shift
          pair = {left_id, right_id}
          next if visited.includes?(pair)
          visited.add(pair)

          left_state = left_dfa[left_id]
          right_state = right_dfa[right_id]
          return true if left_state.accepting? && right_state.accepting?

          256.times do |byte|
            byte_u8 = byte.to_u8
            left_next = left_state.next[left_dfa.byte_classifier[byte_u8]]
            right_next = right_state.next[right_dfa.byte_classifier[byte_u8]]
            next if left_next.to_i < 0 || right_next.to_i < 0
            queue << {left_next, right_next}
          end
        end

        false
      end

      @@compiled = nil.as(NamedTuple(
        dfa: ::Regex::Automata::DFA::DFA,
        pattern_to_variant: Array(self),
        pattern_is_skip: Array(Bool),
        pattern_priority: Array(Int32),
        error_variant: self?
      )?)

      # DFA compilation method
      private def self.compile_dfa : NamedTuple(
        dfa: ::Regex::Automata::DFA::DFA,
        pattern_to_variant: Array(self),
        pattern_is_skip: Array(Bool),
        pattern_priority: Array(Int32),
        error_variant: self?
      )
        if ENV["LOGOS_DEBUG"]?
          puts "DEBUG: compile_dfa called"
        end
        hirs = [] of ::Regex::Syntax::Hir::Hir
        pattern_to_variant = [] of self
        pattern_is_skip = [] of Bool
        pattern_priority = [] of Int32
        pattern_priority_explicit = [] of Bool
        pattern_text = [] of ::String
        pattern_variant_name = [] of ::String

        # Token patterns (literals)
        {% for item, index in token_defs %}
          {% pattern_node = item[:pattern] %}
          {% if subpatterns.size > 0 %}
            pattern_source = self.substitute_subpatterns({{ pattern_node }})
            pattern_uses_subpattern = {{ pattern_node }}.includes?("(?&")
            hir = ::Regex::Syntax::Hir::Hir.literal(pattern_source.to_slice)
          {% else %}
            pattern_uses_subpattern = false
            hir = ::Regex::Syntax::Hir::Hir.literal({{ pattern_node }}.to_slice)
          {% end %}
        {% if item[:ignore_case] %}
            {% if utf8_flag %}
              hir = ::Regex::Syntax::Hir.case_fold_unicode(hir)
            {% else %}
              hir = ::Regex::Syntax::Hir.case_fold_ascii(hir)
            {% end %}
        {% end %}
          {% unless item[:allow_greedy] %}
            if hir.has_greedy_all?
              raise self.greedy_pattern_message
            end
          {% end %}
          if pattern_uses_subpattern && hir.can_match_empty?
            raise "The pattern #{ {{ pattern_node }}.inspect } for variant #{ {{ item[:variant] }} } can match the empty string, which is unsupported by logos."
          end
          hirs << hir
          pattern_to_variant << {{ item[:variant] }}
          pattern_is_skip << {{ item[:skip] }}
          pattern_text << {{ pattern_node }}.inspect
          pattern_variant_name << {{ item[:variant] }}.to_s
          # Use explicit priority if set, otherwise Hir complexity
          {% if item[:priority] %}
            pattern_priority << {{ item[:priority] }}
            pattern_priority_explicit << true
          {% else %}
            pattern_priority << hir.complexity
            pattern_priority_explicit << false
          {% end %}
        {% end %}

        # Regex patterns
        {% for item, index in regex_defs %}
          {% pattern_node = item[:pattern] %}
          {% if subpatterns.size > 0 %}
            pattern_source = self.substitute_subpatterns({{ pattern_node }})
            pattern_uses_subpattern = {{ pattern_node }}.includes?("(?&")
            hir = ::Regex::Syntax.parse(pattern_source, unicode: {{ utf8_flag }})
          {% else %}
            pattern_uses_subpattern = false
            hir = ::Regex::Syntax.parse({{ pattern_node }}, unicode: {{ utf8_flag }})
          {% end %}
          {% if item[:ignore_case] %}
            {% if utf8_flag %}
              hir = ::Regex::Syntax::Hir.case_fold_unicode(hir)
            {% else %}
              hir = ::Regex::Syntax::Hir.case_fold_ascii(hir)
            {% end %}
        {% end %}
          {% unless item[:allow_greedy] %}
            if hir.has_greedy_all?
              raise self.greedy_pattern_message
            end
          {% end %}
          if pattern_uses_subpattern && hir.can_match_empty?
            raise "The pattern #{ {{ pattern_node }}.inspect } for variant #{ {{ item[:variant] }} } can match the empty string, which is unsupported by logos."
          end
          hirs << hir
          pattern_to_variant << {{ item[:variant] }}
          pattern_is_skip << {{ item[:skip] }}
          pattern_text << {{ pattern_node }}.inspect
          pattern_variant_name << {{ item[:variant] }}.to_s
          # Use explicit priority if set, otherwise Hir complexity
          {% if item[:priority] %}
            pattern_priority << {{ item[:priority] }}
            pattern_priority_explicit << true
          {% else %}
            pattern_priority << hir.complexity
            pattern_priority_explicit << false
          {% end %}
        {% end %}

        error_variant = {% if error_def %} {{ error_def[:variant] }} {% else %} nil {% end %}

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
          dfa = ::Regex::Automata::DFA::DFA.new([dead_state], ::Regex::Automata::StateID.new(0), 256)
          return {dfa: dfa, pattern_to_variant: pattern_to_variant, pattern_is_skip: pattern_is_skip, pattern_priority: pattern_priority, error_variant: error_variant}
        end

        hirs.size.times do |i|
          (i + 1...hirs.size).each do |j|
            next unless pattern_priority_explicit[i] && pattern_priority_explicit[j]
            next unless pattern_priority[i] == pattern_priority[j]
            if self.patterns_overlap?(hirs[i], hirs[j])
              raise "The pattern #{pattern_text[i]} (#{pattern_variant_name[i]}) can match simultaneously with #{pattern_text[j]} (#{pattern_variant_name[j]}) at priority #{pattern_priority[i]}."
            end
          end
        end

        # Compile NFA from multiple patterns
        hir_compiler = ::Regex::Automata::HirCompiler.new(utf8: {{ utf8_flag }})
        nfa = hir_compiler.compile_multi(hirs)

        # Build DFA from NFA
        dfa_builder = ::Regex::Automata::DFA::Builder.new(nfa)
        dfa = dfa_builder.build

        {dfa: dfa, pattern_to_variant: pattern_to_variant, pattern_is_skip: pattern_is_skip, pattern_priority: pattern_priority, error_variant: error_variant}
      end

      # Lazy-loaded DFA getter
      private def self.compiled : NamedTuple(
        dfa: ::Regex::Automata::DFA::DFA,
        pattern_to_variant: Array(self),
        pattern_is_skip: Array(Bool),
        pattern_priority: Array(Int32),
        error_variant: self?
      )
        @@compiled ||= compile_dfa
      end

      # Lex method
      {% source_type = utf8_flag ? "::String".id : "::Slice(::UInt8)".id %}
      def self.lexer(source : {{ source_type }}) : ::Logos::Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }})
        ::Logos::Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }}).new(source)
      end

      def self.lexer_with_extras(source : {{ source_type }}, extras : {{ extras_type }}) : ::Logos::Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }})
        ::Logos::Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }}).new(source, extras)
      end

      def self.lex_all(source : {{ source_type }}, extras : {{ extras_type }} = {{ extras_type }}.new) : Array(::Logos::Result(self, {{ error_type }}))
        lexer = ::Logos::Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }}).new(source, extras)
        results = [] of ::Logos::Result(self, {{ error_type }})
        while token = lexer.next
          break if token.is_a?(::Iterator::Stop)
          results << token.as(::Logos::Result(self, {{ error_type }}))
        end
        results
      end

      def self.lex(__lexer : ::Logos::Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }})) : ::Logos::Result(self, {{ error_type }})?
        compiled = self.compiled
        dfa = compiled[:dfa]
        pattern_to_variant = compiled[:pattern_to_variant]
        pattern_is_skip = compiled[:pattern_is_skip]
        pattern_priority = compiled[:pattern_priority]

        # DEBUG
        if ENV["LOGOS_DEBUG"]?
          puts "DEBUG: lexer remainder = '#{__lexer.remainder.inspect}' (#{__lexer.remainder.class})"
        end

        # Find longest match
        match = dfa.find_longest_match(__lexer.remainder)
        if ENV["LOGOS_DEBUG"]?
          puts "DEBUG: find_longest_match returned: #{match.inspect}"
        end

        if match
          end_pos, pattern_ids = match

          # DEBUG
          if ENV["LOGOS_DEBUG"]?
            puts "DEBUG: matched at #{end_pos}, pattern_ids: #{pattern_ids.map(&.to_i)}"
            puts "DEBUG: matched substring: '#{__lexer.remainder[0, end_pos]}'"
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
          __lexer.bump(end_pos)

          # Call callback if any
          {% if has_callbacks %}
            case pattern_id.to_i
            {% for i in 0...all_defs.size %}
              {% item = all_defs[i] %}
              {% if item[:callback] %}
                 {% cb = item[:callback] %}
             when {{ i }}
               {% if cb.args.size == 1 %}
                 {{ cb.args[0].id }} = __lexer
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

               # Handle boolean filter callbacks (true = accept, false = skip)
               if __callback_result.is_a?(Bool)
                 if __callback_result
                   # Accept token - continue to emit variant
                   if ENV["LOGOS_DEBUG"]?
                     puts "DEBUG: Callback returned true, accepting token"
                   end
                 else
                   # Skip token
                   if ENV["LOGOS_DEBUG"]?
                     puts "DEBUG: Callback returned false, skipping token"
                   end
                   return nil
                 end
               end

               # Handle Logos::Result from callbacks
               if __callback_result.is_a?(::Logos::Result)
                 if __callback_result.ok?
                   ok_value = __callback_result.unwrap
                   if ok_value.is_a?(::Logos::Skip) ||
                      ok_value.is_a?(::Logos::Filter::Skip) ||
                      ok_value.is_a?(::Logos::FilterResult::Skip)
                     return nil
                   end
                   if ok_value.is_a?(::Logos::Filter::Emit) ||
                      ok_value.is_a?(::Logos::FilterResult::Emit)
                     __lexer.callback_value = ::Logos::CallbackValue.new(ok_value.value)
                   elsif !ok_value.nil?
                     __lexer.callback_value = ::Logos::CallbackValue.new(ok_value)
                   end
                 else
                   return ::Logos::Result(self, {{ error_type }}).error(__callback_result.unwrap_error)
                 end
               end

               # Handle Logos::Option from callbacks
               if __callback_result.is_a?(::Logos::Option)
                 option_value = __callback_result.value
                 if option_value.nil?
                   {% if error_type.id == Nil.id %}
                     error_value = nil
                   {% else %}
                     error_value = {{ error_type }}.new
                   {% end %}
                   return ::Logos::Result(self, {{ error_type }}).error(error_value)
                 else
                   __lexer.callback_value = ::Logos::CallbackValue.new(option_value)
                 end
               end

                  # Handle Filter::Emit and FilterResult::Emit - store value in lexer
                  if __callback_result.is_a?(::Logos::Filter::Emit) ||
                     __callback_result.is_a?(::Logos::FilterResult::Emit)
                    if ENV["LOGOS_DEBUG"]?
                      puts "DEBUG: Callback returned Emit with value: #{__callback_result.value.inspect}"
                    end
                    # Store emitted value in lexer for later access
                    __lexer.callback_value = ::Logos::CallbackValue.new(__callback_result.value)
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
         elsif error_variant = compiled[:error_variant]
          # No pattern matched, but we have an error variant
          # Match a single byte (or UTF-8 code point for String source)
          {% if utf8_flag %}
            if char = __lexer.remainder[0]?
              __lexer.bump(char.bytesize)
              return ::Logos::Result(self, {{ error_type }}).ok(error_variant)
            else
              # End of input
              return nil
            end
          {% else %}
            # Byte mode - consume single byte
            if __lexer.remainder.length > 0
              __lexer.bump(1)
              return ::Logos::Result(self, {{ error_type }}).ok(error_variant)
            else
              # End of input
              return nil
            end
          {% end %}
         else
            # No match and no error variant - produce lexing error
            {% if utf8_flag %}
              # String mode - consume one UTF-8 code point
              if char = __lexer.remainder[0]?
                __lexer.bump(char.bytesize)
                # Create error value based on error_type
                {% if error_callback %}
                  {% if error_callback.args.size == 1 %}
                    {{ error_callback.args[0].id }} = __lexer
                  {% end %}
                  error_value = begin
                    {{ error_callback.body }}
                  end
                {% elsif error_type.id == Nil.id %}
                  error_value = nil
                {% else %}
                  # Try to construct error value - default to .new without arguments
                  error_value = {{ error_type }}.new
                {% end %}
                return ::Logos::Result(self, {{ error_type }}).error(error_value)
              else
                # End of input
                return nil
              end
            {% else %}
              # Byte mode - consume single byte
              if __lexer.remainder.length > 0
                __lexer.bump(1)
                # Create error value based on error_type
                {% if error_callback %}
                  {% if error_callback.args.size == 1 %}
                    {{ error_callback.args[0].id }} = __lexer
                  {% end %}
                  error_value = begin
                    {{ error_callback.body }}
                  end
                {% elsif error_type.id == Nil.id %}
                  error_value = nil
                {% else %}
                  # Try to construct error value - default to .new without arguments
                  error_value = {{ error_type }}.new
                {% end %}
                return ::Logos::Result(self, {{ error_type }}).error(error_value)
              else
                # End of input
                return nil
              end
            {% end %}
         end
       end
     end
     {% end %}
  end
end
