require "../spec_helper"

module Logos::Spec::CallbackDispatch
  def self.record_error(lexer : Logos::Lexer) : String
    lexer.extras << lexer.slice
    "default:#{lexer.slice}"
  end

  module DefineAPI
    Logos.define Token do
      extras Array(String)
      error_type String do |lexer|
        Logos::Spec::CallbackDispatch.record_error(lexer)
      end

      regex "[0-9]", :Number do |lexer|
        Logos::Option(Int32).new(lexer.slice.to_i)
      end
      token "s", :Ignored do |lexer|
        Logos.skip(lexer)
      end
      skip_token "u", :Ignored do
        Logos::Result(Nil, String).ok(nil)
      end
      skip_token "k", :Ignored do
        Logos::Result(Logos::Skip, String).ok(Logos::Skip.new)
      end
      skip_token "q", :Ignored do
        Logos::Result(Logos::Skip, String).error("skip error")
      end
      token "n", :Number do
        Logos::Option(Int32).new(nil)
      end
      token "b", :Plain do
        false
      end
      token "r", :Number do
        Logos::Result(Int32, String).error("result error")
      end
      token "f", :Number do
        Logos::FilterResult::Error.new("filter error")
      end
      token "c", :Flag do
        Logos::FilterResult::Emit.new(false)
      end
      token "t", :Plain do
        true
      end
      token "x", :Redirect do
        Token::Plain
      end
    end
  end

  @[Logos::Options(extras: Array(String), error: String, error_callback: ->(lexer : Logos::Lexer(AnnotatedToken, String, Array(String), String)) { Logos::Spec::CallbackDispatch.record_error(lexer) })]
  @[Logos::Regex(:Number, "[0-9]", callback: ->(lexer) { Logos::Option(Int32).new(lexer.slice.to_i) })]
  @[Logos::Token(:Ignored, "s", callback: ->(lexer) { Logos.skip(lexer) })]
  @[Logos::Token(:Ignored, "u", skip: true, callback: -> { Logos::Result(Nil, String).ok(nil) })]
  @[Logos::Token(:Ignored, "k", skip: true, callback: -> { Logos::Result(Logos::Skip, String).ok(Logos::Skip.new) })]
  @[Logos::Token(:Ignored, "q", skip: true, callback: -> { Logos::Result(Logos::Skip, String).error("skip error") })]
  @[Logos::Token(:Number, "n", callback: -> { Logos::Option(Int32).new(nil) })]
  @[Logos::Token(:Plain, "b", callback: -> { false })]
  @[Logos::Token(:Number, "r", callback: -> { Logos::Result(Int32, String).error("result error") })]
  @[Logos::Token(:Number, "f", callback: -> { Logos::FilterResult::Error.new("filter error") })]
  @[Logos::Token(:Flag, "c", callback: -> { Logos::FilterResult::Emit.new(false) })]
  @[Logos::Token(:Plain, "t", callback: -> { true })]
  @[Logos::Token(:Redirect, "x", callback: -> { AnnotatedToken::Plain })]
  enum AnnotatedToken
    Number
    Ignored
    Plain
    Flag
    Redirect
  end

  logos_derive(AnnotatedToken)

  INPUT = "7suknbqrfctx8?"

  def self.assert_stream(lexer : Logos::Lexer(T, String, Array(String), String), number : T, flag : T, plain : T) : Nil forall T
    entries = lexer.spanned.map do |result, span|
      {result, span, lexer.callback_value_as(Int32)}
    end.to_a

    entries.map(&.[1]).should eq([0...1, 4...5, 5...6, 6...7, 7...8, 8...9,
                                  9...10, 10...11, 11...12, 12...13, 13...14])
    entries.map { |entry| entry[2] }.should eq([7, nil, nil, nil, nil, nil, nil, nil, nil, 8, nil])
    entries.map { |entry| entry[0].value? }.should eq([number, nil, nil, nil, nil, nil, flag, plain, plain, number, nil])
    entries.compact_map { |entry| entry[0].unwrap_error if entry[0].error? }.should eq(
      ["default:n", "default:b", "skip error", "result error", "filter error", "default:?"]
    )
    entries[0][0].payload_for!(number, Int32).should eq(7)
    entries[6][0].payload_for!(flag, Bool).should be_false
    entries[9][0].payload_for!(number, Int32).should eq(8)
    lexer.extras.should eq(["n", "b", "?"])
    lexer.next.should eq(Iterator::Stop::INSTANCE)
  end
end

describe "callback dispatch" do
  it "preserves payloads, skips, and error spans with Logos.define" do
    type = Logos::Spec::CallbackDispatch::DefineAPI::Token
    Logos::Spec::CallbackDispatch.assert_stream(type.lexer(Logos::Spec::CallbackDispatch::INPUT),
      Logos::Spec::CallbackDispatch::DefineAPI::Token::Number, Logos::Spec::CallbackDispatch::DefineAPI::Token::Flag,
      Logos::Spec::CallbackDispatch::DefineAPI::Token::Plain)
  end

  it "preserves payloads, skips, and error spans with annotations" do
    type = Logos::Spec::CallbackDispatch::AnnotatedToken
    Logos::Spec::CallbackDispatch.assert_stream(type.lexer(Logos::Spec::CallbackDispatch::INPUT),
      Logos::Spec::CallbackDispatch::AnnotatedToken::Number, Logos::Spec::CallbackDispatch::AnnotatedToken::Flag,
      Logos::Spec::CallbackDispatch::AnnotatedToken::Plain)
  end
end
