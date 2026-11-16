require "../spec_helper"
require "regex-automata"

module Logos::Spec::Clone
  class Evil
    getter id : Int32
    getter clone_calls = 0

    def initialize(@id : Int32)
    end

    def clone : self
      @clone_calls += 1
      self.class.new(@id)
    end
  end

  Logos.define Token do
    error_type Nil

    regex "[ \\t\\n\\r]+", :Whitespace do
      Logos::Skip.new
    end

    regex "evil", :Evil do |_|
      Logos::Filter::Emit.new(::Logos::Spec::Clone::Evil.new(1))
    end
  end

  describe "clone behavior with callbacks" do
    it "returns successive independent payloads without cloning the lexer" do
      results = Token.lex_all("evil evil evil")
      values = results.map(&.payload_for!(Token::Evil, Evil))

      values.map(&.id).should eq([1, 1, 1])
      values.map(&.object_id).uniq.size.should eq(3)
      values.map(&.clone_calls).should eq([0, 0, 0])
    end

    it "can advance a cloned lexer after emitting a reference payload" do
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("evil evil")

      result = lexer.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::Evil)
      value = lexer.callback_value_as(::Logos::Spec::Clone::Evil)
      value.should_not be_nil
      value = value.as(::Logos::Spec::Clone::Evil)
      value.id.should eq(1)

      cloned = lexer.clone
      result = cloned.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::Evil)
      value = cloned.callback_value_as(::Logos::Spec::Clone::Evil)
      value.should_not be_nil
      value = value.as(::Logos::Spec::Clone::Evil)
      value.id.should eq(1)

      result = lexer.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::Evil)
      value = lexer.callback_value_as(::Logos::Spec::Clone::Evil)
      value.should_not be_nil
      value = value.as(::Logos::Spec::Clone::Evil)
      value.id.should eq(1)
    end

    it "clones the lexer without cloning its last callback payload" do
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("evil")
      result = lexer.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::Evil)
      value = lexer.callback_value_as(::Logos::Spec::Clone::Evil)
      value.should_not be_nil
      value = value.as(::Logos::Spec::Clone::Evil)
      value.id.should eq(1)

      cloned = lexer.clone
      cloned.callback_value_as(Evil).should be(value)
      value.clone_calls.should eq(0)
      value.clone
      value.clone_calls.should eq(1)

      lexer.next.should eq(Iterator::Stop::INSTANCE)
      cloned.next.should eq(Iterator::Stop::INSTANCE)
    end
  end
end
