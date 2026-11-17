require "../spec_helper"

module Logos::Spec::Crate
  module Some
    module Path
      alias LexerLibrary = ::Logos
    end
  end

  @[Some::Path::LexerLibrary::Options(skip: "[ \\t\\n\\f]+")]
  @[Some::Path::LexerLibrary::Regex(:LiteralInteger, "-?[0-9]+")]
  @[Some::Path::LexerLibrary::Token(:SingleQuote, "'")]
  enum Token
    LiteralInteger
    SingleQuote
  end

  logos_derive(Token)

  describe "qualified Logos annotations" do
    it "lexes the exact upstream quote and integer stream" do
      lexer = Token.lexer("' -1'2  '")
      stream = lexer.spanned
      [
        {Token::SingleQuote, "'", 0...1},
        {Token::LiteralInteger, "-1", 2...4},
        {Token::SingleQuote, "'", 4...5},
        {Token::LiteralInteger, "2", 5...6},
        {Token::SingleQuote, "'", 8...9},
      ].each do |variant, slice, span|
        stream.next.should eq({::Logos::Result(Token, Nil).ok(variant), span})
        lexer.slice.should eq(slice)
      end
      stream.next.should eq(Iterator::Stop::INSTANCE)
    end
  end
end
