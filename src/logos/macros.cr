require "regex-syntax"
require "regex-automata"
require "set"

macro logos_derive(type)
  {% type_node = type.resolve %}
  {% token_defs = [] of NamedTuple %}
  {% regex_defs = [] of NamedTuple %}
  {% subpatterns = [] of NamedTuple %}
  {% error_def = nil %}
  {% skip_variant = nil %}
  {% extras_type = ::Logos::NoExtras %}
  {% error_type = Nil %}
  {% error_callback = nil %}
  {% utf8_flag = true %}

  {% for ann in type_node.annotations(Logos::Options) %}
    {% if value = ann.named_args["extras"] %}
      {% extras_type = value %}
    {% end %}
    {% if value = ann.named_args["error_type"] %}
      {% error_type = value %}
    {% elsif value = ann.named_args["error"] %}
      {% error_type = value %}
    {% end %}
    {% if value = ann.named_args["error_callback"] %}
      {% error_callback = value %}
    {% end %}
    {% if value = ann.named_args["utf8"] %}
      {% utf8_flag = value %}
    {% end %}
    {% if value = ann.named_args["skip"] %}
      {% skip_value = value %}
      {% if skip_value.is_a?(ArrayLiteral) %}
        {% for entry in skip_value %}
          {% regex_defs << {variant: nil, pattern: entry, skip: true, callback: nil, priority: nil, ignore_case: false, allow_greedy: false} %}
        {% end %}
      {% else %}
        {% regex_defs << {variant: nil, pattern: skip_value, skip: true, callback: nil, priority: nil, ignore_case: false, allow_greedy: false} %}
      {% end %}
    {% end %}
  {% end %}

  {% for ann in type_node.annotations(Logos::Subpattern) %}
    {% if ann.args.size < 2 %}
      {% ann.raise "Subpattern annotation requires name and pattern" %}
    {% end %}
    {% name_node = ann.args[0] %}
    {% pattern_node = ann.args[1] %}
    {% unless pattern_node.is_a?(StringLiteral) %}
      {% ann.raise "Subpattern pattern must be a string literal" %}
    {% end %}
    {% name_value = name_node.stringify %}
    {% if name_value.starts_with?(":") %}
      {% name_value = name_value[1..-1] %}
    {% end %}
    {% if name_value.starts_with?("\"") && name_value.ends_with?("\"") %}
      {% name_value = name_value[1..-2] %}
    {% end %}
    {% name_value = name_value.split("\"").join("") %}
    {% name_value = name_value.split("\\").join("") %}
    {% pattern_value = pattern_node.stringify[1..-2] %}
    {% subpatterns << {name: name_value, pattern: pattern_value} %}
  {% end %}

  {% for ann in type_node.annotations(Logos::ErrorToken) %}
    {% variant = ann.named_args["variant"] %}
    {% variant = ann.args[0] if variant.nil? && ann.args.size > 0 %}
    {% if variant %}
      {% if variant.is_a?(SymbolLiteral) %}
        {% variant = variant.id %}
      {% end %}
      {% error_def = {variant: variant, callback: nil, priority: nil} %}
    {% else %}
      {% ann.raise "ErrorToken annotation requires variant" %}
    {% end %}
  {% end %}

  {% for ann in type_node.annotations(Logos::SkipToken) %}
    {% variant = ann.named_args["variant"] %}
    {% variant = ann.args[0] if variant.nil? && ann.args.size > 0 %}
    {% if variant %}
      {% if variant.is_a?(SymbolLiteral) %}
        {% variant = variant.id %}
      {% end %}
      {% skip_variant = variant %}
    {% else %}
      {% ann.raise "SkipToken annotation requires variant" %}
    {% end %}
  {% end %}

  {% for ann in type_node.annotations(Logos::Token) %}
    {% variant = ann.named_args["variant"] %}
    {% pattern = ann.named_args["pattern"] %}
    {% callback = ann.named_args["callback"] %}
    {% if variant.nil? && pattern.nil? && ann.args.size >= 2 && ann.args[0].is_a?(SymbolLiteral) %}
      {% variant = ann.args[0] %}
      {% pattern = ann.args[1] %}
      {% callback = ann.args[2] if callback.nil? && ann.args.size > 2 %}
    {% else %}
      {% pattern = ann.args[0] if pattern.nil? && ann.args.size > 0 %}
      {% callback = ann.args[1] if callback.nil? && ann.args.size > 1 %}
    {% end %}
    {% priority = nil %}
    {% ignore_case = false %}
    {% ignore_ascii_case = false %}
    {% skip = false %}
    {% allow_greedy = false %}
    {% if value = ann.named_args["priority"] %}
      {% priority = value %}
    {% end %}
    {% if value = ann.named_args["ignore_case"] %}
      {% ignore_case = value %}
    {% end %}
    {% if value = ann.named_args["ignore_ascii_case"] %}
      {% ignore_ascii_case = value %}
    {% end %}
    {% if value = ann.named_args["allow_greedy"] %}
      {% allow_greedy = value %}
    {% end %}
    {% if value = ann.named_args["ignore"] %}
      {% skip = value %}
    {% elsif value = ann.named_args["skip"] %}
      {% skip = value %}
    {% end %}
    {% if variant.nil? %}
      {% ann.raise "Token annotation requires variant" %}
    {% end %}
    {% if pattern.nil? %}
      {% ann.raise "Token annotation requires pattern" %}
    {% end %}
    {% if variant.is_a?(SymbolLiteral) %}
      {% variant = variant.id %}
    {% end %}
    {% token_defs << {variant: variant, pattern: pattern, skip: skip, callback: callback, priority: priority, ignore_case: ignore_case || ignore_ascii_case, allow_greedy: allow_greedy} %}
  {% end %}

  {% for ann in type_node.annotations(Logos::Regex) %}
    {% variant = ann.named_args["variant"] %}
    {% pattern = ann.named_args["pattern"] %}
    {% callback = ann.named_args["callback"] %}
    {% if variant.nil? && pattern.nil? && ann.args.size >= 2 && ann.args[0].is_a?(SymbolLiteral) %}
      {% variant = ann.args[0] %}
      {% pattern = ann.args[1] %}
      {% callback = ann.args[2] if callback.nil? && ann.args.size > 2 %}
    {% else %}
      {% pattern = ann.args[0] if pattern.nil? && ann.args.size > 0 %}
      {% callback = ann.args[1] if callback.nil? && ann.args.size > 1 %}
    {% end %}
    {% priority = nil %}
    {% ignore_case = false %}
    {% ignore_ascii_case = false %}
    {% skip = false %}
    {% allow_greedy = false %}
    {% if value = ann.named_args["priority"] %}
      {% priority = value %}
    {% end %}
    {% if value = ann.named_args["ignore_case"] %}
      {% ignore_case = value %}
    {% end %}
    {% if value = ann.named_args["ignore_ascii_case"] %}
      {% ignore_ascii_case = value %}
    {% end %}
    {% if value = ann.named_args["allow_greedy"] %}
      {% allow_greedy = value %}
    {% end %}
    {% if value = ann.named_args["ignore"] %}
      {% skip = value %}
    {% elsif value = ann.named_args["skip"] %}
      {% skip = value %}
    {% end %}
    {% if variant.nil? %}
      {% ann.raise "Regex annotation requires variant" %}
    {% end %}
    {% if pattern.nil? %}
      {% ann.raise "Regex annotation requires pattern" %}
    {% end %}
    {% if variant.is_a?(SymbolLiteral) %}
      {% variant = variant.id %}
    {% end %}
    {% regex_defs << {variant: variant, pattern: pattern, skip: skip, callback: callback, priority: priority, ignore_case: ignore_case || ignore_ascii_case, allow_greedy: allow_greedy} %}
  {% end %}

  {% all_defs = token_defs + regex_defs %}
  {% has_callbacks = all_defs.any? { |item| item[:callback] } %}

  enum {{ type }}
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

    private def self.compile_dfa : NamedTuple(
      dfa: ::Regex::Automata::DFA::DFA,
      pattern_to_variant: Array(self),
      pattern_is_skip: Array(Bool),
      pattern_priority: Array(Int32),
      error_variant: self?
    )
      hirs = [] of ::Regex::Syntax::Hir::Hir
      pattern_to_variant = [] of self
      pattern_is_skip = [] of Bool
      pattern_priority = [] of Int32
      pattern_priority_explicit = [] of Bool
      pattern_text = [] of ::String
      pattern_variant_name = [] of ::String

      skip_value = {% if skip_variant %}
                     self::{{ skip_variant }}
                   {% else %}
                     self.values.first
                   {% end %}

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
        {% if item[:priority] %}
          pattern_priority << {{ item[:priority] }}
          pattern_priority_explicit << true
        {% else %}
          pattern_priority << hir.complexity
          pattern_priority_explicit << false
        {% end %}
      {% end %}

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
          raise "The pattern #{ {{ pattern_node }}.inspect } for variant #{ {% if item[:variant] %} {{ item[:variant] }} {% else %} skip_value {% end %} } can match the empty string, which is unsupported by logos."
        end
        hirs << hir
        pattern_to_variant << {% if item[:variant] %} {{ item[:variant] }} {% else %} skip_value {% end %}
        pattern_is_skip << {{ item[:skip] }}
        pattern_text << {{ pattern_node }}.inspect
        pattern_variant_name << {% if item[:variant] %} {{ item[:variant] }}.to_s {% else %} "<skip>" {% end %}
        {% if item[:priority] %}
          pattern_priority << {{ item[:priority] }}
          pattern_priority_explicit << true
        {% else %}
          pattern_priority << hir.complexity
          pattern_priority_explicit << false
        {% end %}
      {% end %}

      error_variant = {% if error_def %} {{ error_def[:variant] }} {% else %} nil {% end %}

      if hirs.empty?
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

      hir_compiler = ::Regex::Automata::HirCompiler.new(utf8: {{ utf8_flag }})
      nfa = hir_compiler.compile_multi(hirs)

      dfa_builder = ::Regex::Automata::DFA::Builder.new(nfa)
      dfa = dfa_builder.build

      {dfa: dfa, pattern_to_variant: pattern_to_variant, pattern_is_skip: pattern_is_skip, pattern_priority: pattern_priority, error_variant: error_variant}
    end

    private def self.compiled : NamedTuple(
      dfa: ::Regex::Automata::DFA::DFA,
      pattern_to_variant: Array(self),
      pattern_is_skip: Array(Bool),
      pattern_priority: Array(Int32),
      error_variant: self?
    )
      @@compiled ||= compile_dfa
    end

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

    def self.lex(lexer : Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }})) : Result(self, {{ error_type }})?
      compiled = self.compiled
      dfa = compiled[:dfa]
      pattern_to_variant = compiled[:pattern_to_variant]
      pattern_is_skip = compiled[:pattern_is_skip]
      pattern_priority = compiled[:pattern_priority]

      match = dfa.find_longest_match(lexer.remainder)
      if match
        end_pos, pattern_ids = match
        pattern_id = if pattern_ids.size == 1
                       pattern_ids[0]
                     else
                       pattern_ids.max_by { |id| pattern_priority[id.to_i] }
                     end
        variant = pattern_to_variant[pattern_id.to_i]
        is_skip = pattern_is_skip[pattern_id.to_i]

        lexer.bump(end_pos)

        {% if has_callbacks %}
          case pattern_id.to_i
          {% for i in 0...all_defs.size %}
            {% item = all_defs[i] %}
            {% if item[:callback] %}
              {% cb = item[:callback] %}
            when {{ i }}
              {% if cb.args.size == 1 %}
                {{ cb.args[0].id }} = lexer
              {% end %}
              __callback_result = begin
                {{ cb.body }}
              end

              if __callback_result.is_a?(::Logos::FilterResult::Error)
                error_value = __callback_result.error
                return ::Logos::Result(self, {{ error_type }}).error(error_value)
              end

              if __callback_result.is_a?(::Logos::Skip) ||
                 __callback_result.is_a?(::Logos::Filter::Skip) ||
                 __callback_result.is_a?(::Logos::FilterResult::Skip)
                return nil
              end

              if __callback_result.is_a?(Bool)
                return nil unless __callback_result
              end

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
                    lexer.callback_value = ::Logos::CallbackValue.new(ok_value.value)
                  elsif !ok_value.nil?
                    lexer.callback_value = ::Logos::CallbackValue.new(ok_value)
                  end
                else
                  return ::Logos::Result(self, {{ error_type }}).error(__callback_result.unwrap_error)
                end
              end

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
                  lexer.callback_value = ::Logos::CallbackValue.new(option_value)
                end
              end

              if __callback_result.is_a?(::Logos::Filter::Emit) ||
                 __callback_result.is_a?(::Logos::FilterResult::Emit)
                lexer.callback_value = ::Logos::CallbackValue.new(__callback_result.value)
              end
            {% end %}
          {% end %}
          end
        {% end %}

        return nil if is_skip
        return ::Logos::Result(self, {{ error_type }}).ok(variant)
      elsif error_variant = compiled[:error_variant]
        {% if utf8_flag %}
          if char = lexer.remainder[0]?
            lexer.bump(char.bytesize)
            return ::Logos::Result(self, {{ error_type }}).ok(error_variant)
          else
            return nil
          end
        {% else %}
          if lexer.remainder.length > 0
            lexer.bump(1)
            return ::Logos::Result(self, {{ error_type }}).ok(error_variant)
          else
            return nil
          end
        {% end %}
      else
        {% if utf8_flag %}
          if char = lexer.remainder[0]?
            lexer.bump(char.bytesize)
            {% if error_callback %}
              error_value = {{ error_callback }}.call(lexer)
            {% elsif error_type.id == Nil.id %}
              error_value = nil
            {% else %}
              error_value = {{ error_type }}.new
            {% end %}
            return ::Logos::Result(self, {{ error_type }}).error(error_value)
          else
            return nil
          end
        {% else %}
          if lexer.remainder.length > 0
            lexer.bump(1)
            {% if error_callback %}
              error_value = {{ error_callback }}.call(lexer)
            {% elsif error_type.id == Nil.id %}
              error_value = nil
            {% else %}
              error_value = {{ error_type }}.new
            {% end %}
            return ::Logos::Result(self, {{ error_type }}).error(error_value)
          else
            return nil
          end
        {% end %}
      end
    end
  end
end
