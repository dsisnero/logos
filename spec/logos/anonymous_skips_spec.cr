require "../spec_helper"
require "../fixtures/anonymous_skips"
require "file_utils"

describe "anonymous skips" do
  it "runs skip callbacks once without creating enum members" do
    AnonymousSkipToken.precompiled_dfa?.should eq({{ flag?(:anonymous_skip_prebuilt) }})
    lexer = AnonymousSkipToken.lexer("a  \nb!")
    stream = lexer.spanned.to_a
    stream.map(&.[1]).should eq([0...1, 4...5, 5...6])
    stream.first(2).map { |result, _| result.unwrap }.should eq([AnonymousSkipToken::Word, AnonymousSkipToken::Word])
    stream.last[0].error?.should be_true
    lexer.extras.newlines.should eq(1)
    lexer.next.should be_a(Iterator::Stop)
    AnonymousSkipToken.values.should eq([AnonymousSkipToken::Word])
  end

  it "reports a misspelled rule option at compile time" do
    directory = File.expand_path("../../temp", __DIR__)
    FileUtils.mkdir_p(directory)
    file = File.tempfile("unknown-rule-option", ".cr", dir: directory)
    begin
      file.puts <<-'CRYSTAL'
        require "../src/logos"

        Logos.define TypoToken do
          token "a", :A, priorty: 10
        end
        CRYSTAL
      file.close
      error = IO::Memory.new
      status = Process.run("crystal", ["build", "--no-codegen", "--no-color", file.path], error: error)
      status.success?.should be_false
      error.to_s.should contain("Unknown option 'priorty' for token")
    ensure
      file.delete
    end
  end
end
