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

    it "preserves matching boundaries and priorities in emitted matchers" do
      text = JSON.parse(%([{"kind":"token","pattern":"!"},{"kind":"token","pattern":"aéx"},{"kind":"token","pattern":"abc"}])).as_a
      bytes = JSON.parse(%([{"kind":"token","pattern":"!","resolved_priority":2},{"kind":"token","pattern":"abc","resolved_priority":6}])).as_a
      text_end = JSON.parse(%([{"kind":"token","pattern":"b"},{"kind":"regex","pattern":"a$"}])).as_a
      line_end = JSON.parse(%([{"kind":"token","pattern":"\\n","resolved_priority":2},{"kind":"regex","pattern":"(?m)a$","resolved_priority":2}])).as_a
      legacy = JSON.parse(%([{"kind":"regex","pattern":"a","resolved_priority":0},{"kind":"regex","pattern":"[a]","resolved_priority":0}])).as_a
      generic = JSON.parse(%([{"kind":"regex","pattern":".","variant":"Ignored","priority":1},{"kind":"regex","pattern":"a","variant":"A","priority":4}])).as_a
      shadowed = JSON.parse(%([{"kind":"regex","pattern":"a","variant":"Low","resolved_priority":2},{"kind":"regex","pattern":"[a]","variant":"Low","resolved_priority":2},{"kind":"regex","pattern":"[a-a]","variant":"High","resolved_priority":4}])).as_a
      deferred = JSON.parse(%([{"kind":"regex","pattern":"a","priority":2},{"kind":"regex","pattern":"[a]","priority":2}])).as_a
      root = File.expand_path("../..", __DIR__)
      directory = File.join(root, "temp")
      FileUtils.mkdir_p(directory)
      file = File.tempfile("matcher-prefix", ".cr", dir: directory)
      begin
        File.open(file.path, "w") do |io|
          io.puts %q(require "../src/logos")
          io.puts Logos::Codegen.emit_matcher(text, {} of String => String, true, "TextPrefixToken")
          io.puts Logos::Codegen.emit_matcher(bytes, {} of String => String, false, "BytePrefixToken")
          io.puts Logos::Codegen.emit_matcher(text_end, {} of String => String, true, "GeneratedTextEndToken")
          io.puts Logos::Codegen.emit_matcher(line_end, {} of String => String, true, "GeneratedLineEndToken")
          io.puts Logos::Codegen.emit_matcher(legacy, {} of String => String, true, "LegacyResolvedDuplicateToken")
          io.puts Logos::Codegen.emit_matcher(legacy, {} of String => String, true, "LegacyResolvedDistinctToken")
          io.puts Logos::Codegen.emit_matcher(generic, {} of String => String, true, "GenericManifestPriorityToken")
          io.puts Logos::Codegen.emit_matcher(shadowed, {} of String => String, true, "ResolvedShadowedToken")
          io.puts Logos::Codegen.emit_matcher(deferred, {} of String => String, true, "DeferredSkipTieToken")
          io << File.read(File.join(root, "spec/fixtures/generated_error_prefix.cr"))
          io << File.read(File.join(root, "spec/fixtures/generated_priorities.cr"))
        end
        error = IO::Memory.new
        status = Process.run("crystal", ["run", file.path], chdir: root, error: error)
        raise error.to_s unless status.success?
      ensure
        file.delete
      end
    end

    it "validates generated rule bindings and preserves matched callback payloads" do
      root = File.expand_path("../..", __DIR__)
      directory = File.join(root, "temp")
      FileUtils.mkdir_p(directory)
      file = File.tempfile("matcher-binding", ".cr", dir: directory)
      begin
        File.open(file.path, "w") do |io|
          io.puts %q(require "../src/logos")
          {
            "ByteArrayBoundToken"      => %([{"kind":"token","pattern":[255],"variant":"Mark"},{"kind":"regex","pattern":"~(?&digit)","variant":"Digit"}]),
            "ReorderedBindingToken"    => %([{"kind":"token","pattern":"a"},{"kind":"token","pattern":"b"}]),
            "KindBindingToken"         => %([{"kind":"regex","pattern":"a"}]),
            "SkipBindingToken"         => %([{"kind":"token","pattern":"a","skip":true}]),
            "EncodingBindingToken"     => %([{"kind":"token","pattern":"a"}]),
            "RuleEncodingBindingToken" => %([{"kind":"regex","pattern":".","bytes":true}]),
            "BoundResolvedToken"       => %([{"kind":"token","pattern":" ","skip":true,"resolved_priority":2},{"kind":"token","pattern":"+","variant":"Plus","resolved_priority":2},{"kind":"regex","pattern":"[0-9]+","variant":"Number","resolved_priority":2}]),
            "OptionsBindingToken"      => %([{"kind":"token","pattern":"a"}]),
            "VariantBindingToken"      => %([{"kind":"token","pattern":"a","variant":"A"}]),
            "SubpatternBindingToken"   => %([{"kind":"regex","pattern":"(?&digit)"}]),
            "BoundToken"               => %([{"kind":"token","pattern":" ","skip":true},{"kind":"token","pattern":"+","variant":"Plus"},{"kind":"regex","pattern":"[0-9]+","variant":"Number"}]),
          }.each do |name, json|
            subpatterns = case name
                          when "SubpatternBindingToken"
                            {"digit" => "[0-9]"}
                          when "ByteArrayBoundToken"
                            JSON.parse(%({"digit":{"pattern":"\\\\d","bytes":false}})).as_h
                          else
                            {} of String => String
                          end
            utf8 = !{"RuleEncodingBindingToken", "ByteArrayBoundToken"}.includes?(name)
            io.puts Logos::Codegen.emit_matcher(JSON.parse(json).as_a, subpatterns, utf8, name, validate_binding: true)
          end
          io << File.read(File.join(root, "spec/fixtures/generated_binding.cr"))
        end
        error = IO::Memory.new
        status = Process.run("crystal", ["run", file.path], chdir: root, error: error)
        raise error.to_s unless status.success?
      ensure
        file.delete
      end
    end

    it "binds anonymous skips without variants in a strict generated matcher" do
      root = File.expand_path("../..", __DIR__)
      directory = File.join(root, "temp")
      FileUtils.mkdir_p(directory)
      file = File.tempfile("anonymous-skip-matcher", ".cr", dir: directory)
      begin
        patterns = JSON.parse(<<-'JSON').as_a
          [
            {"kind":"regex","pattern":"[ ]+","skip":true,"variant":null},
            {"kind":"regex","pattern":"\n","skip":true,"variant":null},
            {"kind":"regex","pattern":"[a-z]","skip":false,"variant":"Word"}
          ]
          JSON
        file.puts %q(require "../src/logos")
        file.puts Logos::Codegen.emit_matcher(patterns, {} of String => String, true, "AnonymousSkipToken", validate_binding: true)
        file.puts %q(require "../spec/logos/anonymous_skips_spec")
        file.close
        output = IO::Memory.new
        status = Process.run("crystal",
          ["spec", "-Danonymous_skip_prebuilt", file.path, "-e", "runs skip callbacks"],
          chdir: root, output: output, error: output)
        raise output.to_s unless status.success?
        output.to_s.should contain("1 examples, 0 failures, 0 errors")
      ensure
        file.delete
      end
    end

    it "attaches typed payloads in a strict generated matcher" do
      root = File.expand_path("../..", __DIR__)
      directory = File.join(root, "temp")
      FileUtils.mkdir_p(directory)
      file = File.tempfile("typed-payload-matcher", ".cr", dir: directory)
      begin
        patterns = JSON.parse(<<-'JSON').as_a
          [
            {"kind":"token","pattern":" ","skip":true,"variant":null},
            {"kind":"token","pattern":"let","skip":false,"variant":"Let"},
            {"kind":"token","pattern":"f","skip":false,"variant":"Flag"},
            {"kind":"token","pattern":"n","skip":false,"variant":"Nothing"},
            {"kind":"regex","pattern":"[0-9]+","skip":false,"variant":"Integer"},
            {"kind":"regex","pattern":"0x[0-9a-f]+","skip":false,"variant":"Integer"}
          ]
          JSON
        file.puts %q(require "../src/logos")
        file.puts Logos::Codegen.emit_matcher(patterns, {} of String => String, true, "Token", validate_binding: true)
        file.puts %q(require "../spec/logos/typed_payload_spec")
        file.close
        output = IO::Memory.new
        status = Process.run("crystal",
          ["spec", "-Dtyped_payload_prebuilt", file.path, "-e", "reads saved DSL results"],
          chdir: root, output: output, error: output)
        raise output.to_s unless status.success?
        output.to_s.should contain("1 examples, 0 failures, 0 errors")
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

    it "rejects zero-width rules and context-dependent starts in manifests" do
      subpatterns = {} of String => String
      [{"regex", "a?"}, {"token", ""}].each do |kind, pattern|
        patterns = JSON.parse([{kind: kind, pattern: pattern}].to_json).as_a
        expect_raises(Exception, /can match the empty string/) { Logos::Codegen.compile_dfa(patterns, subpatterns, true) }
      end
      patterns = JSON.parse(%([{"kind":"regex","pattern":"^a"}])).as_a
      expect_raises(Exception, /missing a universal start state/) { Logos::Codegen.compile_dfa(patterns, subpatterns, true) }
    end

    it "rejects duplicate variants before emission in either manifest form" do
      [nil, 2].each do |resolved|
        patterns = JSON.parse([
          {kind: "regex", pattern: "a", variant: "A", resolved_priority: resolved},
          {kind: "regex", pattern: "[a]", variant: "A", resolved_priority: resolved},
        ].to_json).as_a
        expect_raises(Exception, /can match simultaneously.*priority 2/) do
          Logos::Codegen.emit_matcher(patterns, {} of String => String, true, "Duplicate")
        end
      end
    end

    it "rejects explicit skip ties and accepts them when shadowed in generic manifests" do
      patterns = JSON.parse(%([
        {"kind":"regex","pattern":"a","variant":"Ignored","priority":2},
        {"kind":"regex","pattern":"[a]","variant":"A","priority":2}
      ])).as_a
      expect_raises(Exception, /can match simultaneously.*priority 2/) do
        Logos::Codegen.emit_matcher(patterns, {} of String => String, true, "SkipTie")
      end
      patterns << JSON.parse(%({"kind":"regex","pattern":"a","variant":"Top","priority":3}))
      Logos::Codegen.emit_matcher(patterns, {} of String => String, true, "Shadowed").should contain("Generated_Shadowed")
    end

    it "preserves first-match ties and rejects explicit ambiguity" do
      patterns = JSON.parse(%([{"resolved_priority":3},{"resolved_priority":3}])).as_a
      Logos::Codegen.resolve_accept([1, 0], patterns).should eq(1)
      patterns = JSON.parse(%([{"resolved_priority":3,"priority_explicit":true},{"resolved_priority":3,"priority_explicit":true}])).as_a
      expect_raises(Exception, /can match simultaneously/) { Logos::Codegen.resolve_accept([0, 1], patterns) }
    end
  end
{% end %}
