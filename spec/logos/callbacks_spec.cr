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

  pending "callback returning bool (filter callbacks)" do
    it "uses boolean callbacks for custom matching logic" do
      # Requires boolean filter callbacks (logos-9me)
      # Callback returns true/false to indicate match success
      # Used for raw string parsing, Lua brackets, etc.
    end
  end

  pending "callback returning Result<(), E> or Skip" do
    it "handles callbacks returning Result or Skip" do
      # Requires support for FilterResult::Error and FilterResult::Skip
      # Callback can return error or skip token
    end
  end

  pending "callback with lifetime annotations" do
    it "supports callbacks with nested lifetimes" do
      # Requires proper lifetime handling in callbacks
      # Token::Integer((&'a str, u64)) with nested tuple
      # Token::Text(Cow<'a, str>) with Cow type
    end
  end
end
