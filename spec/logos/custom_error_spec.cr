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
end
