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

module Logos::Spec::CustomError::Upstream
  alias LexingError = NumberTooLong | NumberNotEven | UnrecognisedCharacter

  struct NumberTooLong
  end

  record NumberNotEven, number : UInt32
  record UnrecognisedCharacter, character : Char

  Logos.define StreamToken do
    error_type LexingError do |lex|
      UnrecognisedCharacter.new(lex.slice[0])
    end
    regex "[0-9]+", :Number do |lex|
      if number = lex.slice.to_u32?
        if number.even?
          Logos::FilterResult::Emit.new(number)
        else
          Logos::FilterResult::Error.new(NumberNotEven.new(number))
        end
      else
        Logos::FilterResult::Error.new(NumberTooLong.new)
      end
    end
    regex "[a-zA-Z_]+", :Identifier do |lex|
      Logos::FilterResult::Emit.new(lex.slice)
    end
  end

  @[Logos::Options(extras: Array(String), error_type: String, error_callback: ->(lex : Logos::Lexer(EmptyAToken, String, Array(String), String)) {
    lex.extras << "a"
    "a"
  })]
  enum EmptyAToken
    Unused
  end

  logos_derive(EmptyAToken)

  @[Logos::Options(extras: Array(String), error_type: String, error_callback: ->(lex : Logos::Lexer(EmptyBToken, String, Array(String), String)) {
    lex.extras << "b"
    "b"
  })]
  enum EmptyBToken
    Unused
  end

  logos_derive(EmptyBToken)

  describe "vendored custom error streams" do
    it "preserves typed payloads, overflow and the default error callback with exact spans" do
      long_number = "1111111111111111111111111111111111111111111111111111111"
      lexer = StreamToken.lexer("123abc1234xyz#{long_number},")
      stream = lexer.spanned
      expected = [
        {nil, NumberNotEven.new(123_u32), nil, "123", 0...3},
        {StreamToken::Identifier, nil, "abc", "abc", 3...6},
        {StreamToken::Number, nil, 1234_u32, "1234", 6...10},
        {StreamToken::Identifier, nil, "xyz", "xyz", 10...13},
        {nil, NumberTooLong.new, nil, long_number, 13...68},
        {nil, UnrecognisedCharacter.new(','), nil, ",", 68...69},
      ]
      expected.each do |variant, error, payload, slice, span|
        actual, actual_span = stream.next.as({Logos::Result(StreamToken, LexingError), Logos::Span})
        if variant
          actual.unwrap.should eq(variant)
          if payload.is_a?(String)
            actual.payload_for(variant, String).should eq(payload)
          else
            actual.payload_for(variant, UInt32).should eq(payload)
          end
        else
          actual.unwrap_error.should eq(error)
        end
        actual_span.should eq(span)
        lexer.slice.should eq(slice)
      end
      stream.next.should eq(Iterator::Stop::INSTANCE)
    end

    it "carries extras from fifteen error callbacks into a second ten-error lexer" do
      lexer_a = EmptyAToken.lexer("a" * 15)
      stream_a = lexer_a.spanned
      15.times do |index|
        stream_a.next.should eq({Logos::Result(EmptyAToken, String).error("a"), index...index + 1})
        lexer_a.slice.should eq("a")
      end
      stream_a.next.should eq(Iterator::Stop::INSTANCE)

      lexer_b = EmptyBToken.lexer_with_extras("b" * 10, lexer_a.extras)
      stream_b = lexer_b.spanned
      10.times do |index|
        stream_b.next.should eq({Logos::Result(EmptyBToken, String).error("b"), index...index + 1})
        lexer_b.slice.should eq("b")
      end
      stream_b.next.should eq(Iterator::Stop::INSTANCE)
      lexer_b.extras.should eq(Array.new(15, "a") + Array.new(10, "b"))
    end
  end
end
