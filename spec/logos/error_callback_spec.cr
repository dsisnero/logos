require "../spec_helper"
require "regex-automata"

module Logos::Spec::ErrorCallback
  class ErrorFromLexer
    getter slice : String

    def initialize(@slice : String)
    end

    def ==(other : self) : Bool
      slice == other.slice
    end
  end

  module DefineAPI
    Logos.define Token do
      error_type ErrorFromLexer do |lex|
        ErrorFromLexer.new(lex.slice)
      end

      token "a", :A
    end
  end

  @[Logos::Options(error: ErrorFromLexer, error_callback: ->(lex : Logos::Lexer(Logos::Spec::ErrorCallback::AnnotatedToken, String, Logos::NoExtras, Logos::Spec::ErrorCallback::ErrorFromLexer)) { ErrorFromLexer.new(lex.slice) })]
  @[Logos::Token("a", variant: :A)]
  enum AnnotatedToken
    A
  end

  logos_derive(AnnotatedToken)
end

describe "error callbacks" do
  it "uses error callbacks in Logos.define" do
    lexer = Logos::Lexer(Logos::Spec::ErrorCallback::DefineAPI::Token, String, Logos::NoExtras, Logos::Spec::ErrorCallback::ErrorFromLexer).new("b")
    result = lexer.next
    result = result.as(Logos::Result(Logos::Spec::ErrorCallback::DefineAPI::Token, Logos::Spec::ErrorCallback::ErrorFromLexer))
    result.error?.should be_true
    result.unwrap_error.should eq(Logos::Spec::ErrorCallback::ErrorFromLexer.new("b"))
  end

  it "uses error callbacks with annotations" do
    lexer = Logos::Lexer(Logos::Spec::ErrorCallback::AnnotatedToken, String, Logos::NoExtras, Logos::Spec::ErrorCallback::ErrorFromLexer).new("b")
    result = lexer.next
    result = result.as(Logos::Result(Logos::Spec::ErrorCallback::AnnotatedToken, Logos::Spec::ErrorCallback::ErrorFromLexer))
    result.error?.should be_true
    result.unwrap_error.should eq(Logos::Spec::ErrorCallback::ErrorFromLexer.new("b"))
  end
end
