require "../spec_helper"
require "regex-automata"

module Logos::Spec::LexerModes
  Logos.define Outer do
    token "\"", :StartString
    regex "\\p{White_Space}", :WhiteSpace
  end

  Logos.define Inner do
    regex "[^\\\\\"]+", :Text
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

    it "parses string with escaped codepoint, octal, and newline (upstream parity)" do
      source = %q("Hello W\u{00f4}rld\n")
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
      result.unwrap.should eq(Inner::EscapedCodepoint)
      inner.slice.should eq("\\u{00f4}")

      result = inner.next
      result = result.as(Logos::Result(Inner, Nil))
      result.unwrap.should eq(Inner::Text)

      result = inner.next
      result = result.as(Logos::Result(Inner, Nil))
      result.unwrap.should eq(Inner::EscapedNewline)
      inner.slice.should eq("\\n")

      result = inner.next
      result = result.as(Logos::Result(Inner, Nil))
      result.unwrap.should eq(Inner::EndString)
      inner.slice.should eq("\"")

      outer = inner.morph(Outer)
      outer.next.should eq(Iterator::Stop::INSTANCE)
    end

    it "iterates modes with octal, codepoint, and newline escapes (upstream iterating_modes)" do
      source = %q("Hello W\u{00f4}\162ld\n")
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
      result.unwrap.should eq(Inner::EscapedCodepoint)

      result = inner.next
      result = result.as(Logos::Result(Inner, Nil))
      result.unwrap.should eq(Inner::EscapedOctal)

      result = inner.next
      result = result.as(Logos::Result(Inner, Nil))
      result.unwrap.should eq(Inner::Text)

      result = inner.next
      result = result.as(Logos::Result(Inner, Nil))
      result.unwrap.should eq(Inner::EscapedNewline)

      result = inner.next
      result = result.as(Logos::Result(Inner, Nil))
      result.unwrap.should eq(Inner::EndString)

      outer = inner.morph(Outer)
      outer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end
end
