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

  Logos.define Utf8InvalidTokenToken do
    token "\xFF", :Invalid
  end

  Logos.define Utf8InvalidRegexNullStarToken do
    regex "\x00.*", :Invalid, bytes: true
  end

  Logos.define Utf8InvalidRegexNullPlusToken do
    regex "\x00.+", :Invalid, bytes: true
  end

  @[Logos::Regex("\xFF", variant: :Invalid)]
  enum Utf8InvalidRegexAnnotatedToken
    Invalid
  end

  logos_derive(Utf8InvalidRegexAnnotatedToken)

  Logos.define GreedySkipWithoutConfigToken do
    skip_regex ".+", :Skip
    token "bar", :Bar
  end

  @[Logos::Subpattern("example", "(a|)+")]
  @[Logos::Regex("(?&example)+", variant: :Subpattern)]
  enum EmptySubpatternPlusToken
    Subpattern
  end

  logos_derive(EmptySubpatternPlusToken)
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

  it "rejects empty-matching annotation subpatterns with + quantifier" do
    lexer = Logos::Spec::Diagnostics::EmptySubpatternPlusToken.lexer("a")
    expect_raises(Exception, /can match the empty string/) do
      lexer.next
    end
  end

  it "rejects greedy skip patterns without allow_greedy" do
    lexer = Logos::Spec::Diagnostics::GreedySkipWithoutConfigToken.lexer("bar")
    expect_raises(Exception, /allow_greedy/) do
      lexer.next
    end
  end

  it "rejects define-API patterns that can match invalid UTF-8 in utf8 mode" do
    lexer = Logos::Spec::Diagnostics::Utf8InvalidRegexToken.lexer("x")
    expect_raises(Exception, /UTF-8.*byte-oriented/) do
      lexer.next
    end
  end

  it "rejects define-API token literals that can match invalid UTF-8 in utf8 mode" do
    lexer = Logos::Spec::Diagnostics::Utf8InvalidTokenToken.lexer("x")
    expect_raises(Exception, /UTF-8.*byte-oriented/) do
      lexer.next
    end
  end

  it "rejects define-API byte-oriented null-prefix greedy regex in utf8 mode" do
    lexer = Logos::Spec::Diagnostics::Utf8InvalidRegexNullStarToken.lexer("x")
    expect_raises(Exception, /UTF-8.*byte-oriented/) do
      lexer.next
    end
  end

  it "rejects define-API byte-oriented null-prefix plus regex in utf8 mode" do
    lexer = Logos::Spec::Diagnostics::Utf8InvalidRegexNullPlusToken.lexer("x")
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
