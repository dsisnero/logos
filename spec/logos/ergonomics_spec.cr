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
      end
    end
  end

  @[Logos::Options(skip: "\\s+")]
  @[Logos::Token("let", variant: :Let)]
  @[Logos::Regex("[0-9]+", variant: :Number)]
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
end
