require "../spec_helper"

module Logos::Spec::Diagnostics
  Logos.define PriorityConflictToken do
    token "a", :LiteralA, priority: 10
    regex "[a]", :RegexA, priority: 10
  end

  @[Logos::Subpattern("example", "(a|)+")]
  @[Logos::Regex("(?&example)", variant: :Subpattern)]
  enum EmptySubpatternToken
    Subpattern
  end

  logos_derive(EmptySubpatternToken)

  Logos.define Utf8InvalidRegexToken do
    regex "\xFF", :Invalid
  end

  @[Logos::Regex("\xFF", variant: :Invalid)]
  enum Utf8InvalidRegexAnnotatedToken
    Invalid
  end

  logos_derive(Utf8InvalidRegexAnnotatedToken)
end

describe "logos diagnostics" do
  it "rejects ambiguous same-priority overlaps" do
    lexer = Logos::Spec::Diagnostics::PriorityConflictToken.lexer("a")
    expect_raises(Exception, /can match simultaneously/) do
      lexer.next
    end
  end

  it "rejects empty-matching annotation subpatterns" do
    lexer = Logos::Spec::Diagnostics::EmptySubpatternToken.lexer("a")
    expect_raises(Exception, /can match the empty string/) do
      lexer.next
    end
  end

  it "rejects define-API patterns that can match invalid UTF-8 in utf8 mode" do
    lexer = Logos::Spec::Diagnostics::Utf8InvalidRegexToken.lexer("x")
    expect_raises(Exception, /UTF-8.*byte-oriented/) do
      lexer.next
    end
  end

  it "rejects annotation API patterns that can match invalid UTF-8 in utf8 mode" do
    lexer = Logos::Spec::Diagnostics::Utf8InvalidRegexAnnotatedToken.lexer("x")
    expect_raises(Exception, /UTF-8.*byte-oriented/) do
      lexer.next
    end
  end
end
