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
  {% extras_type = "::Logos::NoExtras".id %}
  {% error_type = Nil %}
  {% error_callback = nil %}
  {% utf8_flag = true %}

  {% for ann in type_node.annotations(::Logos::Options) %}
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
    {% value = ann.named_args["utf8"] %}
    {% utf8_flag = value unless value.nil? %}
    {% if value = ann.named_args["skip"] %}
      {% skip_value = value %}
      {% if skip_value.is_a?(ArrayLiteral) %}
        {% for entry in skip_value %}
          {% regex_defs << {variant: nil, pattern: entry, skip: true, callback: nil, priority: nil, ignore_case: false, ignore_ascii_case: false, allow_greedy: false, bytes: nil} %}
        {% end %}
      {% else %}
        {% regex_defs << {variant: nil, pattern: skip_value, skip: true, callback: nil, priority: nil, ignore_case: false, ignore_ascii_case: false, allow_greedy: false, bytes: nil} %}
      {% end %}
    {% end %}
  {% end %}

  {% for ann in type_node.annotations(::Logos::Subpattern) %}
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
    {% subpatterns << {name: name_value, pattern: pattern_node, bytes: ann.named_args["bytes"]} %}
  {% end %}

  {% for ann in type_node.annotations(::Logos::ErrorToken) %}
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

  {% for ann in type_node.annotations(::Logos::SkipToken) %}
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

  {% for ann in type_node.annotations(::Logos::Token) %}
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
    {% bytes = ann.named_args["bytes"] %}
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
    {% token_defs << {variant: variant, pattern: pattern, skip: skip, callback: callback, priority: priority, ignore_case: ignore_case, ignore_ascii_case: ignore_ascii_case, allow_greedy: allow_greedy, bytes: bytes} %}
  {% end %}

  {% for ann in type_node.annotations(::Logos::Regex) %}
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
    {% bytes = ann.named_args["bytes"] %}
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
    {% regex_defs << {variant: variant, pattern: pattern, skip: skip, callback: callback, priority: priority, ignore_case: ignore_case, ignore_ascii_case: ignore_ascii_case, allow_greedy: allow_greedy, bytes: bytes} %}
  {% end %}

  {% all_defs = token_defs + regex_defs %}
  {% has_callbacks = all_defs.any? { |item| item[:callback] } %}

  enum {{ type }}
    {% if subpatterns.size > 0 %}
      private def self.subpatterns : Array(Tuple(String, String, Bool))
        [
          {% for sub in subpatterns %}
            { {{ sub[:name] }}, {{ sub[:pattern] }}, {{ sub[:bytes].nil? ? utf8_flag : !sub[:bytes] }} },
          {% end %}
        ]
      end
    {% end %}

    private def self.prefix_matches_exactly?(vm : ::Regex::Automata::NFA::PikeVM, input : ::String, end_pos : Int32) : Bool
      return false if end_pos <= 0 || end_pos > input.bytesize

      prefix = input.byte_slice(0, end_pos)
      search = ::Regex::Automata::Input.new(prefix)
        .anchored(::Regex::Automata::Anchored::Yes)
      cache = vm.create_cache
      vm.find(cache, search).try { |match| match.start == 0 && match.end == end_pos } || false
    end

    private def self.prefix_matches_exactly?(vm : ::Regex::Automata::NFA::PikeVM, slice : ::Bytes, end_pos : Int32) : Bool
      return false if end_pos <= 0 || end_pos > slice.size

      prefix = slice[0, end_pos]
      input = ::Regex::Automata::Input.new(prefix)
        .anchored(::Regex::Automata::Anchored::Yes)
      cache = vm.create_cache
      vm.find(cache, input).try { |match| match.start == 0 && match.end == end_pos } || false
    end

    private def self.find_exact_match_at_start(dfa : ::Regex::Automata::DFA::DFA, pattern_dfas : Array(::Regex::Automata::NFA::PikeVM), input : ::String) : Tuple(Int32, Array(::Regex::Automata::PatternID))?
      match = dfa.find_longest_match_at_start(input)
      return nil unless match

      end_pos, pattern_ids = match
      return nil if end_pos <= 0

      if pattern_ids.empty?
        nil
      elsif pattern_ids.size == 1
        pid = pattern_ids.first
        vm = pattern_dfas[pid.to_i]
        if self.prefix_matches_exactly?(vm, input, end_pos)
          {end_pos, [pid]}
        end
      else
        exact_pattern_ids = [] of ::Regex::Automata::PatternID
        pattern_ids.each do |pid|
          vm = pattern_dfas[pid.to_i]
          if self.prefix_matches_exactly?(vm, input, end_pos)
            exact_pattern_ids << pid
          end
        end
        exact_pattern_ids.empty? ? nil : {end_pos, exact_pattern_ids}
      end
    end

    private def self.find_exact_match_at_start(dfa : ::Regex::Automata::DFA::DFA, pattern_dfas : Array(::Regex::Automata::NFA::PikeVM), input : ::Bytes) : Tuple(Int32, Array(::Regex::Automata::PatternID))?
      match = dfa.find_longest_match_at_start(input)
      return nil unless match

      end_pos, pattern_ids = match
      return nil if end_pos <= 0

      if pattern_ids.empty?
        nil
      elsif pattern_ids.size == 1
        pid = pattern_ids.first
        vm = pattern_dfas[pid.to_i]
        if self.prefix_matches_exactly?(vm, input, end_pos)
          {end_pos, [pid]}
        end
      else
        exact_pattern_ids = [] of ::Regex::Automata::PatternID
        pattern_ids.each do |pid|
          vm = pattern_dfas[pid.to_i]
          if self.prefix_matches_exactly?(vm, input, end_pos)
            exact_pattern_ids << pid
          end
        end
        exact_pattern_ids.empty? ? nil : {end_pos, exact_pattern_ids}
      end
    end

      @@compiled = nil.as(NamedTuple(
        dfa: ::Regex::Automata::DFA::DFA,
        pattern_dfas: Array(::Regex::Automata::NFA::PikeVM),
        pattern_prefix_dfas: Array(::Regex::Automata::DFA::DFA),
        pattern_to_variant: Array(self),
        pattern_is_skip: Array(Bool),
        pattern_priority: Array(Int32),
        pattern_priority_explicit: Array(Bool),
        error_variant: self?
      )?)

    private def self.compile_dfa : NamedTuple(
        dfa: ::Regex::Automata::DFA::DFA,
        pattern_dfas: Array(::Regex::Automata::NFA::PikeVM),
        pattern_prefix_dfas: Array(::Regex::Automata::DFA::DFA),
        pattern_to_variant: Array(self),
        pattern_is_skip: Array(Bool),
        pattern_priority: Array(Int32),
        pattern_priority_explicit: Array(Bool),
        error_variant: self?
      )
      hirs = [] of ::Regex::Syntax::Hir::Hir
      pattern_to_variant = [] of self
      pattern_is_skip = [] of Bool
      pattern_priority = [] of Int32
      pattern_priority_explicit = [] of Bool
      pattern_dfas = [] of ::Regex::Automata::NFA::PikeVM
      pattern_prefix_dfas = [] of ::Regex::Automata::DFA::DFA
      pattern_text = [] of ::String
      pattern_variant_name = [] of ::String

      {% if subpatterns.size > 0 %}
        expanded_subpatterns = ::Logos::Pattern.expand_subpatterns(self.subpatterns, {{ utf8_flag }})
      {% end %}

      skip_value = {% if skip_variant %}
                     self::{{ skip_variant }}
                   {% else %}
                     self.values.first
                   {% end %}

      {% for item, index in token_defs %}
        {% pattern_node = item[:pattern] %}
        {% unicode = !item[:ignore_ascii_case] && (item[:bytes].nil? ? utf8_flag : !item[:bytes]) %}
        {% fold_case = item[:ignore_case] || item[:ignore_ascii_case] %}
        pattern_source = {{ pattern_node }}
        hir = ::Logos::Pattern.literal_hir(pattern_source, unicode: {{ unicode }}, ignore_case: {{ fold_case }})
        {% if utf8_flag %}
          ::Logos::Pattern.validate_utf8(hir, pattern_source)
        {% end %}
        ::Logos::Pattern.validate_rule(hir, pattern_source, allow_greedy: {{ item[:allow_greedy] }}, subpattern: false)
        hirs << hir
        pattern_to_variant << {{ item[:variant] }}
        pattern_is_skip << {{ item[:skip] }}
        pattern_text << {{ pattern_node }}.inspect
        pattern_variant_name << {{ item[:variant] }}.to_s
        {% if item[:priority] %}
          pattern_priority << {{ item[:priority] }}
          pattern_priority_explicit << true
        {% else %}
          pattern_priority << pattern_source.bytesize * 2
          pattern_priority_explicit << false
        {% end %}
      {% end %}

      {% for item, index in regex_defs %}
        {% pattern_node = item[:pattern] %}
        {% unicode = !item[:ignore_ascii_case] && (item[:bytes].nil? ? utf8_flag : !item[:bytes]) %}
        {% fold_case = item[:ignore_case] || item[:ignore_ascii_case] %}
        pattern_source = {{ pattern_node }}
        hir = ::Logos::Pattern.regex_hir(pattern_source, unicode: {{ unicode }}, ignore_case: {{ fold_case }}{% if subpatterns.size > 0 %}, subpatterns: expanded_subpatterns{% end %})
        pattern_uses_subpattern = pattern_source.includes?("(?&")
        {% if utf8_flag %}
          ::Logos::Pattern.validate_utf8(hir, pattern_source)
        {% end %}
        ::Logos::Pattern.validate_rule(hir, pattern_source, allow_greedy: {{ item[:allow_greedy] }}, subpattern: pattern_uses_subpattern)
        hirs << hir
        pattern_to_variant << {% if item[:variant] %} {{ item[:variant] }} {% else %} skip_value {% end %}
        pattern_is_skip << {{ item[:skip] }}
        pattern_text << {{ pattern_node }}.inspect
        pattern_variant_name << {% if item[:variant] %} {{ item[:variant] }}.to_s {% else %} "<skip>" {% end %}
        {% if item[:priority] %}
          pattern_priority << {{ item[:priority] }}
          pattern_priority_explicit << true
        {% else %}
          pattern_priority << ::Logos::Pattern.regex_priority(hir.node)
          pattern_priority_explicit << false
        {% end %}
      {% end %}

      error_variant = {% if error_def %} {{ error_def[:variant] }} {% else %} nil {% end %}

      if hirs.empty?
        dfa = ::Regex::Automata::DFA::DFA.never_match
        return {dfa: dfa, pattern_dfas: pattern_dfas, pattern_prefix_dfas: pattern_prefix_dfas, pattern_to_variant: pattern_to_variant, pattern_is_skip: pattern_is_skip, pattern_priority: pattern_priority, pattern_priority_explicit: pattern_priority_explicit, error_variant: error_variant}
      end

      hir_compiler = ::Regex::Automata::HirCompiler.new(::Regex::Automata::HirCompilerConfig.new(utf8: {{ utf8_flag }}))
      nfa = hir_compiler.compile_multi(hirs)
      dfa_config = ::Regex::Automata::Config.new
        .match_kind(::Regex::Automata::MatchKind::All)
        .start_kind(::Regex::Automata::StartKind::Anchored)
        .prefilter(nil)
        .accelerate(false)
        .starts_for_each_pattern(false)
        .specialize_start_states(false)
      dfa = ::Regex::Automata::DFA::Builder.from_nfa(nfa, dfa_config).build
      ::Logos::Pattern.validate_priorities(dfa, pattern_priority, pattern_priority_explicit, pattern_text, pattern_variant_name)
        hirs.each do |hir|
          pattern_nfa = ::Regex::Automata::HirCompiler
            .new(::Regex::Automata::HirCompilerConfig.new(utf8: {{ utf8_flag }}))
            .build_from_hir(hir)
          pattern_dfas << ::Regex::Automata::NFA::PikeVM::Builder.new
            .configure(::Regex::Automata::NFA::PikeVM::Config.new.match_kind(::Regex::Automata::MatchKind::All))
            .build_from_nfa(pattern_nfa)
          pattern_prefix_dfas << ::Regex::Automata::DFA::Builder.from_nfa(pattern_nfa, dfa_config.dup).build
        end

      {dfa: dfa, pattern_dfas: pattern_dfas, pattern_prefix_dfas: pattern_prefix_dfas, pattern_to_variant: pattern_to_variant, pattern_is_skip: pattern_is_skip, pattern_priority: pattern_priority, pattern_priority_explicit: pattern_priority_explicit, error_variant: error_variant}
    end

    private def self.compiled : NamedTuple(
        dfa: ::Regex::Automata::DFA::DFA,
        pattern_dfas: Array(::Regex::Automata::NFA::PikeVM),
        pattern_prefix_dfas: Array(::Regex::Automata::DFA::DFA),
        pattern_to_variant: Array(self),
        pattern_is_skip: Array(Bool),
        pattern_priority: Array(Int32),
      pattern_priority_explicit: Array(Bool),
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

    private def self.default_lex_error(lexer : ::Logos::Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }})) : {{ error_type }}
      {% if error_callback %}
        {{ error_callback }}.call(lexer)
      {% elsif error_type.id == Nil.id %}
        nil
      {% else %}
        {{ error_type }}.new
      {% end %}
    end

    def self.lex(lexer : ::Logos::Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }})) : ::Logos::Result(self, {{ error_type }})?
      compiled = self.compiled
      dfa = compiled[:dfa]
      pattern_dfas = compiled[:pattern_dfas]
      pattern_prefix_dfas = compiled[:pattern_prefix_dfas]
      pattern_to_variant = compiled[:pattern_to_variant]
      pattern_is_skip = compiled[:pattern_is_skip]
      pattern_priority = compiled[:pattern_priority]
      pattern_priority_explicit = compiled[:pattern_priority_explicit]

      match = self.find_exact_match_at_start(dfa, pattern_dfas, lexer.remainder)

      if match
        end_pos, pattern_ids = match
        highest_priority = pattern_ids.max_of { |id| pattern_priority[id.to_i] }
        highest_priority_ids = pattern_ids.select { |id| pattern_priority[id.to_i] == highest_priority }
        if ::Logos::Pattern.ambiguous_winners?(highest_priority_ids, pattern_priority_explicit, pattern_to_variant)
          raise "Patterns with priority #{highest_priority} can match simultaneously."
        end
        pattern_id = highest_priority_ids.first
        variant = pattern_to_variant[pattern_id.to_i]
        is_skip = pattern_is_skip[pattern_id.to_i]
        emitted_variant = variant

        lexer.bump(end_pos)

        __payload = nil.as(::Logos::CallbackValueBase?)
        {% if has_callbacks %}
          case pattern_id.to_i
          {% for i in 0...all_defs.size %}
            {% item = all_defs[i] %}
            {% if item[:callback] %}
              {% cb = item[:callback] %}
            when {{ i }}
              {% if cb.args.size == 1 && cb.args[0].id.stringify != "lexer" %}
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
                unless __callback_result
                  return ::Logos::Result(self, {{ error_type }}).error(default_lex_error(lexer))
                end
              end

              if __callback_result.is_a?(self)
                emitted_variant = __callback_result
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
                    emitted_value = ok_value.value
                    if emitted_value.is_a?(self)
                      emitted_variant = emitted_value
                    else
                      lexer.callback_value = __payload = ::Logos::CallbackValue.new(emitted_value)
                    end
                  elsif ok_value.is_a?(self)
                    emitted_variant = ok_value
                  elsif !ok_value.nil?
                    lexer.callback_value = __payload = ::Logos::CallbackValue.new(ok_value)
                  end
                else
                  return ::Logos::Result(self, {{ error_type }}).error(__callback_result.unwrap_error)
                end
              end

              if __callback_result.is_a?(::Logos::Option)
                option_value = __callback_result.value
                if option_value.nil?
                  return ::Logos::Result(self, {{ error_type }}).error(default_lex_error(lexer))
                elsif option_value.is_a?(self)
                  emitted_variant = option_value
                else
                  lexer.callback_value = __payload = ::Logos::CallbackValue.new(option_value)
                end
              end

              if __callback_result.is_a?(::Logos::Filter::Emit) ||
                 __callback_result.is_a?(::Logos::FilterResult::Emit)
                emitted_value = __callback_result.value
                if emitted_value.is_a?(self)
                  emitted_variant = emitted_value
                else
                  lexer.callback_value = __payload = ::Logos::CallbackValue.new(emitted_value)
                end
              end
            {% end %}
          {% end %}
          end
        {% end %}

        return nil if is_skip
        return ::Logos::Result(self, {{ error_type }}).ok(emitted_variant, __payload)
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
        remainder = lexer.remainder
        return nil if remainder.length == 0

        lexer.bump(::Logos::Pattern.invalid_span_length(pattern_prefix_dfas, remainder))
        return ::Logos::Result(self, {{ error_type }}).error(default_lex_error(lexer))
      end
    end
  end
end
