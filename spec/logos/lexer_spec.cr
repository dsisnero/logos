require "../spec_helper"

module Logos::Spec
  # Dummy token enum for testing Lexer
  enum DummyToken
    A
    B
    Error
  end

  # Define class method lex
  def DummyToken.lex(lexer : Logos::Lexer(self, ::String, NoExtras, Nil)) : Logos::Result(self, Nil)?
    nil
  end
end

describe Logos::Lexer do
  it "can be instantiated with a token type" do
    source = "test"
    lexer = Logos::Lexer(Logos::Spec::DummyToken, String, Logos::NoExtras, Nil).new(source)
    lexer.should be_a(Logos::Lexer(Logos::Spec::DummyToken, String, Logos::NoExtras, Nil))
  end

  it "can iterate over tokens" do
    lexer = Logos::Lexer(Logos::Spec::DummyToken, String, Logos::NoExtras, Nil).new("")
    lexer.next.should eq(Iterator::Stop::INSTANCE)
  end
end
