require "../spec_helper"
require "regex-automata"

module Logos::Spec::Clone
  class Evil
    getter id : Int32

    def initialize(@id : Int32)
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
    it "handles cloning without use-after-free" do
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

    it "handles cloning without memory leaks" do
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("evil")
      result = lexer.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::Evil)
      value = lexer.callback_value_as(::Logos::Spec::Clone::Evil)
      value.should_not be_nil
      value = value.as(::Logos::Spec::Clone::Evil)
      value.id.should eq(1)

      cloned = lexer.clone
      value = cloned.callback_value_as(::Logos::Spec::Clone::Evil)
      value.should_not be_nil
      value = value.as(::Logos::Spec::Clone::Evil)
      value.id.should eq(1)

      lexer.next.should eq(Iterator::Stop::INSTANCE)
      cloned.next.should eq(Iterator::Stop::INSTANCE)
    end
  end
end
