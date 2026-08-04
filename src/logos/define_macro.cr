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
        {% bytes = false %}
        {% if node.block %}
          {% callback = node.block %}
        {% end %}
        {% if node.named_args %}
          {% for named_arg in node.named_args %}
            {% if named_arg.name == "callback" && callback.nil? %}
              {% callback = named_arg.value %}
            {% elsif named_arg.name == "priority" %}
              {% priority = named_arg.value %}
            {% elsif named_arg.name == "ignore_case" || named_arg.name == "ignore_ascii_case" %}
              {% ignore_case = named_arg.value %}
            {% elsif named_arg.name == "allow_greedy" %}
              {% allow_greedy = named_arg.value %}
            {% elsif named_arg.name == "bytes" %}
              {% bytes = named_arg.value %}
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
          {% token_defs << {variant: variant, pattern: node.args[0], skip: false, callback: callback, priority: priority, ignore_case: ignore_case, allow_greedy: allow_greedy, bytes: bytes} %}
        {% elsif node.name == "regex" && node.args.size == 2 %}
          {% variant = node.args[1] %}
          {% if variant.is_a?(SymbolLiteral) %}
            {% variant = variant.id %}
          {% end %}
          {% regex_defs << {variant: variant, pattern: node.args[0], skip: false, callback: callback, priority: priority, ignore_case: ignore_case, allow_greedy: allow_greedy, bytes: bytes} %}
        {% elsif node.name == "skip_token" && node.args.size == 2 %}
          {% variant = node.args[1] %}
          {% if variant.is_a?(SymbolLiteral) %}
            {% variant = variant.id %}
          {% end %}
          {% token_defs << {variant: variant, pattern: node.args[0], skip: true, callback: callback, priority: priority, ignore_case: ignore_case, allow_greedy: allow_greedy, bytes: bytes} %}
        {% elsif node.name == "skip_regex" && node.args.size == 2 %}
          {% variant = node.args[1] %}
          {% if variant.is_a?(SymbolLiteral) %}
            {% variant = variant.id %}
          {% end %}
          {% regex_defs << {variant: variant, pattern: node.args[0], skip: true, callback: callback, priority: priority, ignore_case: ignore_case, allow_greedy: allow_greedy, bytes: bytes} %}
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
        left_nfa = ::Regex::Automata::HirCompiler.new(::Regex::Automata::HirCompilerConfig.new(utf8: {{ utf8_flag }})).compile(left_hir)
        right_nfa = ::Regex::Automata::HirCompiler.new(::Regex::Automata::HirCompilerConfig.new(utf8: {{ utf8_flag }})).compile(right_hir)
        dfa_config = ::Regex::Automata::Config.new
          .start_kind(::Regex::Automata::StartKind::Anchored)
          .prefilter(nil)
          .accelerate(false)
          .specialize_start_states(false)
        left_dfa = ::Regex::Automata::DFA::Builder.from_nfa(left_nfa, dfa_config).build
        right_dfa = ::Regex::Automata::DFA::Builder.from_nfa(right_nfa, dfa_config.dup).build

        queue = [{left_dfa.start_anchored, right_dfa.start_anchored}]
        visited = Set(Tuple(::Regex::Automata::StateID, ::Regex::Automata::StateID)).new

        until queue.empty?
          left_id, right_id = queue.shift
          pair = {left_id, right_id}
          next if visited.includes?(pair)
          visited.add(pair)

          left_accepting = left_dfa.is_match_state?(left_dfa.next_eoi_state(left_id))
          right_accepting = right_dfa.is_match_state?(right_dfa.next_eoi_state(right_id))
          return true if left_accepting && right_accepting

          left_state = left_dfa[left_id]
          right_state = right_dfa[right_id]

          256.times do |byte|
            byte_u8 = byte.to_u8
            left_next = left_state.next[left_dfa.byte_classifier[byte_u8]]
            right_next = right_state.next[right_dfa.byte_classifier[byte_u8]]
            next if left_next == ::Regex::Automata::DFA::DEAD_STATE_ID ||
                    right_next == ::Regex::Automata::DFA::DEAD_STATE_ID
            queue << {left_next, right_next}
          end
        end

        false
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

        # Use DFA-reported pattern IDs as a filter: only verify those patterns
        # with PikeVM. This is much faster than checking ALL patterns when the
        # DFA narrows down to just 1-2 candidates.
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

      # DFA compilation method
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
        if ENV["LOGOS_DEBUG"]?
          puts "DEBUG: compile_dfa called"
        end
        hirs = [] of ::Regex::Syntax::Hir::Hir
        pattern_to_variant = [] of self
        pattern_is_skip = [] of Bool
        pattern_priority = [] of Int32
        pattern_priority_explicit = [] of Bool
        pattern_dfas = [] of ::Regex::Automata::NFA::PikeVM
        pattern_prefix_dfas = [] of ::Regex::Automata::DFA::DFA
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
              raise "UTF-8 mode is enabled, but pattern #{ {{ pattern_node }}.inspect } for variant #{ {{ item[:variant] }} } is byte-oriented. Set utf8 false to allow byte-oriented matching."
            {% end %}
            unless pattern_source.valid_encoding?
              raise "UTF-8 mode is enabled, but pattern #{pattern_source.inspect} for variant #{ {{ item[:variant] }} } is not valid UTF-8. Set utf8 false to allow byte-oriented matching."
            end
            if self.hir_matches_invalid_utf8?(hir)
              raise "UTF-8 mode is enabled, but pattern #{ {{ pattern_node }}.inspect } for variant #{ {{ item[:variant] }} } can match invalid UTF-8. Set utf8 false to allow byte-oriented matching."
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
              raise "UTF-8 mode is enabled, but pattern #{ {{ pattern_node }}.inspect } for variant #{ {{ item[:variant] }} } is byte-oriented. Set utf8 false to allow byte-oriented matching."
            {% end %}
            unless pattern_source.valid_encoding?
              raise "UTF-8 mode is enabled, but pattern #{pattern_source.inspect} for variant #{ {{ item[:variant] }} } is not valid UTF-8. Set utf8 false to allow byte-oriented matching."
            end
            if self.hir_matches_invalid_utf8?(hir)
              raise "UTF-8 mode is enabled, but pattern #{ {{ pattern_node }}.inspect } for variant #{ {{ item[:variant] }} } can match invalid UTF-8. Set utf8 false to allow byte-oriented matching."
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
          dfa = ::Regex::Automata::DFA::DFA.new([dead_state], nil, ::Regex::Automata::StateID.new(0), 256)
          return {dfa: dfa, pattern_dfas: pattern_dfas, pattern_prefix_dfas: pattern_prefix_dfas, pattern_to_variant: pattern_to_variant, pattern_is_skip: pattern_is_skip, pattern_priority: pattern_priority, pattern_priority_explicit: pattern_priority_explicit, error_variant: error_variant}
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

        dfa_config = ::Regex::Automata::Config.new
          .match_kind(::Regex::Automata::MatchKind::All)
          .start_kind(::Regex::Automata::StartKind::Anchored)
          .prefilter(nil)
          .accelerate(false)
          .starts_for_each_pattern(false)
          .specialize_start_states(false)
        hir_compiler = ::Regex::Automata::HirCompiler.new(::Regex::Automata::HirCompilerConfig.new(utf8: {{ utf8_flag }}))
        nfa = hir_compiler.compile_multi(hirs)
        dfa = ::Regex::Automata::DFA::Builder.from_nfa(nfa, dfa_config).build
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

      # Lazy-loaded DFA getter
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

      # Lex method
      {% source_type = utf8_flag ? "::String".id : "::Slice(::UInt8)".id %}
      def self.lexer(source : {{ source_type }}) : ::Logos::Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }})
        ::Logos::Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }}).new(source)
      end

      def self.lexer_with_extras(source : {{ source_type }}, extras : {{ extras_type }}) : ::Logos::Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }})
        ::Logos::Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }}).new(source, extras)
      end

      # Whether a generated source matcher was registered before this lexer
      # definition. Source generation is an explicit pre-build step; macros
      # do not execute external programs during compilation.
      def self.precompiled_dfa? : Bool
        !::Logos.generated_matcher?("{{ name }}").nil?
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
        generated_matcher = ::Logos.generated_matcher?("{{ name }}")
        if generated_matcher
          pattern_to_variant = [
            {% for item in all_defs %}
              {{ item[:variant] }},
            {% end %}
          ]
          pattern_is_skip = [
            {% for item in all_defs %}
              {{ item[:skip] }},
            {% end %}
          ]
          pattern_priority = [
            {% for item in all_defs %}
              {% if item[:priority] %}
                {{ item[:priority] }},
              {% else %}
                0,
              {% end %}
            {% end %}
          ] of Int32
          pattern_priority_explicit = [
            {% for item in all_defs %}
              {{ !item[:priority].nil? }},
            {% end %}
          ]
          pattern_prefix_dfas = [] of ::Regex::Automata::DFA::DFA
          match = generated_matcher.not_nil!.call(
            {% if utf8_flag %}
              __lexer.source.to_slice,
            {% else %}
              __lexer.source,
            {% end %}
            __lexer.offset
          )
        else
          compiled = self.compiled
          dfa = compiled[:dfa]
          pattern_dfas = compiled[:pattern_dfas]
          pattern_prefix_dfas = compiled[:pattern_prefix_dfas]
          pattern_to_variant = compiled[:pattern_to_variant]
          pattern_is_skip = compiled[:pattern_is_skip]
          pattern_priority = compiled[:pattern_priority]
          pattern_priority_explicit = compiled[:pattern_priority_explicit]
          match = self.find_exact_match_at_start(dfa, pattern_dfas, __lexer.remainder)
        end

        # DEBUG
        if ENV["LOGOS_DEBUG"]?
          puts "DEBUG: lexer remainder = '#{__lexer.remainder.inspect}' (#{__lexer.remainder.class})"
        end

        # Find longest match
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
          highest_priority = pattern_ids.max_of { |id| pattern_priority[id.to_i] }
          highest_priority_ids = pattern_ids.select { |id| pattern_priority[id.to_i] == highest_priority }
          if highest_priority_ids.size > 1 &&
             highest_priority_ids.all? { |id| pattern_priority_explicit[id.to_i] }
            raise "Patterns with priority #{highest_priority} can match simultaneously."
          end
          pattern_id = if highest_priority_ids.size == 1
                         highest_priority_ids[0]
                       else
                         pattern_ids.max_by { |id| pattern_priority[id.to_i] }
                       end
          variant = pattern_to_variant[pattern_id.to_i]
          is_skip = pattern_is_skip[pattern_id.to_i]
          emitted_variant = variant

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
                   # False maps to the default error for the matched span.
                   if ENV["LOGOS_DEBUG"]?
                     puts "DEBUG: Callback returned false, returning default error"
                   end
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
                     error_value = {{ error_type }}.new
                   {% end %}
                   return ::Logos::Result(self, {{ error_type }}).error(error_value)
                 end
               end

               if __callback_result.is_a?(self)
                 emitted_variant = __callback_result
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
                     emitted_value = ok_value.value
                     if emitted_value.is_a?(self)
                       emitted_variant = emitted_value
                     else
                       __lexer.callback_value = ::Logos::CallbackValue.new(emitted_value)
                     end
                   elsif ok_value.is_a?(self)
                     emitted_variant = ok_value
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
                 elsif option_value.is_a?(self)
                   emitted_variant = option_value
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
                    emitted_value = __callback_result.value
                    if emitted_value.is_a?(self)
                      emitted_variant = emitted_value
                    else
                      # Store emitted value in lexer for later access
                      __lexer.callback_value = ::Logos::CallbackValue.new(emitted_value)
                    end
                  end
              {% end %}
            {% end %}
            end
          {% end %}

          # Return token unless it's a skip variant
          unless is_skip
            return ::Logos::Result(self, {{ error_type }}).ok(emitted_variant)
          else
            # Skip variant - return nil to continue lexing
            return nil
          end
         elsif error_variant = {% if error_def %} {{ error_def[:variant] }} {% else %} nil {% end %}
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
              # String mode - consume the invalid span up to the next token start
              if __lexer.remainder.length > 0
                __lexer.bump(self.invalid_span_length(pattern_prefix_dfas, __lexer.remainder))
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
