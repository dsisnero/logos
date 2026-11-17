require "json"
require "regex-syntax"
require "regex-automata"
require "./logos"

# Build-time helper for Logos. It compiles a JSON pattern manifest into an
# ordinary Crystal matcher. The generated matcher has no regex parsing,
# determinization, or DFA deserialization at runtime.
module Logos::Codegen
  alias ManifestSubpatterns = Hash(String, String) | Hash(String, JSON::Any)

  def self.resolve_accept(ids : Array(Int32), patterns : Array(JSON::Any)) : Int32?
    return nil if ids.empty?

    candidates = ids.map { |id| ::Regex::Automata::PatternID.new(id) }
    priorities = Array.new(patterns.size, 0)
    ids.each { |id| priorities[id] = patterns[id]["resolved_priority"].as_i }
    explicit = patterns.map { |entry| priority_explicit?(entry) }
    variants = patterns.map { |entry| entry["variant"]?.try(&.as_s?) }
    resolved_winners(candidates, priorities, explicit, variants).first.to_i
  end

  private def self.resolved_winners(matches : Array(::Regex::Automata::PatternID), priorities : Array(Int32), explicit : Array(Bool), variants : Array(String?)) : Array(::Regex::Automata::PatternID)
    winners = Logos::Pattern.highest_priority_winners(matches, priorities)
    if Logos::Pattern.ambiguous_winners?(winners, explicit, variants)
      labels = winners.map { |id| variants[id.to_i] || "rule #{id.to_i}" }
      raise "Patterns #{labels.join(", ")} can match simultaneously at priority #{priorities[winners.first.to_i]}."
    end
    winners
  end

  private def self.optional_integer(entry : JSON::Any, key : String) : Int32?
    value = entry[key]?
    value.as_i if value && !value.raw.nil?
  end

  private def self.priority_explicit?(entry : JSON::Any) : Bool
    flag = entry["priority_explicit"]?.try(&.as_bool?)
    flag.nil? ? !optional_integer(entry, "priority").nil? : flag
  end

  def self.compile_dfa(patterns : Array(JSON::Any), subpatterns : ManifestSubpatterns, utf8 : Bool) : ::Regex::Automata::DFA::DFA
    build_dfa(compile_patterns(patterns, subpatterns, utf8).map(&.[0]), utf8)
  end

  private def self.compile_patterns(patterns : Array(JSON::Any), subpatterns : ManifestSubpatterns, utf8 : Bool) : Array({::Regex::Syntax::Hir::Hir, Int32})
    definitions = subpattern_definitions(subpatterns, utf8)
    expanded = Logos::Pattern.expand_subpatterns(definitions, utf8)
    patterns.map do |entry|
      kind = entry["kind"].as_s
      pattern, unicode = pattern_options(entry, utf8)
      ascii_case = entry["ignore_ascii_case"]?.try(&.as_bool) == true
      ignore_case = ascii_case || entry["ignore_case"]?.try(&.as_bool) == true
      unicode = unicode && !ascii_case
      case kind
      when "token"
        hir = Logos::Pattern.literal_hir(pattern, unicode: unicode, ignore_case: ignore_case)
        priority = pattern.bytesize * 2
      when "regex"
        hir = Logos::Pattern.regex_hir(pattern, unicode: unicode, ignore_case: ignore_case, subpatterns: expanded)
        priority = Logos::Pattern.regex_priority(hir.node)
      else
        raise "unknown Logos pattern kind: #{kind}"
      end
      Logos::Pattern.validate_utf8(hir, pattern) if utf8
      allow_greedy = entry["allow_greedy"]?.try(&.as_bool) == true
      Logos::Pattern.validate_rule(hir, pattern, allow_greedy)
      {hir, priority}
    end
  end

  private def self.subpattern_definitions(subpatterns : ManifestSubpatterns, utf8 : Bool) : Array({String, String, Bool})
    subpatterns.map do |name, value|
      case value
      when String
        {name, value, utf8}
      else
        if source = value.as_s?
          {name, source, utf8}
        else
          source, unicode = pattern_options(value, utf8)
          {name, source, unicode}
        end
      end
    end
  end

  private def self.pattern_options(entry : JSON::Any, utf8 : Bool) : {String, Bool}
    value = entry["pattern"]
    bytes = entry["bytes"]?.try(&.as_bool)
    if source = value.as_s?
      {source, bytes.nil? ? utf8 : !bytes}
    else
      octets = value.as_a.map(&.as_i.to_u8)
      {String.new(octets.to_unsafe, octets.size), bytes == false}
    end
  end

  private def self.build_dfa(hirs : Array(::Regex::Syntax::Hir::Hir), utf8 : Bool) : ::Regex::Automata::DFA::DFA
    nfa = ::Regex::Automata::HirCompiler.new(
      ::Regex::Automata::HirCompilerConfig.new(utf8: utf8)
    ).compile_multi(hirs)
    config = ::Regex::Automata::Config.new
      .match_kind(::Regex::Automata::MatchKind::All)
      .start_kind(::Regex::Automata::StartKind::Anchored)
      .prefilter(nil)
      .accelerate(false)
      .starts_for_each_pattern(false)
      .specialize_start_states(false)
    dfa = ::Regex::Automata::DFA::Builder.from_nfa(nfa, config).build.reduce_byte_classes
    Logos::Pattern.universal_start(dfa)
    dfa
  end

  private def self.static_array(values : Enumerable, suffix : String) : String
    String.build do |io|
      io << "StaticArray["
      values.each_with_index do |value, index|
        io << ", " unless index == 0
        io << value << suffix
      end
      io << "]"
    end
  end

  private def self.compile_priorities(dfa : ::Regex::Automata::DFA::DFA, patterns : Array(JSON::Any), inferred : Array(Int32))
    resolved_values = patterns.map { |entry| optional_integer(entry, "resolved_priority") }
    resolved = resolved_values.all? { |value| !value.nil? }
    priorities = if resolved
                   resolved_values.compact
                 else
                   patterns.map_with_index { |entry, index| optional_integer(entry, "priority") || inferred[index] }
                 end
    explicit = patterns.map { |entry| priority_explicit?(entry) }
    variants = patterns.map { |entry| entry["variant"]?.try(&.as_s?) }
    if !resolved && patterns.all?(&.as_h.has_key?("variant"))
      labels = patterns.map(&.["pattern"].inspect)
      Logos::Pattern.validate_priorities(dfa, priorities, explicit, labels, variants)
    end

    {priorities, explicit, variants, resolved}
  end

  private def self.binding_source(patterns : Array(JSON::Any), subpatterns : ManifestSubpatterns, utf8 : Bool) : String
    rules = patterns.map do |entry|
      source, unicode = pattern_options(entry, utf8)
      rule = {
        "kind"              => entry["kind"].as_s,
        "pattern"           => source,
        "unicode"           => unicode.to_s,
        "ignore_case"       => (entry["ignore_case"]?.try(&.as_bool) == true).to_s,
        "ignore_ascii_case" => (entry["ignore_ascii_case"]?.try(&.as_bool) == true).to_s,
        "allow_greedy"      => (entry["allow_greedy"]?.try(&.as_bool) == true).to_s,
      }
      rule["skip"] = entry["skip"].as_bool.to_s if entry.as_h.has_key?("skip")
      if variant = entry["variant"]?
        if variant.raw.nil?
          raise "A null variant requires skip: true" unless rule["skip"]? == "true"
          rule["variant"] = ""
        else
          rule["variant"] = variant.as_s
        end
      end
      rule
    end
    definitions = subpattern_definitions(subpatterns, utf8)
    "::Logos::GeneratedBinding.new(#{utf8}, #{rules.inspect} of Hash(String, String), #{definitions.inspect} of {String, String, Bool})"
  end

  # Emit a source-level matcher using compact table lookups. The DFA is built
  # and byte-class reduced by this program; the consuming application merely
  # indexes generated constants.
  def self.emit_matcher(patterns : Array(JSON::Any), subpatterns : ManifestSubpatterns, utf8 : Bool, name : String, *, validate_binding : Bool = false) : String
    compiled_patterns = compile_patterns(patterns, subpatterns, utf8)
    dfa = build_dfa(compiled_patterns.map(&.[0]), utf8)
    priorities, explicit, variants, resolved = compile_priorities(dfa, patterns, compiled_patterns.map(&.[1]))

    module_name = "Generated_#{name.gsub(/[^A-Za-z0-9_]/, "_")}"
    transition_table = dfa.tt || raise "DFA has no transition table"
    start = transition_table.to_index(Logos::Pattern.universal_start(dfa))
    class_count = dfa.byte_classes
    transitions = [] of Int32
    eoi = [] of Int32
    match_offsets = [0]
    match_ids = [] of Int32
    single_winner_table = resolved
    dfa.size.times do |state_index|
      state_id = transition_table.to_state_id(state_index)
      state = dfa[state_id]
      class_count.times do |klass|
        byte = dfa.byte_classifier.representative(klass)
        transitions << transition_table.to_index(dfa.next_state(state_id, byte))
      end
      eoi << transition_table.to_index(dfa.next_eoi_state(state_id))
      matches = resolved ? resolved_winners(state.match, priorities, explicit, variants) : state.match
      single_winner_table = false if matches.size > 1
      matches.each { |pattern_id| match_ids << pattern_id.to_i }
      match_offsets << match_ids.size
    end
    winners = if single_winner_table
                Array.new(dfa.size) do |index|
                  offset = match_offsets[index]
                  offset < match_offsets[index + 1] ? match_ids[offset] : -1
                end
              end

    String.build do |io|
      io << "module Logos::GeneratedMatchers::#{module_name}\n"
      io << "  BYTE_CLASSES = #{static_array((0...256).map { |byte| dfa.byte_classifier[byte] }, "_u8")}\n"
      io << "  TRANSITIONS = #{static_array(transitions, "_i32")}\n"
      io << "  EOI_TRANSITIONS = #{static_array(eoi, "_i32")}\n"
      io << "  MATCH_OFFSETS = #{static_array(match_offsets, "_i32")}\n"
      io << "  MATCH_IDS = #{static_array(match_ids, "_i32")}\n"
      io << "  WINNERS = #{static_array(winners, "_i32")}\n" if winners
      io << "  START_STATE = #{start}\n  BYTE_CLASS_COUNT = #{class_count}\n\n"
      io << "  def self.match(input : ::Bytes, start_index : Int32) : ::Logos::GeneratedMatch\n"
      io << "    return if start_index >= input.size\n    state = START_STATE\n    end_pos = -1\n    pattern_ids = nil.as(::Logos::GeneratedPatternIDs?)\n    pattern_id = nil.as(::Regex::Automata::PatternID?)\n    index = start_index\n"
      io << "    loop do\n      eof = index == input.size\n      next_state = eof ? EOI_TRANSITIONS[state] : TRANSITIONS[state * BYTE_CLASS_COUNT + BYTE_CLASSES[input[index]]]\n"
      if winners
        io << "      winner = WINNERS[next_state]\n      if winner >= 0\n        end_pos = index - start_index\n        pattern_id = ::Regex::Automata::PatternID.new(winner)\n      end\n"
      else
        io << "      match_start = MATCH_OFFSETS[next_state]\n      match_finish = MATCH_OFFSETS[next_state + 1]\n"
        io << "      if match_start < match_finish\n        end_pos = index - start_index\n        if match_finish == match_start + 1\n          pattern_id = ::Regex::Automata::PatternID.new(MATCH_IDS[match_start])\n        elsif match_finish == match_start + 2\n          pattern_id = nil\n          pattern_ids = StaticArray[::Regex::Automata::PatternID.new(MATCH_IDS[match_start]), ::Regex::Automata::PatternID.new(MATCH_IDS[match_start + 1])]\n        else\n          pattern_id = nil\n          ids = pattern_ids.is_a?(Array) ? pattern_ids : [] of ::Regex::Automata::PatternID\n          ids.clear\n          while match_start < match_finish\n            ids << ::Regex::Automata::PatternID.new(MATCH_IDS[match_start])\n            match_start += 1\n          end\n          pattern_ids = ids\n        end\n      end\n"
      end
      io << "      break if eof || next_state == 0 || (state != START_STATE && next_state == START_STATE)\n      state = next_state\n      index += 1\n    end\n"
      io << "    if end_pos >= 0\n      {end_pos, pattern_id || pattern_ids.not_nil!}\n    elsif index > start_index\n      ::Logos::GeneratedMiss.new(index - start_index)\n    end\n  end\nend\n"
      io << "Logos.register_generated_matcher(#{name.inspect}, ->(input : ::Bytes, start_index : Int32) { Logos::GeneratedMatchers::#{module_name}.match(input, start_index) }"
      unless winners
        io << ", #{priorities.inspect} of Int32"
        io << ", explicit_priorities: #{explicit.inspect} of Bool" if explicit.any?
        io << ", resolved_priorities: true" if resolved
      end
      io << ", binding: " << binding_source(patterns, subpatterns, utf8) if validate_binding
      io << ")"
    end
  end
end

{% unless flag?(:codegen_library) %}
  if ARGV[0]? == "--manifest"
    manifest_path = ARGV[1]? || raise "usage: logos-codegen --manifest MANIFEST [--out OUTPUT]"
    manifest = JSON.parse(File.read(manifest_path))
    patterns = manifest["patterns"].as_a
    utf8 = manifest["utf8"]?.try(&.as_bool) != false
    subpatterns = manifest["subpatterns"]?.try(&.as_h) || {} of String => JSON::Any
    name = manifest["name"].as_s
    output = Logos::Codegen.emit_matcher(patterns, subpatterns, utf8, name, validate_binding: manifest["validate_binding"]?.try(&.as_bool) == true)
    if ARGV[2]? == "--out"
      output_path = ARGV[3]? || raise("--out requires a path")
      File.write(output_path, output)
    else
      puts output
    end
  else
    patterns = Array(JSON::Any).from_json(ARGV[0])
    utf8 = ARGV[1]? != "false"
    subpatterns = JSON.parse(ARGV[2]? || "{}").as_h
    name = ARGV[3]? || raise "usage: logos-codegen PATTERNS UTF8 SUBPATTERNS TOKEN_NAME"
    puts Logos::Codegen.emit_matcher(patterns, subpatterns, utf8, name)
  end
{% end %}
