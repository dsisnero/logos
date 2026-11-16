require "../spec_helper"
require "file_utils"

module Logos::Spec::PayloadExamples
  ROOT = File.expand_path("../..", __DIR__)

  def self.run(name : String, args : Array(String) = [] of String) : {String, String}
    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run("crystal", ["run", "examples/#{name}.cr", "--", *args],
      chdir: ROOT, output: output, error: error)
    raise "#{name} exited with #{status.exit_code}: #{error}" unless status.success?
    {output.to_s, error.to_s}
  end

  def self.with_input(source : String, &)
    directory = File.join(ROOT, "temp")
    FileUtils.mkdir_p(directory)
    file = File.tempfile("payload-example", ".txt", dir: directory) { |input| input << source }
    begin
      yield file.path
    ensure
      file.delete
    end
  end
end

describe "payload examples" do
  it "evaluates collected calculator tokens with Rust integer division" do
    output, error = Logos::Spec::PayloadExamples.run("calculator", ["1 + 7 * (3 - 4) / 2"])
    output.should eq("[AST]\n(1 + ((7 * (3 - 4)) / 2))\n\n[result]\n-2\n")
    error.should be_empty
  end

  it "prints typed values after collecting the token stream" do
    output, error = Logos::Spec::PayloadExamples.run("token_values")
    output.should eq("Tokenizing: 123 + 45.67 \"hello\"\n\nInteger: 123\nPlus\nFloat: 45.67\nString: hello\n")
    error.should be_empty
  end

  it "reports successful integer payloads, overflow, and each non-ASCII span" do
    output, error = Logos::Spec::PayloadExamples.run("custom_error", ["Hello 255 256 Jéàrome"])
    output.lines.should eq([
      "Word: Hello",
      "Integer: 255",
      "Error: InvalidInteger(overflow error) (slice=256)",
      "Word: J",
      "Error: NonAsciiCharacter(é) (slice=é)",
      "Error: NonAsciiCharacter(à) (slice=à)",
      "Word: rome",
    ])
    error.should be_empty
  end

  it "reports positions using the line and byte column at each word" do
    Logos::Spec::PayloadExamples.with_input("one two\né three\n") do |path|
      output, error = Logos::Spec::PayloadExamples.run("extras", [path])
      output.lines.should eq([
        "Word 'one' found at (1, 0)",
        "Word 'two' found at (1, 4)",
        "Word 'é' found at (2, 0)",
        "Word 'three' found at (2, 3)",
      ])
      error.should be_empty
    end
  end

  {"json", "json_borrowed"}.each do |name|
    it "reads scalar payloads and compares raw object keys by content in #{name}" do
      Logos::Spec::PayloadExamples.with_input(%q({"key":[],"key":[true,false,12.5,"a\n",null]})) do |path|
        output, error = Logos::Spec::PayloadExamples.run(name, [path])
        output.should eq(%q({"\"key\"" => [true, false, 12.5, "\"a\\n\"", nil]}) + "\n")
        error.should be_empty
      end
    end

    it "keeps the missing-colon diagnostic at the offending span in #{name}" do
      Logos::Spec::PayloadExamples.with_input(%q({"key" 1})) do |path|
        output, error = Logos::Spec::PayloadExamples.run(name, [path])
        output.should be_empty
        error.should eq("Invalid JSON at 7...8: unexpected token here, expecting ':'\n")
      end
    end
  end

  it "evaluates nested interpolation and preserves the enclosing lexer position" do
    output, error = Logos::Spec::PayloadExamples.run("string_interpolation")
    output.lines.should eq([
      "name = Mark",
      "greeting = Hi Mark!",
      "surname = Scott",
      "greeting2 = Hi Mark Scott!",
      "greeting3 = Hi Mark Scott!!",
    ])
    error.should be_empty
  end
end
