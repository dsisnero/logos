require "../spec_helper"
require "regex-automata"

module Logos::Spec::Callbacks
  module CallbackValues
    Logos.define Token do
      error_type Nil

      # Skip whitespace
      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "[0-9]+", :Integer do |lex|
        value = lex.slice.to_i64
        Logos::Filter::Emit.new(value)
      end

      regex "[0-9]+\\.[0-9]+", :Float do |lex|
        value = lex.slice.to_f64
        Logos::Filter::Emit.new(value)
      end

      token "+", :Plus
    end
  end

  module RepetitionPatterns
    Logos.define Token do
      error_type Nil

      # Whitespace skip
      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "a{2,5}", :TwoToFiveA
      regex "a{2}", :TwoA
      regex "a{2,}", :TwoOrMoreA
      regex "a{0,3}", :UpToThreeA
    end
  end

  describe "callback returning values (token variants with associated data)" do
    it "parses numbers with callbacks returning values" do
      lexer = Logos::Lexer(CallbackValues::Token, String, Logos::NoExtras, Nil).new("42 3.14 +")

      # First token: Integer with value 42
      result = lexer.next
      result.should_not be_nil
      result.should be_a(Logos::Result(CallbackValues::Token, Nil))
      result = result.as(Logos::Result(CallbackValues::Token, Nil))
      result.ok?.should be_true
      result.unwrap.should eq(CallbackValues::Token::Integer)
      lexer.int_value.should eq(42)
      lexer.slice.should eq("42")

      # Second token: Float with value 3.14
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(CallbackValues::Token, Nil))
      result.ok?.should be_true
      result.unwrap.should eq(CallbackValues::Token::Float)
      lexer.float_value.should eq(3.14)
      lexer.slice.should eq("3.14")

      # Third token: Plus without value
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(CallbackValues::Token, Nil))
      result.ok?.should be_true
      result.unwrap.should eq(CallbackValues::Token::Plus)
      lexer.int_value.should be_nil
      lexer.float_value.should be_nil
      lexer.slice.should eq("+")

      # End of input
      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  module BoolCallbacks
    Logos.define Token do
      error_type Nil

      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "[a-z]+", :Word do |lex|
        lex.slice != "skip"
      end
    end
  end

  module FilterResultCallbacks
    struct CustomError
      getter message : String

      def initialize(@message : String = "")
      end

      def ==(other : self) : Bool
        @message == other.message
      end
    end

    Logos.define Token do
      error_type CustomError

      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "[0-9]+", :Number do |lex|
        value = lex.slice.to_i
        if value == 0
          Logos::FilterResult::Skip.new
        elsif value > 10
          Logos::FilterResult::Error.new(CustomError.new("too big"))
        else
          true
        end
      end
    end
  end

  describe "callback returning bool (filter callbacks)" do
    it "uses boolean callbacks for custom matching logic" do
      lexer = Logos::Lexer(BoolCallbacks::Token, String, Logos::NoExtras, Nil).new("keep skip keep")

      result = lexer.next
      result = result.as(Logos::Result(BoolCallbacks::Token, Nil))
      result.unwrap.should eq(BoolCallbacks::Token::Word)
      lexer.slice.should eq("keep")

      result = lexer.next
      result = result.as(Logos::Result(BoolCallbacks::Token, Nil))
      result.unwrap.should eq(BoolCallbacks::Token::Word)
      lexer.slice.should eq("keep")

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "callback returning Result<(), E> or Skip" do
    it "handles callbacks returning Result or Skip" do
      lexer = Logos::Lexer(FilterResultCallbacks::Token, String, Logos::NoExtras, FilterResultCallbacks::CustomError).new("1 0 20")

      result = lexer.next
      result = result.as(Logos::Result(FilterResultCallbacks::Token, FilterResultCallbacks::CustomError))
      result.unwrap.should eq(FilterResultCallbacks::Token::Number)
      lexer.slice.should eq("1")

      result = lexer.next
      result = result.as(Logos::Result(FilterResultCallbacks::Token, FilterResultCallbacks::CustomError))
      result.error?.should be_true
      result.unwrap_error.should eq(FilterResultCallbacks::CustomError.new("too big"))
    end
  end

  module LifetimeCallbacks
    Logos.define Token do
      error_type Nil

      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "[0-9]+", :Integer do |lex|
        Logos::Filter::Emit.new({lex.slice, lex.slice.to_u64})
      end

      regex "[a-z]+", :Text do |lex|
        Logos::Filter::Emit.new(lex.slice)
      end
    end
  end

  describe "callback with lifetime annotations" do
    it "supports callbacks with nested tuple and string values" do
      lexer = Logos::Lexer(LifetimeCallbacks::Token, String, Logos::NoExtras, Nil).new("123 abc")

      result = lexer.next
      result = result.as(Logos::Result(LifetimeCallbacks::Token, Nil))
      result.unwrap.should eq(LifetimeCallbacks::Token::Integer)
      lexer.callback_value_as(Tuple(String, UInt64)).should eq({"123", 123_u64})

      result = lexer.next
      result = result.as(Logos::Result(LifetimeCallbacks::Token, Nil))
      result.unwrap.should eq(LifetimeCallbacks::Token::Text)
      lexer.callback_value_as(String).should eq("abc")
    end
  end

  describe "regex repetition ranges" do
    it "matches a{2,5} with exactly 5 a's" do
      lexer = Logos::Lexer(RepetitionPatterns::Token, String, Logos::NoExtras, Nil).new("aaaaa")
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(RepetitionPatterns::Token, Nil))
      result.ok?.should be_true
      result.unwrap.should eq(RepetitionPatterns::Token::TwoToFiveA)
      lexer.slice.should eq("aaaaa")
    end

    it "matches a{2,} with 6 a's" do
      lexer = Logos::Lexer(RepetitionPatterns::Token, String, Logos::NoExtras, Nil).new("aaaaaa")
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(RepetitionPatterns::Token, Nil))
      result.ok?.should be_true
      result.unwrap.should eq(RepetitionPatterns::Token::TwoOrMoreA)
      lexer.slice.should eq("aaaaaa")
    end

    it "matches a{0,3} with 1 a" do
      lexer = Logos::Lexer(RepetitionPatterns::Token, String, Logos::NoExtras, Nil).new("a")
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(RepetitionPatterns::Token, Nil))
      result.ok?.should be_true
      result.unwrap.should eq(RepetitionPatterns::Token::UpToThreeA)
      lexer.slice.should eq("a")
    end
  end
end
