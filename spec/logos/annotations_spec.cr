require "../spec_helper"
require "regex-automata"

@[Logos::Options(skip: "\\s+")]
@[Logos::Subpattern("xdigit", "[0-9a-fA-F]")]
@[Logos::Token("let", variant: :Let)]
@[Logos::Regex("0x(?&xdigit)+", variant: :Hex)]
@[Logos::Regex("[0-9]+", variant: :Number)]
enum Logos::Spec::Annotations::Token
  Let
  Hex
  Number
end

logos_derive(Logos::Spec::Annotations::Token)

module Logos::Spec::Annotations
  describe "annotation-based lexer" do
    it "lexes tokens with class-level options" do
      source = "let 0x1f 23"
      lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

      result = lexer.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::Let)
      lexer.slice.should eq("let")
      lexer.span.should eq(0...3)

      result = lexer.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::Hex)
      lexer.slice.should eq("0x1f")
      lexer.span.should eq(4...8)

      result = lexer.next
      result = result.as(Logos::Result(Token, Nil))
      result.unwrap.should eq(Token::Number)
      lexer.slice.should eq("23")
      lexer.span.should eq(9...11)

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end
end
