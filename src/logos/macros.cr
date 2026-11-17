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
          {% regex_defs << {variant: nil, pattern: entry, skip: true, callback: nil, priority: nil, ignore_case: false, allow_greedy: false, bytes: false} %}
        {% end %}
      {% else %}
        {% regex_defs << {variant: nil, pattern: skip_value, skip: true, callback: nil, priority: nil, ignore_case: false, allow_greedy: false, bytes: false} %}
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
    {% bytes = false %}
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
    {% if value = ann.named_args["bytes"] %}
      {% bytes = value %}
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
    {% token_defs << {variant: variant, pattern: pattern, skip: skip, callback: callback, priority: priority, ignore_case: ignore_case || ignore_ascii_case, allow_greedy: allow_greedy, bytes: bytes} %}
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
    {% bytes = false %}
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
    {% if value = ann.named_args["bytes"] %}
      {% bytes = value %}
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
    {% regex_defs << {variant: variant, pattern: pattern, skip: skip, callback: callback, priority: priority, ignore_case: ignore_case || ignore_ascii_case, allow_greedy: allow_greedy, bytes: bytes} %}
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

    private def self.hir_matches_invalid_utf8?(hir : ::Regex::Syntax::Hir::Hir) : Bool
      node_matches_invalid_utf8?(hir.node)
    end

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

    private def self.invalid_span_length(pattern_prefix_dfas : Array(::Regex::Automata::DFA::DFA), input : ::String) : Int32
      return input.find_boundary(1) if pattern_prefix_dfas.empty?

      bytes = input.to_slice
      start_states = pattern_prefix_dfas.map(&.start_anchored)
      alive_states = start_states.dup
      last_alive_boundary = 0
      offset = 0
      first_char_size = 0

      input.each_char do |char|
        char_bytes = char.bytesize
        first_char_size = char_bytes if first_char_size == 0

        char_bytes.times do |index|
          byte = bytes[offset + index]
          any_alive = false

          pattern_prefix_dfas.each_with_index do |pattern_dfa, pattern_index|
            state_id = alive_states[pattern_index]
            next if pattern_dfa.is_dead_state?(state_id)

            next_state = pattern_dfa.next_state(state_id, byte)
            if pattern_dfa.is_dead_state?(next_state) || pattern_dfa.is_start_state?(next_state)
              alive_states[pattern_index] = ::Regex::Automata::DFA::DEAD_STATE_ID
              next
            end

            alive_states[pattern_index] = next_state
            any_alive = true
          end

          return last_alive_boundary > 0 ? last_alive_boundary : first_char_size unless any_alive
        end

        offset += char_bytes
        last_alive_boundary = offset
      end

      last_alive_boundary
    end

    private def self.invalid_span_length(pattern_prefix_dfas : Array(::Regex::Automata::DFA::DFA), input : ::Bytes) : Int32
      return 1 if pattern_prefix_dfas.empty?

      start_states = pattern_prefix_dfas.map(&.start_anchored)
      alive_states = start_states.dup
      last_alive_offset = 0

      input.each_with_index do |byte, index|
        any_alive = false

        pattern_prefix_dfas.each_with_index do |pattern_dfa, pattern_index|
          state_id = alive_states[pattern_index]
          next if pattern_dfa.is_dead_state?(state_id)

          next_state = pattern_dfa.next_state(state_id, byte)
          if pattern_dfa.is_dead_state?(next_state) || pattern_dfa.is_start_state?(next_state)
            alive_states[pattern_index] = ::Regex::Automata::DFA::DEAD_STATE_ID
            next
          end

          alive_states[pattern_index] = next_state
          any_alive = true
        end

        return last_alive_offset > 0 ? last_alive_offset : 1 unless any_alive
        last_alive_offset = index + 1
      end

      last_alive_offset
    end

    private def self.node_matches_invalid_utf8?(node : ::Regex::Syntax::Hir::Node) : Bool
      case node
      when ::Regex::Syntax::Hir::Literal
        !::String.new(node.bytes).valid_encoding?
      when ::Regex::Syntax::Hir::CharClass
        node.intervals.any? { |range| range.end >= 0x80_u8 }
      when ::Regex::Syntax::Hir::DotNode
        case node.kind
        when ::Regex::Syntax::Hir::Dot::AnyByte,
             ::Regex::Syntax::Hir::Dot::AnyByteExceptLF,
             ::Regex::Syntax::Hir::Dot::AnyByteExceptCRLF
          true
        else
          false
        end
      when ::Regex::Syntax::Hir::Concat
        node.children.any? { |child| node_matches_invalid_utf8?(child) }
      when ::Regex::Syntax::Hir::Alternation
        node.children.any? { |child| node_matches_invalid_utf8?(child) }
      when ::Regex::Syntax::Hir::Repetition
        node_matches_invalid_utf8?(node.sub)
      when ::Regex::Syntax::Hir::Capture
        node_matches_invalid_utf8?(node.sub)
      else
        false
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
          pattern_source = {{ pattern_node }}
          pattern_uses_subpattern = false
          hir = ::Regex::Syntax::Hir::Hir.literal(pattern_source.to_slice)
        {% end %}
        {% if item[:ignore_case] %}
          {% if utf8_flag %}
            hir = ::Regex::Syntax::Hir.case_fold_unicode(hir)
          {% else %}
            hir = ::Regex::Syntax::Hir.case_fold_ascii(hir)
          {% end %}
        {% end %}
        {% if utf8_flag %}
          {% if item[:bytes] %}
            raise "UTF-8 mode is enabled, but pattern #{ {{ pattern_node }}.inspect } for variant #{ {{ item[:variant] }} } is byte-oriented. Set utf8: false to allow byte-oriented matching."
          {% end %}
          unless pattern_source.valid_encoding?
            raise "UTF-8 mode is enabled, but pattern #{pattern_source.inspect} for variant #{ {{ item[:variant] }} } is not valid UTF-8. Set utf8: false to allow byte-oriented matching."
          end
          if self.hir_matches_invalid_utf8?(hir)
            raise "UTF-8 mode is enabled, but pattern #{ {{ pattern_node }}.inspect } for variant #{ {{ item[:variant] }} } can match invalid UTF-8. Set utf8: false to allow byte-oriented matching."
          end
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
          pattern_priority << pattern_source.bytesize * 2
          pattern_priority_explicit << false
        {% end %}
      {% end %}

      {% for item, index in regex_defs %}
        {% pattern_node = item[:pattern] %}
        {% if subpatterns.size > 0 %}
          pattern_source = self.substitute_subpatterns({{ pattern_node }})
          pattern_uses_subpattern = {{ pattern_node }}.includes?("(?&")
          hir = ::Regex::Syntax.parse(pattern_source, unicode: {{ utf8_flag }}, utf8: {{ utf8_flag }})
        {% else %}
          pattern_source = {{ pattern_node }}
          pattern_uses_subpattern = false
          hir = ::Regex::Syntax.parse(pattern_source, unicode: {{ utf8_flag }}, utf8: {{ utf8_flag }})
        {% end %}
        {% if item[:ignore_case] %}
          {% if utf8_flag %}
            hir = ::Regex::Syntax::Hir.case_fold_unicode(hir)
          {% else %}
            hir = ::Regex::Syntax::Hir.case_fold_ascii(hir)
          {% end %}
        {% end %}
        {% if utf8_flag %}
          {% if item[:bytes] %}
            raise "UTF-8 mode is enabled, but pattern #{ {{ pattern_node }}.inspect } for variant #{ {% if item[:variant] %} {{ item[:variant] }} {% else %} skip_value {% end %} } is byte-oriented. Set utf8: false to allow byte-oriented matching."
          {% end %}
          unless pattern_source.valid_encoding?
            raise "UTF-8 mode is enabled, but pattern #{pattern_source.inspect} for variant #{ {% if item[:variant] %} {{ item[:variant] }} {% else %} skip_value {% end %} } is not valid UTF-8. Set utf8: false to allow byte-oriented matching."
          end
          if self.hir_matches_invalid_utf8?(hir)
            raise "UTF-8 mode is enabled, but pattern #{ {{ pattern_node }}.inspect } for variant #{ {% if item[:variant] %} {{ item[:variant] }} {% else %} skip_value {% end %} } can match invalid UTF-8. Set utf8: false to allow byte-oriented matching."
          end
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
          pattern_priority << ::Logos::Pattern.regex_priority(hir.node)
          pattern_priority_explicit << false
        {% end %}
      {% end %}

      error_variant = {% if error_def %} {{ error_def[:variant] }} {% else %} nil {% end %}

      if hirs.empty?
        dead_state = ::Regex::Automata::DFA::State.new(::Regex::Automata::StateID.new(0), 256)
        256.times { |i| dead_state.set_transition(i, ::Regex::Automata::StateID.new(-1)) }
        dfa = ::Regex::Automata::DFA::DFA.new([dead_state], nil, ::Regex::Automata::StateID.new(0), 256)
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

    def self.lex(lexer : Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }})) : Result(self, {{ error_type }})?
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
        {% if utf8_flag %}
          if lexer.remainder.length > 0
            lexer.bump(self.invalid_span_length(pattern_prefix_dfas, lexer.remainder))
            return ::Logos::Result(self, {{ error_type }}).error(default_lex_error(lexer))
          else
            return nil
          end
        {% else %}
          if lexer.remainder.length > 0
            lexer.bump(1)
            return ::Logos::Result(self, {{ error_type }}).error(default_lex_error(lexer))
          else
            return nil
          end
        {% end %}
      end
    end
  end
end
