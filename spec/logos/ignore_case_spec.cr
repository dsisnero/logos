require "../spec_helper"
require "regex-automata"

module Logos::Spec::IgnoreCase
  # ignore_ascii_case tests from Rust ignore_case.rs
  module IgnoreAsciiCase
    Logos.define Token do
      error_type Nil

      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      token "lowercase", :Lowercase, ignore_ascii_case: true
      token "or", :Or, ignore_ascii_case: true
      token "uppercase", :Uppercase, ignore_ascii_case: true
    end

    Logos.define RegexToken do
      error_type Nil

      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "a", :A, ignore_ascii_case: true
      regex "bc", :BC, ignore_ascii_case: true
      regex "[de]", :DE, ignore_ascii_case: true
      regex "f+", :F, ignore_ascii_case: true
      regex "gg", :GG, ignore_ascii_case: true
      regex "[h-k]", :HK, ignore_ascii_case: true
    end

    describe "ignore_ascii_case: tokens with ignore(case)" do
      it "matches case-insensitive ASCII tokens" do
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("lOwERCaSe OR UppeRcaSE")
        result = lexer.next
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Lowercase)

        result = lexer.next
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Or)

        result = lexer.next
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Uppercase)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end

    describe "ignore_ascii_case: regex with ignore(case)" do
      it "matches case-insensitive ASCII regex patterns" do
        lexer = Logos::Lexer(RegexToken, String, Logos::NoExtras, Nil).new("A bC D fff gg H")
        result = lexer.next
        result = result.as(Logos::Result(RegexToken, Nil))
        result.unwrap.should eq(RegexToken::A)

        result = lexer.next
        result = result.as(Logos::Result(RegexToken, Nil))
        result.unwrap.should eq(RegexToken::BC)

        result = lexer.next
        result = result.as(Logos::Result(RegexToken, Nil))
        result.unwrap.should eq(RegexToken::DE)

        result = lexer.next
        result = result.as(Logos::Result(RegexToken, Nil))
        result.unwrap.should eq(RegexToken::F)

        result = lexer.next
        result = result.as(Logos::Result(RegexToken, Nil))
        result.unwrap.should eq(RegexToken::GG)

        result = lexer.next
        result = result.as(Logos::Result(RegexToken, Nil))
        result.unwrap.should eq(RegexToken::HK)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # ignore_case tests (full Unicode case folding)
  module IgnoreCase
    Logos.define Token do
      error_type Nil

      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      token "éléphant", :Elephant, ignore_case: true
      token "élève", :Eleve, ignore_case: true
      token "à", :AAccent, ignore_case: true
    end

    Logos.define RegexToken do
      error_type Nil

      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "[abcéà]+", :Letters, ignore_case: true
      regex "[0-9]+", :Numbers
      regex "ééààé", :Word, ignore_case: true
    end

    describe "ignore_case: tokens with Unicode case folding" do
      it "matches case-insensitive Unicode tokens" do
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("élÉphAnt ÉlèvE À")

        result = lexer.next
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Elephant)

        result = lexer.next
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Eleve)

        result = lexer.next
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::AAccent)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end

    describe "ignore_case: regex with Unicode case folding" do
      it "matches case-insensitive Unicode regex patterns" do
        lexer = Logos::Lexer(RegexToken, String, Logos::NoExtras, Nil).new("AbcéÀ 123 ÉÉÀÀÉ")

        result = lexer.next
        result = result.as(Logos::Result(RegexToken, Nil))
        result.unwrap.should eq(RegexToken::Letters)

        result = lexer.next
        result = result.as(Logos::Result(RegexToken, Nil))
        result.unwrap.should eq(RegexToken::Numbers)

        result = lexer.next
        result = result.as(Logos::Result(RegexToken, Nil))
        result.unwrap.should eq(RegexToken::Word)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end
end
