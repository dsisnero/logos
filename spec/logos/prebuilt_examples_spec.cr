require "../spec_helper"

{% if flag?(:codegen_library) %}
  require "../../src/logos_codegen"
  require "file_utils"

  module Logos::Spec::PrebuiltExamples
    ROOT = File.expand_path("../..", __DIR__)

    def self.check(example : String, matcher_name : String, args : Array(String), expected : String, contract : String) : Nil
      directory = File.join(ROOT, "temp", "prebuilt-#{example}")
      FileUtils.mkdir_p(directory)
      manifest = JSON.parse(File.read(File.join(ROOT, "examples/#{example}.logos.json")))
      source = Logos::Codegen.emit_matcher(manifest["patterns"].as_a, manifest["subpatterns"].as_h,
        manifest["utf8"].as_bool, manifest["name"].as_s, validate_binding: true)
      File.write(File.join(directory, "#{matcher_name}.cr"), source)
      driver = File.join(directory, "driver.cr")

      path = IO::Memory.new
      status = Process.run("crystal", ["env", "CRYSTAL_PATH"], output: path)
      raise "cannot read Crystal load path" unless status.success?
      environment = {"CRYSTAL_PATH" => "#{directory}:#{path.to_s.strip}"}
      {false, true}.each do |precompiled|
        binding_check = "raise \"matcher mode mismatch\" unless #{manifest["name"].as_s}.precompiled_dfa? == #{precompiled}"
        binding_check += "\nraise \"binding metadata missing\" unless Logos.generated_matcher_binding?(#{manifest["name"].as_s.inspect})" if precompiled
        File.write(driver, "require #{"../../examples/#{example}".inspect}\n#{contract}\n#{binding_check}\n")
        binary = File.join(directory, precompiled ? "generated" : "runtime")
        build_args = ["build", driver, "-o", binary]
        build_args << "-Dprecompiled" if precompiled
        error = IO::Memory.new
        status = Process.run("crystal", build_args, chdir: ROOT, env: environment, error: error)
        raise "could not build #{example}: #{error}" unless status.success?
        output = IO::Memory.new
        error.clear
        status = Process.run(binary, args, chdir: ROOT, output: output, error: error)
        raise "#{example} failed: #{error}" unless status.success?
        output.to_s.should eq(expected)
        error.to_s.should be_empty
      end
      manifest["validate_binding"]?.try(&.as_bool).should be_true
      manifest["patterns"].as_a.each do |rule|
        rule["variant"]?.try(&.as_s).should_not be_nil
        rule["skip"]?.try(&.as_bool).should_not be_nil
      end
    end
  end

  describe "shipped strict prebuilds" do
    it "preserves the benchmark token and span contract with strict binding" do
      root = Logos::Spec::PrebuiltExamples::ROOT
      manifest = JSON.parse(File.read(File.join(root, "benchmarks/benchmark_token.logos.json")))
      FileUtils.mkdir_p(File.join(root, "temp"))
      generated = File.join(root, "temp/strict_benchmark_token.cr")
      source = Logos::Codegen.emit_matcher(manifest["patterns"].as_a, {} of String => String,
        true, manifest["name"].as_s, validate_binding: true)
      File.write(generated, source)
      driver = File.join(root, "temp/strict_benchmark_contract.cr")
      contract = File.read(File.join(root, "benchmarks/prebuild_contract.cr"))
        .sub(%q(require "../temp/generated_benchmark_token"), %q(require "./strict_benchmark_token"))
      File.write(driver, contract)
      output = IO::Memory.new
      error = IO::Memory.new
      status = Process.run("crystal", ["run", driver], chdir: root, output: output, error: error)
      raise error.to_s unless status.success?
      output.to_s.should eq("generated/runtime contract passed\n")
      manifest["validate_binding"]?.try(&.as_bool).should be_true
    end

    it "preserves custom errors, typed payloads, and byte spans" do
      Logos::Spec::PrebuiltExamples.check("custom_error", "generated_token_with_error",
        ["Hello 255 256 Jéàrome"],
        "Word: Hello\nInteger: 255\nError: InvalidInteger(overflow error) (slice=256)\nWord: J\nError: NonAsciiCharacter(é) (slice=é)\nError: NonAsciiCharacter(à) (slice=à)\nWord: rome\n",
        <<-'CRYSTAL'
        stream = Token.lexer("255 256 é").spanned.to_a
        raise "incorrect error spans" unless stream.map(&.[1]) == [0...3, 4...7, 8...10]
        raise "missing typed payload" unless stream[0][0].payload_for!(Token::Integer, UInt8) == 255
        raise "wrong overflow error" unless stream[1][0].unwrap_error.kind == LexingError::Kind::InvalidInteger
        raise "wrong Unicode error" unless stream[2][0].unwrap_error.detail == "é"
        CRYSTAL
      )
    end

    it "preserves newline extras and word-position payloads" do
      path = File.join(Logos::Spec::PrebuiltExamples::ROOT, "temp", "prebuilt-extras-input.txt")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "one two\né three\n")
      Logos::Spec::PrebuiltExamples.check("extras", "generated_token", [path],
        "Word 'one' found at (1, 0)\nWord 'two' found at (1, 4)\nWord 'é' found at (2, 0)\nWord 'three' found at (2, 3)\n",
        <<-'CRYSTAL'
        lexer = Token.lexer("one\né\n")
        stream = lexer.spanned.to_a
        raise "wrong extras spans" unless stream.map(&.[1]) == [0...3, 4...6]
        positions = stream.map { |result, _| result.payload_for!(Token::Word, Tuple(Int32, Int32)) }
        raise "wrong position payloads" unless positions == [{1, 0}, {2, 0}]
        raise "wrong final extras" unless lexer.extras.line == 3 && lexer.extras.line_start == 7
        CRYSTAL
      )
    end

    it "preserves interpreter output and skips non-operator text" do
      path = File.join(Logos::Spec::PrebuiltExamples::ROOT, "temp", "prebuilt-brainfuck-input.bf")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "comment\n++++++++[>++++++++<-]>+.")
      Logos::Spec::PrebuiltExamples.check("brainfuck", "generated_op", [path], "A",
        <<-'CRYSTAL'
        stream = Op.lexer("x+\nλ>-").spanned.to_a
        raise "wrong operator spans" unless stream.map(&.[1]) == [1...2, 5...6, 6...7]
        raise "wrong operator tokens" unless stream.map(&.[0].unwrap) == [Op::IncData, Op::IncPointer, Op::DecData]
        CRYSTAL
      )
    end
  end
{% end %}
