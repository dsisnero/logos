require "../spec_helper"
require "regex-automata"

module Logos::Spec::LexerModes
  Logos.define Outer do
    token "\"", :StartString
    regex "\\p{White_Space}", :WhiteSpace
  end

  Logos.define Inner do
    regex "[^\\x22]+", :Text
    token "\\n", :EscapedNewline
    regex "\\\\u\\{[^}]*\\}", :EscapedCodepoint
    regex "\\\\[0-7]{1,3}", :EscapedOctal
    token "\\\"", :EscapedQuote
    token "\"", :EndString
  end

  describe "lexer morphing (logos-morph)" do
    it "switches from outer lexer to inner lexer for string parsing" do
      source = %q("Hello World")
      outer = Logos::Lexer(Outer, String, Logos::NoExtras, Nil).new(source)

      result = outer.next
      result = result.as(Logos::Result(Outer, Nil))
      result.unwrap.should eq(Outer::StartString)

      inner = outer.morph(Inner)
      result = inner.next
      result = result.as(Logos::Result(Inner, Nil))
      result.unwrap.should eq(Inner::Text)
      result = inner.next
      result = result.as(Logos::Result(Inner, Nil))
      result.unwrap.should eq(Inner::EndString)
    end

    it "returns to outer lexer after string ends" do
      source = %q("Hello World")
      outer = Logos::Lexer(Outer, String, Logos::NoExtras, Nil).new(source)
      outer.next

      inner = outer.morph(Inner)
      loop do
        result = inner.next
        break if result.is_a?(Iterator::Stop)
        result = result.as(Logos::Result(Inner, Nil))
        if result.unwrap == Inner::EndString
          break
        end
      end

      outer = inner.morph(Outer)
      outer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end
end
