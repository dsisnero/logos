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
  @[Logos::Regex(:Number, "[0-9]+")]
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
end
