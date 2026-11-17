require "../spec_helper"
{% if flag?(:codegen_library) %}
  require "../../src/logos_codegen"
  require "file_utils"

  describe Logos::Codegen do
    it "resolves the highest priority independently of pattern order" do
      patterns = JSON.parse(%([{"resolved_priority":1},{"resolved_priority":3}])).as_a
      Logos::Codegen.resolve_accept([0, 1], patterns).should eq(1)
      Logos::Codegen.resolve_accept([1, 0], patterns).should eq(1)
      Logos::Codegen.resolve_accept([] of Int32, patterns).should be_nil
    end

    it "emits inferred literal and regexp priorities for generic matchers" do
      patterns = JSON.parse(%([{"kind":"token","pattern":"é"},{"kind":"regex","pattern":"é"}])).as_a
      source = Logos::Codegen.emit_matcher(patterns, {} of String => String, true, "UnicodePriority")
      source.should end_with(", [4, 2] of Int32)")
    end

    it "groups subpattern alternatives while compiling the manifest" do
      patterns = JSON.parse(%([{"kind":"regex","pattern":"~(?&part)+"},{"kind":"token","pattern":"(?&part)"}])).as_a
      dfa = Logos::Codegen.compile_dfa(patterns, {"part" => "a|b"}, true)

      dfa.find_longest_match_at_start("~abba").should eq({5, [Regex::Automata::PatternID.new(0)]})
      dfa.find_longest_match_at_start("bbb").should be_nil
      dfa.find_longest_match_at_start("(?&part)").should eq({8, [Regex::Automata::PatternID.new(1)]})
    end

    it "compiles per-pattern Unicode, byte, and case options in binary manifests" do
      patterns = JSON.parse(<<-JSON).as_a
        [
          {"kind":"regex","pattern":"~(?&digit)(?&raw)"},
          {"kind":"regex","pattern":"(?-i:k)é","bytes":false,"ignore_case":true},
          {"kind":"token","pattern":[255, 97],"ignore_case":true}
        ]
        JSON
      subpatterns = JSON.parse(%({"digit":{"pattern":"\\\\d","bytes":false},"raw":{"pattern":".","bytes":true}})).as_h
      dfa = Logos::Codegen.compile_dfa(patterns, subpatterns, false)

      dfa.find_longest_match_at_start(String.new(Bytes[0x7E, 0xD9, 0xA1, 0xFF])).should eq({4, [Regex::Automata::PatternID.new(0)]})
      dfa.find_longest_match_at_start("kÉ").should eq({3, [Regex::Automata::PatternID.new(1)]})
      dfa.find_longest_match_at_start("Ké").should be_nil
      dfa.find_longest_match_at_start(String.new(Bytes[0xFF, 0x41])).should eq({2, [Regex::Automata::PatternID.new(2)]})
    end

    it "preserves failed prefixes in emitted text and byte matchers" do
      text = JSON.parse(%([{"kind":"token","pattern":"!"},{"kind":"token","pattern":"aéx"},{"kind":"token","pattern":"abc"}])).as_a
      bytes = JSON.parse(%([{"kind":"token","pattern":"!","resolved_priority":2},{"kind":"token","pattern":"abc","resolved_priority":6}])).as_a
      root = File.expand_path("../..", __DIR__)
      directory = File.join(root, "temp")
      FileUtils.mkdir_p(directory)
      file = File.tempfile("matcher-prefix", ".cr", dir: directory)
      begin
        File.open(file.path, "w") do |io|
          io.puts %q(require "../src/logos")
          io.puts Logos::Codegen.emit_matcher(text, {} of String => String, true, "TextPrefixToken")
          io.puts Logos::Codegen.emit_matcher(bytes, {} of String => String, false, "BytePrefixToken")
          io << File.read(File.join(root, "spec/fixtures/generated_error_prefix.cr"))
        end
        error = IO::Memory.new
        status = Process.run("crystal", ["run", file.path], chdir: root, error: error)
        raise error.to_s unless status.success?
      ensure
        file.delete
      end
    end

    it "rejects greedy dot and empty subpattern rules unless allowed by the runtime contract" do
      subpatterns = {"optional" => "a?"}
      greedy = JSON.parse(%([{"kind":"regex","pattern":".+"}])).as_a
      allowed = JSON.parse(%([{"kind":"regex","pattern":".+","allow_greedy":true}])).as_a
      empty = JSON.parse(%([{"kind":"regex","pattern":"(?&optional)"}])).as_a

      expect_raises(Exception, /unbounded greedy dot/) { Logos::Codegen.emit_matcher(greedy, subpatterns, true, "Greedy") }
      expect_raises(Exception, /can match the empty string/) { Logos::Codegen.emit_matcher(empty, subpatterns, true, "Empty") }
      Logos::Codegen.emit_matcher(allowed, subpatterns, true, "Allowed").should contain("Generated_Allowed")
    end

    it "preserves first-match ties and rejects explicit ambiguity" do
      patterns = JSON.parse(%([{"resolved_priority":3},{"resolved_priority":3}])).as_a
      Logos::Codegen.resolve_accept([1, 0], patterns).should eq(1)
      patterns = JSON.parse(%([{"resolved_priority":3,"priority_explicit":true},{"resolved_priority":3,"priority_explicit":true}])).as_a
      expect_raises(Exception, /can match simultaneously/) { Logos::Codegen.resolve_accept([0, 1], patterns) }
    end
  end
{% end %}
