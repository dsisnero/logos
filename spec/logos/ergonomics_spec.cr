require "../spec_helper"
require "regex-automata"

module Logos::Spec::Ergonomics
  class Extras
    property seen : Int32

    def initialize
      @seen = 0
    end
  end

  module DefineAPI
    Logos.define Token do
      extras Extras
      error_type Nil

      regex "\\s+", :Whitespace do
        Logos::Skip.new
      end

      token "let", :Let
      regex "[0-9]+", :Number do |lex|
        lex.extras.seen += 1
        Logos::Result(Int32, Nil).ok(lex.slice.to_i32)
      end
    end
  end

  @[Logos::Options(skip: "\\s+")]
  @[Logos::Token(:Let, "let")]
  @[Logos::Regex(:Number, "[0-9]+", callback: ->(lex) { Logos::FilterResult::Emit.new(lex.slice.to_i32) })]
  enum AnnotatedToken
    Let
    Number
  end

  logos_derive(AnnotatedToken)
end

describe "token entrypoints" do
  it "builds lexers from define API token type" do
    lexer = Logos::Spec::Ergonomics::DefineAPI::Token.lexer_with_extras("let 42", Logos::Spec::Ergonomics::Extras.new)

    result = lexer.next
    result = result.as(Logos::Result(Logos::Spec::Ergonomics::DefineAPI::Token, Nil))
    result.unwrap.should eq(Logos::Spec::Ergonomics::DefineAPI::Token::Let)

    result = lexer.next
    result = result.as(Logos::Result(Logos::Spec::Ergonomics::DefineAPI::Token, Nil))
    result.unwrap.should eq(Logos::Spec::Ergonomics::DefineAPI::Token::Number)
    lexer.extras.seen.should eq(1)
    lexer.callback_value_as(Int32).should eq(42)
  end

  it "collects token stream with lex_all" do
    results = Logos::Spec::Ergonomics::DefineAPI::Token.lex_all("let 42", Logos::Spec::Ergonomics::Extras.new)
    results.map(&.unwrap).should eq([
      Logos::Spec::Ergonomics::DefineAPI::Token::Let,
      Logos::Spec::Ergonomics::DefineAPI::Token::Number,
    ])
  end

  it "builds lexers from annotation API token type" do
    lexer = Logos::Spec::Ergonomics::AnnotatedToken.lexer("let 42")

    result = lexer.next
    result = result.as(Logos::Result(Logos::Spec::Ergonomics::AnnotatedToken, Nil))
    result.unwrap.should eq(Logos::Spec::Ergonomics::AnnotatedToken::Let)

    result = lexer.next
    result = result.as(Logos::Result(Logos::Spec::Ergonomics::AnnotatedToken, Nil))
    result.unwrap.should eq(Logos::Spec::Ergonomics::AnnotatedToken::Number)
  end

  it "provides typed payload helpers bound to token variants" do
    lexer = Logos::Spec::Ergonomics::DefineAPI::Token.lexer_with_extras("let 42", Logos::Spec::Ergonomics::Extras.new)

    let_result = lexer.next
    let_result = let_result.as(Logos::Result(Logos::Spec::Ergonomics::DefineAPI::Token, Nil))
    let_result.matches?(Logos::Spec::Ergonomics::DefineAPI::Token::Let).should be_true
    lexer.payload_for(let_result, Logos::Spec::Ergonomics::DefineAPI::Token::Number, Int32).should be_nil

    number_result = lexer.next
    number_result = number_result.as(Logos::Result(Logos::Spec::Ergonomics::DefineAPI::Token, Nil))
    number_result.matches?(Logos::Spec::Ergonomics::DefineAPI::Token::Number).should be_true
    lexer.payload_for(number_result, Logos::Spec::Ergonomics::DefineAPI::Token::Number, Int32).should eq(42)
    lexer.payload_for!(number_result, Logos::Spec::Ergonomics::DefineAPI::Token::Number, Int32).should eq(42)
  end

  it "keeps the first payload after advancing to the same variant" do
    lexer = Logos::Spec::Ergonomics::DefineAPI::Token.lexer("42 7")
    first = lexer.next.as(Logos::Result(Logos::Spec::Ergonomics::DefineAPI::Token, Nil))
    second = lexer.next.as(Logos::Result(Logos::Spec::Ergonomics::DefineAPI::Token, Nil))

    lexer.payload_for!(first, Logos::Spec::Ergonomics::DefineAPI::Token::Number, Int32).should eq(42)
    lexer.payload_for!(second, Logos::Spec::Ergonomics::DefineAPI::Token::Number, Int32).should eq(7)
    lexer.callback_value_as(Int32).should eq(7)
  end

  it "keeps annotated payloads across skips, errors, and collection" do
    results = Logos::Spec::Ergonomics::AnnotatedToken.lex_all("42 ! 7 let")
    first, error, second, plain = results
    number = Logos::Spec::Ergonomics::AnnotatedToken::Number
    let = Logos::Spec::Ergonomics::AnnotatedToken::Let

    first.payload_for!(number, Int32).should eq(42)
    second.payload_for(number, Int32).should eq(7)
    error.error?.should be_true
    error.payload_for(number, Int32).should be_nil
    plain.payload_for(let, Int32).should be_nil
    first.payload_for(let, Int32).should be_nil
    first.payload_for(number, String).should be_nil
    expect_raises(Exception, "Expected token Let") { first.payload_for!(let, Int32) }
    expect_raises(Exception, "Expected payload String") { first.payload_for!(number, String) }
  end

  it "attaches a payload to a direct token match without leaking it to the next match" do
    token_type = Logos::Spec::Ergonomics::DefineAPI::Token
    lexer = token_type.lexer("42let")
    number = Logos::Spec::Ergonomics::DefineAPI::Token::Number
    let = Logos::Spec::Ergonomics::DefineAPI::Token::Let

    first = token_type.lex(lexer).as(Logos::Result(Logos::Spec::Ergonomics::DefineAPI::Token, Nil))
    second = token_type.lex(lexer).as(Logos::Result(Logos::Spec::Ergonomics::DefineAPI::Token, Nil))

    first.payload_for!(number, Int32).should eq(42)
    second.matches?(let).should be_true
    second.payload_for(let, Int32).should be_nil
  end

  it "preserves result equality and distinguishes boxed nil from a missing payload" do
    with_payload = Logos::Result(Int32, String).ok(7, Logos::CallbackValue.new(nil))
    without_payload = Logos::Result(Int32, String).ok(7)

    with_payload.should eq(without_payload)
    with_payload.hash.should eq(without_payload.hash)
    with_payload.payload_for!(7, Nil).should be_nil
    expect_raises(Exception, "Expected payload Nil") { without_payload.payload_for!(7, Nil) }
  end
end
