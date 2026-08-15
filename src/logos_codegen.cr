require "json"
require "regex-syntax"
require "regex-automata"
require "./logos"

# Build-time helper for Logos. It compiles a JSON pattern manifest into an
# ordinary Crystal matcher. The generated matcher has no regex parsing,
# determinization, or DFA deserialization at runtime.
module Logos::Codegen
  def self.compile_dfa(patterns : Array(JSON::Any), subpatterns : Hash(String, String), utf8 : Bool) : ::Regex::Automata::DFA::DFA
    hirs = patterns.map do |entry|
      kind = entry["kind"].as_s
      pattern = entry["pattern"].as_s
      subpatterns.each { |name, value| pattern = pattern.gsub("(?&#{name})", value) }
      case kind
      when "token"
        ::Regex::Syntax::Hir::Hir.literal(pattern.to_slice)
      when "regex"
        ::Regex::Syntax.parse(pattern, unicode: utf8, utf8: utf8)
      else
        raise "unknown Logos pattern kind: #{kind}"
      end
    end
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
    ::Regex::Automata::DFA::Builder.from_nfa(nfa, config).build.reduce_byte_classes
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

  # Emit a source-level matcher using compact table lookups. The DFA is built
  # and byte-class reduced by this program; the consuming application merely
  # indexes generated constants.
  def self.emit_matcher(patterns : Array(JSON::Any), subpatterns : Hash(String, String), utf8 : Bool, name : String) : String
    dfa = compile_dfa(patterns, subpatterns, utf8)
    module_name = "Generated_#{name.gsub(/[^A-Za-z0-9_]/, "_")}"
    transition_table = dfa.tt || raise "DFA has no transition table"
    start = transition_table.to_index(dfa.start_anchored)
    class_count = dfa.byte_classes
    transitions = [] of Int32
    eoi = [] of Int32
    match_offsets = [0]
    match_ids = [] of Int32
    dfa.size.times do |state_index|
      state_id = transition_table.to_state_id(state_index)
      state = dfa[state_id]
      class_count.times do |klass|
        byte = dfa.byte_classifier.representative(klass)
        transitions << transition_table.to_index(dfa.next_state(state_id, byte))
      end
      eoi << transition_table.to_index(dfa.next_eoi_state(state_id))
      state.match.each { |pattern_id| match_ids << pattern_id.to_i }
      match_offsets << match_ids.size
    end

    String.build do |io|
      io << "module Logos::GeneratedMatchers::#{module_name}\n"
      io << "  BYTE_CLASSES = #{static_array((0...256).map { |byte| dfa.byte_classifier[byte] }, "_u8")}\n"
      io << "  TRANSITIONS = #{static_array(transitions, "_i32")}\n"
      io << "  EOI_TRANSITIONS = #{static_array(eoi, "_i32")}\n"
      io << "  MATCH_OFFSETS = #{static_array(match_offsets, "_i32")}\n"
      io << "  MATCH_IDS = #{static_array(match_ids, "_i32")}\n"
      io << "  START_STATE = #{start}\n  BYTE_CLASS_COUNT = #{class_count}\n\n"
      io << "  def self.match(input : ::Bytes, start_index : Int32) : ::Logos::GeneratedMatch\n"
      io << "    state = START_STATE\n    end_pos = -1\n    pattern_ids = nil.as(Array(::Regex::Automata::PatternID)?)\n    pattern_id = nil.as(::Regex::Automata::PatternID?)\n    index = start_index\n"
      io << "    while index < input.size\n      next_state = TRANSITIONS[state * BYTE_CLASS_COUNT + BYTE_CLASSES[input[index]]]\n"
      io << "      break if next_state == 0 || (state != START_STATE && next_state == START_STATE)\n      state = next_state\n"
      io << "      eoi_state = EOI_TRANSITIONS[state]\n      match_start = MATCH_OFFSETS[eoi_state]\n      match_finish = MATCH_OFFSETS[eoi_state + 1]\n"
      io << "      if match_start < match_finish\n        end_pos = index - start_index + 1\n        if match_finish == match_start + 1\n          pattern_id = ::Regex::Automata::PatternID.new(MATCH_IDS[match_start])\n        else\n          pattern_id = nil\n          ids = pattern_ids ||= [] of ::Regex::Automata::PatternID\n          ids.clear\n          while match_start < match_finish\n            ids << ::Regex::Automata::PatternID.new(MATCH_IDS[match_start])\n            match_start += 1\n          end\n        end\n      end\n      index += 1\n    end\n"
      io << "    end_pos < 0 ? nil : {end_pos, pattern_id || pattern_ids.not_nil!}\n  end\nend\n"
      io << "Logos.register_generated_matcher(#{name.inspect}, ->(input : ::Bytes, start_index : Int32) { Logos::GeneratedMatchers::#{module_name}.match(input, start_index) })"
    end
  end
end

if ARGV[0]? == "--manifest"
  manifest_path = ARGV[1]? || raise "usage: logos-codegen --manifest MANIFEST [--out OUTPUT]"
  manifest = JSON.parse(File.read(manifest_path))
  patterns = manifest["patterns"].as_a
  utf8 = manifest["utf8"]?.try(&.as_bool) || true
  subpatterns = manifest["subpatterns"]?.try { |value| Hash(String, String).from_json(value.to_json) } || {} of String => String
  name = manifest["name"].as_s
  output = Logos::Codegen.emit_matcher(patterns, subpatterns, utf8, name)
  if ARGV[2]? == "--out"
    output_path = ARGV[3]? || raise("--out requires a path")
    File.write(output_path, output)
  else
    puts output
  end
else
  patterns = Array(JSON::Any).from_json(ARGV[0])
  utf8 = ARGV[1]? != "false"
  subpatterns = Hash(String, String).from_json(ARGV[2]? || "{}")
  name = ARGV[3]? || raise "usage: logos-codegen PATTERNS UTF8 SUBPATTERNS TOKEN_NAME"
  puts Logos::Codegen.emit_matcher(patterns, subpatterns, utf8, name)
end
