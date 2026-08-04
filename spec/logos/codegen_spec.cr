require "../spec_helper"

module Logos::Spec::Codegen
  Logos.define Token do
    subpattern :digit, "[0-9]"
    token "+", :Plus
    regex "(?&digit)+", :Integer
  end
end

describe "source pre-generation integration" do
  it "does not execute a generator from the Logos.define macro" do
    Logos::Spec::Codegen::Token.precompiled_dfa?.should be_false

    lexer = Logos::Spec::Codegen::Token.lexer("+123")
    lexer.next.as(Logos::Result(Logos::Spec::Codegen::Token, Nil)).unwrap.should eq(Logos::Spec::Codegen::Token::Plus)
    lexer.next.as(Logos::Result(Logos::Spec::Codegen::Token, Nil)).unwrap.should eq(Logos::Spec::Codegen::Token::Integer)
  end
end
