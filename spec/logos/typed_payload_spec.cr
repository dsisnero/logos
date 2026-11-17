require "../spec_helper"
require "file_utils"

module TypedPayloadExamples
  Logos.define Token do
    skip_token " "
    token "let", :Let
    token "f", :Flag, payload: Bool do
      false
    end
    token "n", :Nothing, payload: Nil do
      nil
    end
    regex "[0-9]+", :Integer, payload: Int64 do |lex|
      lex.slice.to_i64
    end
    regex "0x[0-9a-f]+", :Integer, payload: Int64 do |lex|
      lex.slice[2..].to_i64(16)
    end
  end

  @[Logos::Options(skip: " +")]
  @[Logos::Regex(:Integer, "[0-9]+", payload: Int64, callback: ->(lex) { lex.slice.to_i64 })]
  enum Annotated
    Integer
  end

  logos_derive(Annotated)
end

describe "typed payload declarations" do
  it "reads saved DSL results with variant-checked accessors" do
    token = TypedPayloadExamples::Token
    token.precompiled_dfa?.should eq({{ flag?(:typed_payload_prebuilt) }})
    first, second, plain, error, flag, nothing, hex = token.lex_all("42 7 let ! f n 0xa")

    token.integer_value!(first).should eq(42_i64)
    token.integer_value!(second).should eq(7_i64)
    token.integer_value!(hex).should eq(10_i64)
    expect_raises(Exception, "Expected token Integer") { token.integer_value!(plain) }
    expect_raises(Exception, "Expected token Integer") { token.integer_value!(error) }
    token.flag_value!(flag).should be_false
    token.nothing_value!(nothing).should be_nil
  end

  it "reads saved annotated results with variant-checked accessors" do
    token = TypedPayloadExamples::Annotated
    first, second = token.lex_all("42 7")
    token.integer_value!(first).should eq(42_i64)
    token.integer_value!(second).should eq(7_i64)
  end

  it "diagnoses invalid types and accessor collisions during compilation" do
    cases = {
      %q(regex "[0-9]+", :Number, payload: Int64 do; "wrong"; end) => "expected argument #1 to 'Logos::CallbackValue(Int64).new' to be Int64",
      %q(token "a", :Number, payload: Int64 do; 1_i64; end
         token "b", :Number, payload: String do; "b"; end) => "Conflicting payload types for Number",
      %q(token "a", :HTTP, payload: Int64 do; 1_i64; end
         token "b", :Http, payload: Int64 do; 2_i64; end) => "Payload accessor http_value! collides",
    }

    directory = File.expand_path("../../temp", __DIR__)
    FileUtils.mkdir_p(directory)
    cases.each do |definition, diagnostic|
      file = File.tempfile("typed-payload", ".cr", dir: directory)
      begin
        file.puts %q(require "../src/logos")
        file.puts "Logos.define InvalidPayloadToken do\n#{definition}\nend"
        file.puts %q(InvalidPayloadToken.lex_all("a"))
        file.close
        error = IO::Memory.new
        status = Process.run("crystal", ["build", "--no-codegen", "--no-color", file.path], error: error)
        status.success?.should be_false
        error.to_s.should contain(diagnostic)
      ensure
        file.delete
      end
    end
  end
end
