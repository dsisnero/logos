require "../spec_helper"
require "regex-automata"

module Logos::Spec::CustomError
  struct LexingError
    enum Kind
      NumberNotEven
      NumberTooLong
    end

    getter kind : Kind

    def initialize(@kind : Kind = Kind::NumberNotEven)
    end

    def ==(other : self) : Bool
      @kind == other.kind
    end
  end

  struct ErrorExtras
    property errors : Array(String)

    def initialize
      @errors = [] of String
    end
  end

  Logos.define Token do
    error_type LexingError
    extras ErrorExtras

    regex "[ \\t\\n\\r]+", :Whitespace do
      Logos::Skip.new
    end

    regex "[0-9]+", :Number do |lex|
      value = lex.slice.to_i
      if value.odd?
        lex.extras.errors << "odd"
        Logos::FilterResult::Error.new(LexingError.new(LexingError::Kind::NumberNotEven))
      elsif value > 99
        lex.extras.errors << "too_long"
        Logos::FilterResult::Error.new(LexingError.new(LexingError::Kind::NumberTooLong))
      else
        Logos::FilterResult::Emit.new(value)
      end
    end
  end

  describe "token variants with associated data" do
    it "handles custom error types with callbacks" do
      lexer = Logos::Lexer(Token, String, ErrorExtras, LexingError).new("24 25 100")

      result = lexer.next
      result = result.as(Logos::Result(Token, LexingError))
      result.ok?.should be_true
      result.unwrap.should eq(Token::Number)
      lexer.callback_value_as(Int32).should eq(24)

      result = lexer.next
      result = result.as(Logos::Result(Token, LexingError))
      result.error?.should be_true
      result.unwrap_error.should eq(LexingError.new(LexingError::Kind::NumberNotEven))

      result = lexer.next
      result = result.as(Logos::Result(Token, LexingError))
      result.error?.should be_true
      result.unwrap_error.should eq(LexingError.new(LexingError::Kind::NumberTooLong))
    end

    it "handles error callbacks with extras" do
      lexer = Logos::Lexer(Token, String, ErrorExtras, LexingError).new("25 100")

      result = lexer.next
      result = result.as(Logos::Result(Token, LexingError))
      result.error?.should be_true
      result.unwrap_error.should eq(LexingError.new(LexingError::Kind::NumberNotEven))

      result = lexer.next
      result = result.as(Logos::Result(Token, LexingError))
      result.error?.should be_true
      result.unwrap_error.should eq(LexingError.new(LexingError::Kind::NumberTooLong))

      lexer.extras.errors.should eq(["odd", "too_long"])
    end
  end

  module ErrorWithCallbackCallback
    Logos.define Token do
      error_type String do |lex|
        lex.extras.errors << "error_callback"
        "error_value"
      end
      extras ErrorExtras

      token "a", :A
    end
  end

  describe "error callbacks with extras" do
    it "calls the error callback on unmatched input" do
      lexer = Logos::Lexer(ErrorWithCallbackCallback::Token, String, ErrorExtras, String).new("x")
      result = lexer.next
      result = result.as(Logos::Result(ErrorWithCallbackCallback::Token, String))
      result.error?.should be_true
      result.unwrap_error.should eq("error_value")
      lexer.extras.errors.should eq(["error_callback"])
    end
  end

  module CustomErrorCallbackModule
    Logos.define Token do
      error_type String do |lex|
        "error:" + lex.slice
      end

      regex "a", :A
    end
  end

  describe "custom error callback with slice info" do
    it "produces error values from the error callback" do
      lexer = Logos::Lexer(CustomErrorCallbackModule::Token, String, Logos::NoExtras, String).new("b")
      result = lexer.next
      result = result.as(Logos::Result(CustomErrorCallbackModule::Token, String))
      result.error?.should be_true
      result.unwrap_error.should eq("error:b")
    end
  end

  module TokenA
    Logos.define Token do
      error_type String do |lex|
        "errA"
      end
      extras ErrorExtras
      token "a", :A
    end
  end

  module TokenB
    Logos.define Token do
      error_type String do |lex|
        "errB"
      end
      extras ErrorExtras
      token "b", :B
    end
  end

  describe "error callback propagation across tokens" do
    it "uses separate error callbacks for each token type" do
      lexer = Logos::Lexer(TokenA::Token, String, ErrorExtras, String).new("x")
      result = lexer.next
      result = result.as(Logos::Result(TokenA::Token, String))
      result.error?.should be_true
      result.unwrap_error.should eq("errA")

      lexer2 = Logos::Lexer(TokenB::Token, String, ErrorExtras, String).new("y")
      result2 = lexer2.next
      result2 = result2.as(Logos::Result(TokenB::Token, String))
      result2.error?.should be_true
      result2.unwrap_error.should eq("errB")
    end
  end
end
