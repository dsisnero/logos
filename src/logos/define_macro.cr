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
        {% ignore_ascii_case = false %}
        {% allow_greedy = false %}
        {% bytes = nil %}
        {% if node.block %}
          {% callback = node.block %}
        {% end %}
        {% if node.named_args %}
          {% for named_arg in node.named_args %}
            {% if named_arg.name == "callback" && callback.nil? %}
              {% callback = named_arg.value %}
            {% elsif named_arg.name == "priority" %}
              {% priority = named_arg.value %}
            {% elsif named_arg.name == "ignore_case" %}
              {% ignore_case = named_arg.value %}
            {% elsif named_arg.name == "ignore_ascii_case" %}
              {% ignore_ascii_case = named_arg.value %}
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
          {% subpatterns << {name: subpattern_name, pattern: pattern_node, bytes: bytes} %}
        {% elsif node.name == "token" && node.args.size == 2 %}
          {% variant = node.args[1] %}
          {% if variant.is_a?(SymbolLiteral) %}
            {% variant = variant.id %}
          {% end %}
          {% token_defs << {variant: variant, pattern: node.args[0], skip: false, callback: callback, priority: priority, ignore_case: ignore_case, ignore_ascii_case: ignore_ascii_case, allow_greedy: allow_greedy, bytes: bytes} %}
        {% elsif node.name == "regex" && node.args.size == 2 %}
          {% variant = node.args[1] %}
          {% if variant.is_a?(SymbolLiteral) %}
            {% variant = variant.id %}
          {% end %}
          {% regex_defs << {variant: variant, pattern: node.args[0], skip: false, callback: callback, priority: priority, ignore_case: ignore_case, ignore_ascii_case: ignore_ascii_case, allow_greedy: allow_greedy, bytes: bytes} %}
        {% elsif node.name == "skip_token" && node.args.size == 2 %}
          {% variant = node.args[1] %}
          {% if variant.is_a?(SymbolLiteral) %}
            {% variant = variant.id %}
          {% end %}
          {% token_defs << {variant: variant, pattern: node.args[0], skip: true, callback: callback, priority: priority, ignore_case: ignore_case, ignore_ascii_case: ignore_ascii_case, allow_greedy: allow_greedy, bytes: bytes} %}
        {% elsif node.name == "skip_regex" && node.args.size == 2 %}
          {% variant = node.args[1] %}
          {% if variant.is_a?(SymbolLiteral) %}
            {% variant = variant.id %}
          {% end %}
          {% regex_defs << {variant: variant, pattern: node.args[0], skip: true, callback: callback, priority: priority, ignore_case: ignore_case, ignore_ascii_case: ignore_ascii_case, allow_greedy: allow_greedy, bytes: bytes} %}
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

        search = ::Regex::Automata::Input.new(input).span(0...end_pos)
          .anchored(::Regex::Automata::Anchored::Yes)
        cache = vm.create_cache
        vm.find(cache, search).try { |match| match.start == 0 && match.end == end_pos } || false
      end

      private def self.prefix_matches_exactly?(vm : ::Regex::Automata::NFA::PikeVM, slice : ::Bytes, end_pos : Int32) : Bool
        return false if end_pos <= 0 || end_pos > slice.size

        input = ::Regex::Automata::Input.new(slice).span(0...end_pos)
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
      @@debug_enabled = !ENV["LOGOS_DEBUG"]?.nil?
      @@debug_priority_enabled = !ENV["LOGOS_DEBUG_PRIORITY"]?.nil?
      @@empty_pattern_prefix_dfas = [] of ::Regex::Automata::DFA::DFA

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
        if @@debug_enabled
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

        {% if subpatterns.size > 0 %}
          expanded_subpatterns = ::Logos::Pattern.expand_subpatterns(self.subpatterns, {{ utf8_flag }})
        {% end %}

        # Token patterns (literals)
        {% for item, index in token_defs %}
          {% pattern_node = item[:pattern] %}
          {% unicode = !item[:ignore_ascii_case] && (item[:bytes].nil? ? utf8_flag : !item[:bytes]) %}
          {% fold_case = item[:ignore_case] || item[:ignore_ascii_case] %}
          pattern_source = {{ pattern_node }}
          hir = ::Logos::Pattern.literal_hir(pattern_source, unicode: {{ unicode }}, ignore_case: {{ fold_case }})
          {% if utf8_flag %}
            ::Logos::Pattern.validate_utf8(hir, pattern_source)
          {% end %}
          ::Logos::Pattern.validate_rule(hir, pattern_source, allow_greedy: {{ item[:allow_greedy] }})
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
            pattern_priority << pattern_source.bytesize * 2
            pattern_priority_explicit << false
          {% end %}
        {% end %}

        # Regex patterns
        {% for item, index in regex_defs %}
          {% pattern_node = item[:pattern] %}
          {% unicode = !item[:ignore_ascii_case] && (item[:bytes].nil? ? utf8_flag : !item[:bytes]) %}
          {% fold_case = item[:ignore_case] || item[:ignore_ascii_case] %}
          pattern_source = {{ pattern_node }}
          hir = ::Logos::Pattern.regex_hir(pattern_source, unicode: {{ unicode }}, ignore_case: {{ fold_case }}{% if subpatterns.size > 0 %}, subpatterns: expanded_subpatterns{% end %})
          {% if utf8_flag %}
            ::Logos::Pattern.validate_utf8(hir, pattern_source)
          {% end %}
          ::Logos::Pattern.validate_rule(hir, pattern_source, allow_greedy: {{ item[:allow_greedy] }})
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
            pattern_priority << ::Logos::Pattern.regex_priority(hir.node)
            pattern_priority_explicit << false
          {% end %}
        {% end %}

        error_variant = {% if error_def %} {{ error_def[:variant] }} {% else %} nil {% end %}

        # DEBUG: Print priorities
        if @@debug_priority_enabled
          puts "Pattern priorities:"
          pattern_to_variant.each_with_index do |variant, i|
            puts "  Pattern #{i}: #{variant} = #{pattern_priority[i]}"
          end
        end

        # If no patterns, create a DFA that never matches
        if hirs.empty?
          dfa = ::Regex::Automata::DFA::DFA.never_match
          return {dfa: dfa, pattern_dfas: pattern_dfas, pattern_prefix_dfas: pattern_prefix_dfas, pattern_to_variant: pattern_to_variant, pattern_is_skip: pattern_is_skip, pattern_priority: pattern_priority, pattern_priority_explicit: pattern_priority_explicit, error_variant: error_variant}
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
        ::Logos::Pattern.universal_start(dfa)
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

      private def self.default_lex_error(__lexer : ::Logos::Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }})) : {{ error_type }}
        {% if error_callback %}
          {% if error_callback.args.size == 1 && error_callback.args[0].id.stringify != "__lexer" %}
            {{ error_callback.args[0].id }} = __lexer
          {% end %}
          {{ error_callback.body }}
        {% elsif error_type.id == Nil.id %}
          nil
        {% else %}
          {{ error_type }}.new
        {% end %}
      end

      @@validated_generated_binding = nil.as(::Logos::GeneratedBinding?)

      private def self.validate_generated_binding : Nil
        binding = ::Logos.generated_matcher_binding?("{{ name }}")
        return unless binding
        return if binding.same?(@@validated_generated_binding)

        rules = [
          {% for item in all_defs %}
            {
              "kind" => {{ token_defs.includes?(item) ? "token" : "regex" }},
              "pattern" => {{ item[:pattern] }},
              "unicode" => {{ (item[:bytes].nil? ? utf8_flag : !item[:bytes]).stringify }},
              "ignore_case" => {{ item[:ignore_case].stringify }},
              "ignore_ascii_case" => {{ item[:ignore_ascii_case].stringify }},
              "allow_greedy" => {{ item[:allow_greedy].stringify }},
              "skip" => {{ item[:skip].stringify }},
              "variant" => {{ item[:variant].stringify }},
            },
          {% end %}
        ] of ::Hash(::String, ::String)
        definitions = [
          {% for sub in subpatterns %}
            { {{ sub[:name] }}, {{ sub[:pattern] }}, {{ sub[:bytes].nil? ? utf8_flag : !sub[:bytes] }} },
          {% end %}
        ] of {::String, ::String, ::Bool}
        binding.validate("{{ name }}", {{ utf8_flag }}, rules, definitions)
        @@validated_generated_binding = binding
      end

      def self.lex(__lexer : ::Logos::Lexer(self, {{ source_type }}, {{ extras_type }}, {{ error_type }})) : ::Logos::Result(self, {{ error_type }})?
        generated_matcher = ::Logos.generated_matcher?("{{ name }}")
        generated_prefix = nil
        if generated_matcher
          validate_generated_binding
          pattern_prefix_dfas = @@empty_pattern_prefix_dfas
          generated_result = generated_matcher.call(
            {% if utf8_flag %}
              __lexer.source_bytes,
            {% else %}
              __lexer.source,
            {% end %}
            __lexer.offset
          )
          if generated_result.is_a?(::Logos::GeneratedMiss)
            generated_prefix = generated_result.prefix_length
            match = nil
          else
            match = generated_result
          end
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
        if @@debug_enabled
          puts "DEBUG: lexer remainder = '#{__lexer.remainder.inspect}' (#{__lexer.remainder.class})"
        end

        # Find longest match
        if @@debug_enabled
          puts "DEBUG: find_longest_match returned: #{match.inspect}"
        end

        if match
          end_pos, pattern_ids = match
          # DEBUG
          if @@debug_enabled
            puts "DEBUG: matched at #{end_pos}, pattern_ids: #{pattern_ids.inspect}"
            puts "DEBUG: matched substring: '#{__lexer.remainder[0, end_pos]}'"
            if pattern_ids.is_a?(Array) && pattern_ids.empty?
              puts "DEBUG: WARNING: pattern_ids empty but match state accepting"
            end
          end

          if generated_matcher && pattern_ids.is_a?(::Regex::Automata::PatternID)
            # The external generator returns one accepted pattern for the
            # common case. Emit the action mapping directly: unlike the
            # runtime-DFA path, no metadata arrays or priority scan are needed.
            pattern_id = pattern_ids
            case pattern_id.to_i
            {% for i in 0...all_defs.size %}
              {% item = all_defs[i] %}
            when {{ i }}
              variant = {{ item[:variant] }}
              is_skip = {{ item[:skip] }}
            {% end %}
            else
              raise "generated matcher returned an unknown pattern ID"
            end
          else
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
              priority_info = ::Logos.generated_matcher_priority_info?("{{ name }}")
              manifest_explicit = priority_info.try(&.explicit)
              if priority_info && priority_info.resolved
                pattern_priority = priority_info.values
                pattern_priority_explicit = manifest_explicit || Array.new({{ all_defs.size }}, false)
              else
                default_priorities = priority_info.try(&.values)
                pattern_priority = [
                  {% for item, index in all_defs %}
                    {% if item[:priority] %}
                      {{ item[:priority] }},
                    {% else %}
                      default_priorities.try(&.[{{ index }}]?) || 0,
                    {% end %}
                  {% end %}
                ] of Int32
                pattern_priority_explicit = [
                  {% for item, index in all_defs %}
                    {% if item[:priority].nil? %}
                      manifest_explicit.try(&.[{{ index }}]?) || false,
                    {% else %}
                      true,
                    {% end %}
                  {% end %}
                ]
              end
            end
            # Allocate a list of tied rules only when there is more than one winner.
            pattern_id = if pattern_ids.is_a?(::Regex::Automata::PatternID)
                           pattern_ids
                         else
                           priorities = pattern_priority.not_nil!
                           highest_priority = priorities[pattern_ids[0].to_i]
                           selected = pattern_ids[0]
                           highest_priority_count = 1
                           index = 1
                           while index < pattern_ids.size
                             candidate = pattern_ids[index]
                             candidate_priority = priorities[candidate.to_i]
                             if candidate_priority > highest_priority
                               selected = candidate
                               highest_priority = candidate_priority
                               highest_priority_count = 1
                             elsif candidate_priority == highest_priority
                               highest_priority_count += 1
                             end
                             index += 1
                           end
                           if highest_priority_count > 1
                             winners = pattern_ids.select { |id| priorities[id.to_i] == highest_priority }
                             if ::Logos::Pattern.ambiguous_winners?(winners, pattern_priority_explicit.not_nil!, pattern_to_variant.not_nil!)
                               raise "Patterns with priority #{highest_priority} can match simultaneously."
                             end
                           end
                           selected
                         end
            variant = pattern_to_variant.not_nil![pattern_id.to_i]
            is_skip = pattern_is_skip.not_nil![pattern_id.to_i]
          end
          emitted_variant = variant

          # Advance lexer by matched length
          __lexer.bump(end_pos)

          # Call callback if any
          __payload = nil.as(::Logos::CallbackValueBase?)
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
              if @@debug_enabled
                puts "DEBUG: Callback result: #{__callback_result.inspect}, type: #{__callback_result.class}"
              end

              # Handle FilterResult::Error
              if __callback_result.is_a?(::Logos::FilterResult::Error)
                error_value = __callback_result.error
                if @@debug_enabled
                  puts "DEBUG: Callback returned FilterResult::Error, returning error: #{error_value.inspect}"
                end
                return ::Logos::Result(self, {{ error_type }}).error(error_value)
              end

               # Handle Skip types
               if __callback_result.is_a?(::Logos::Skip) ||
                  __callback_result.is_a?(::Logos::Filter::Skip) ||
                  __callback_result.is_a?(::Logos::FilterResult::Skip)
                 if @@debug_enabled
                   puts "DEBUG: Callback returned Skip, skipping token"
                 end
                 return nil
               end

               # Handle boolean filter callbacks (true = accept, false = skip)
               if __callback_result.is_a?(Bool)
                 if __callback_result
                   # Accept token - continue to emit variant
                   if @@debug_enabled
                     puts "DEBUG: Callback returned true, accepting token"
                   end
                 else
                   # False maps to the default error for the matched span.
                   if @@debug_enabled
                     puts "DEBUG: Callback returned false, returning default error"
                   end
                   return ::Logos::Result(self, {{ error_type }}).error(default_lex_error(__lexer))
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
                       __lexer.callback_value = __payload = ::Logos::CallbackValue.new(emitted_value)
                     end
                   elsif ok_value.is_a?(self)
                     emitted_variant = ok_value
                   elsif !ok_value.nil?
                     __lexer.callback_value = __payload = ::Logos::CallbackValue.new(ok_value)
                   end
                 else
                   return ::Logos::Result(self, {{ error_type }}).error(__callback_result.unwrap_error)
                 end
               end

               # Handle Logos::Option from callbacks
               if __callback_result.is_a?(::Logos::Option)
                 option_value = __callback_result.value
                 if option_value.nil?
                   return ::Logos::Result(self, {{ error_type }}).error(default_lex_error(__lexer))
                 elsif option_value.is_a?(self)
                   emitted_variant = option_value
                 else
                   __lexer.callback_value = __payload = ::Logos::CallbackValue.new(option_value)
                 end
               end

                  # Handle Filter::Emit and FilterResult::Emit - store value in lexer
                  if __callback_result.is_a?(::Logos::Filter::Emit) ||
                     __callback_result.is_a?(::Logos::FilterResult::Emit)
                    if @@debug_enabled
                      puts "DEBUG: Callback returned Emit with value: #{__callback_result.value.inspect}"
                    end
                    emitted_value = __callback_result.value
                    if emitted_value.is_a?(self)
                      emitted_variant = emitted_value
                    else
                      # Store emitted value in lexer for later access
                      __lexer.callback_value = __payload = ::Logos::CallbackValue.new(emitted_value)
                    end
                  end
              {% end %}
            {% end %}
            end
          {% end %}

          # Return token unless it's a skip variant
          unless is_skip
            return ::Logos::Result(self, {{ error_type }}).ok(emitted_variant, __payload)
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
            remainder = __lexer.remainder
            return nil if remainder.length == 0

            length = if generated_prefix
                       remainder.find_boundary(Math.max(generated_prefix, 1))
                     else
                       ::Logos::Pattern.invalid_span_length(pattern_prefix_dfas, remainder)
                     end
            __lexer.bump(length)
            return ::Logos::Result(self, {{ error_type }}).error(default_lex_error(__lexer))
         end
       end
     end
     {% end %}
  end
end
