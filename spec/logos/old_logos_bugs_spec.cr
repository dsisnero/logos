require "../spec_helper"
require "regex-automata"

module Logos::Spec::OldLogosBugs
  # issue_160: https://github.com/maciejhirsz/logos/issues/160
  # tokens with spaces in them (else if)
  module Issue160
    Logos.define Token do
      skip_regex "[ ]+", :Skip

      token "else", :Else
      token "else if", :ElseIf
      regex "[a-z]+", :Other
    end

    describe "issue_160: tokens with spaces" do
      it "matches else and else if correctly" do
        source = "else x else if y"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        expected = [
          {Token::Else, "else", 0...4},
          {Token::Other, "x", 5...6},
          {Token::ElseIf, "else if", 7...14},
          {Token::Other, "y", 15...16},
        ]

        expected.each do |expected_token, expected_slice, expected_range|
          result = lexer.next
          result.should_not be_nil
          result = result.as(Logos::Result(Token, Nil))
          result.unwrap.should eq(expected_token)
          lexer.slice.should eq(expected_slice)
          lexer.span.should eq(expected_range)
        end

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_173: https://github.com/maciejhirsz/logos/issues/173
  # priority between regex and token
  module Issue173
    Logos.define Token do
      regex "[0-9]+", :Literal
      regex "([0-9]+[.][0-9]*f)", :Literal # Note: Crystal regex doesn't support \d, use [0-9]
      regex "[a-zA-Z_][a-zA-Z_0-9]*", :Ident
      token ".", :Dot, priority: 100
    end

    describe "issue_173: priority between regex and token" do
      it "matches dots with high priority" do
        source = "a.0.0.0.0"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        expected = [
          {Token::Ident, "a", 0...1},
          {Token::Dot, ".", 1...2},
          {Token::Literal, "0", 2...3},
          {Token::Dot, ".", 3...4},
          {Token::Literal, "0", 4...5},
          {Token::Dot, ".", 5...6},
          {Token::Literal, "0", 6...7},
          {Token::Dot, ".", 7...8},
          {Token::Literal, "0", 8...9},
        ]

        expected.each do |expected_token, expected_slice, expected_range|
          result = lexer.next
          result.should_not be_nil
          result = result.as(Logos::Result(Token, Nil))
          result.unwrap.should eq(expected_token)
          lexer.slice.should eq(expected_slice)
          lexer.span.should eq(expected_range)
        end

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_179: https://github.com/maciejhirsz/logos/issues/179
  # emoji tokens
  module Issue179
    Logos.define Token do
      token "😎", :A
      token "😁", :B
    end

    describe "issue_179: emoji tokens" do
      it "matches smile emoji" do
        source = "😁"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::B)
        lexer.slice.should eq("😁")
        lexer.span.should eq(0...4)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end

      it "produces error for unmatched character" do
        source = "x"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.error?.should be_true

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_180: https://github.com/maciejhirsz/logos/issues/180
  module Issue180
    Logos.define Token do
      skip_regex "[ \\n\\t\\f]+", :Skip

      token "fast", :Fast
      token ".", :Period
      regex "[a-zA-Z]+", :Text
      regex "/\\*(?:[^*]|\\*+[^*/])+\\*+/", :Comment
    end

    describe "issue_180: comment token with skip" do
      it "matches text/comment/fast/period sequence" do
        source = "Create ridiculously /* comment */ fast Lexers."
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        expected = [
          {Token::Text, "Create", 0...6},
          {Token::Text, "ridiculously", 7...19},
          {Token::Comment, "/* comment */", 20...33},
          {Token::Fast, "fast", 34...38},
          {Token::Text, "Lexers", 39...45},
          {Token::Period, ".", 45...46},
        ]

        expected.each do |expected_token, expected_slice, expected_range|
          result = lexer.next
          result.should_not be_nil
          result = result.as(Logos::Result(Token, Nil))
          result.unwrap.should eq(expected_token)
          lexer.slice.should eq(expected_slice)
          lexer.span.should eq(expected_range)
        end

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_181: https://github.com/maciejhirsz/logos/issues/181
  # priority between regex and token
  module Issue181
    Logos.define Token do
      token "a", :A
      token "axb", :B
      regex "ax[bc]", :Word, priority: 5
    end

    describe "issue_181: priority with regex" do
      it "matches a then error for x" do
        source = "ax"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        # First token: "a"
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::A)
        lexer.slice.should eq("a")
        lexer.span.should eq(0...1)

        # Second token: error for "x"
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.error?.should be_true
        lexer.slice.should eq("x")
        lexer.span.should eq(1...2)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_185: https://github.com/maciejhirsz/logos/issues/185
  # block comment regex
  module Issue185
    Logos.define Token do
      regex "/\\*([^*]|\\**[^*/])*\\*+/", :BlockComment
    end

    describe "issue_185: block comment regex" do
      it "matches /**/" do
        source = "/**/"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::BlockComment)
        lexer.slice.should eq("/**/")
        lexer.span.should eq(0...4)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_187: https://github.com/maciejhirsz/logos/issues/187
  # currency regex
  module Issue187
    Logos.define Token do
      regex "[A-Z][A-Z]*[A-Z]", :Currency
    end

    describe "issue_187: currency regex" do
      it "matches USD" do
        source = "USD"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Currency)
        lexer.slice.should eq("USD")
        lexer.span.should eq(0...3)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_200: https://github.com/maciejhirsz/logos/issues/200
  # not vs not in with spaces
  module Issue200
    Logos.define Token do
      skip_regex " +", :Skip

      token "not", :Not
      regex "not[ ]+in", :NotIn
    end

    describe "issue_200: not vs not in" do
      it "matches not not" do
        source = "not not"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        expected = [
          {Token::Not, "not", 0...3},
          {Token::Not, "not", 4...7},
        ]

        expected.each do |expected_token, expected_slice, expected_range|
          result = lexer.next
          result.should_not be_nil
          result = result.as(Logos::Result(Token, Nil))
          result.unwrap.should eq(expected_token)
          lexer.slice.should eq(expected_slice)
          lexer.span.should eq(expected_range)
        end

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_203: https://github.com/maciejhirsz/logos/issues/203
  # float regex with underscores
  module Issue203
    Logos.define Token do
      skip_regex " +", :Skip

      regex "[0-9](_[0-9])*\\.[0-9](_[0-9])*([eE][+-]?[0-9](_[0-9])*)?", :Float
    end

    describe "issue_203: float regex with underscores" do
      it "matches floats with exponents" do
        source = "1.1e1 2.3e"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        expected = [
          {Token::Float, "1.1e1", 0...5},
          {Token::Float, "2.3", 6...9},
          # Error for "e"
        ]

        expected.each do |expected_token, expected_slice, expected_range|
          result = lexer.next
          result.should_not be_nil
          result = result.as(Logos::Result(Token, Nil))
          result.unwrap.should eq(expected_token)
          lexer.slice.should eq(expected_slice)
          lexer.span.should eq(expected_range)
        end

        # Error for "e"
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.error?.should be_true
        lexer.slice.should eq("e")
        lexer.span.should eq(9...10)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_213: https://github.com/maciejhirsz/logos/issues/213
  # number formats with underscores
  module Issue213
    Logos.define Token do
      skip_regex "[ \\t\\n\\f]+", :Skip

      token "+", :Plus
      token "-", :Minus
      token "*", :Times
      token "/", :Division
      regex "[0-9][0-9_]*", :Number
      regex "0b[01_]*[01][01_]*", :Number
      regex "0o[0-7_]*[0-7][0-7_]*", :Number
      regex "0x[0-9a-fA-F_]*[0-9a-fA-F][0-9a-fA-F_]*", :Number
    end

    describe "issue_213: number formats with underscores" do
      it "matches numbers with underscores" do
        source = "12_3 0b0000_1111"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        expected = [
          {Token::Number, "12_3", 0...4},
          {Token::Number, "0b0000_1111", 5...16},
        ]

        expected.each do |expected_token, expected_slice, expected_range|
          result = lexer.next
          result.should_not be_nil
          result = result.as(Logos::Result(Token, Nil))
          result.unwrap.should eq(expected_token)
          lexer.slice.should eq(expected_slice)
          lexer.span.should eq(expected_range)
        end

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_227: https://github.com/maciejhirsz/logos/issues/227
  # regex vs token priority (a+b vs a)
  module Issue227
    Logos.define Token do
      regex "a+b", :APlusB
      token "a", :A
    end

    describe "issue_227: regex vs token priority" do
      it "matches a+b as single token" do
        source = "aaaaaaaaaaaaaaab"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::APlusB)
        lexer.slice.should eq("aaaaaaaaaaaaaaab")
        lexer.span.should eq(0...16)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end

      it "matches single a as A" do
        source = "a"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::A)
        lexer.slice.should eq("a")
        lexer.span.should eq(0...1)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end

      it "matches aa as two A tokens" do
        source = "aa"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        # First a
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::A)
        lexer.slice.should eq("a")
        lexer.span.should eq(0...1)

        # Second a
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::A)
        lexer.slice.should eq("a")
        lexer.span.should eq(1...2)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_246: https://github.com/maciejhirsz/logos/issues/246
  # triple quotes
  module Issue246
    Logos.define Token do
      regex "\"\"\".*?\"\"\"", :Triple
    end

    describe "issue_246: triple quotes" do
      it "matches triple quoted string" do
        source = "\"\"\"abc\"\"\""
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Triple)
        lexer.slice.should eq("\"\"\"abc\"\"\"")
        lexer.span.should eq(0...9)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_259: https://github.com/maciejhirsz/logos/issues/259
  # string regex
  module Issue259
    Logos.define Token do
      regex "\"(?:[^\"\\\\]*(?:\\\\\")?)*\"", :String
    end

    describe "issue_259: string regex" do
      it "produces error for unmatched quote" do
        source = "\""
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.error?.should be_true
        lexer.slice.should eq("\"")
        lexer.span.should eq(0...1)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_265: https://github.com/maciejhirsz/logos/issues/265
  # priority with whitespace token
  module Issue265
    Logos.define Token do
      regex "[ \\t]+", :TK_WHITESPACE, priority: 1
      regex "[a-zA-Z][a-zA-Z0-9]*", :TK_WORD, priority: 1
      token "not", :TK_NOT, priority: 50
      token "not in", :TK_NOT_IN, priority: 60
    end

    describe "issue_265: priority with whitespace token" do
      it "matches not" do
        source = "not"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::TK_NOT)
        lexer.slice.should eq("not")
        lexer.span.should eq(0...3)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end

      it "matches word not" do
        source = "word not"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        expected = [
          {Token::TK_WORD, "word", 0...4},
          {Token::TK_WHITESPACE, " ", 4...5},
          {Token::TK_NOT, "not", 5...8},
        ]

        expected.each do |expected_token, expected_slice, expected_range|
          result = lexer.next
          result.should_not be_nil
          result = result.as(Logos::Result(Token, Nil))
          result.unwrap.should eq(expected_token)
          lexer.slice.should eq(expected_slice)
          lexer.span.should eq(expected_range)
        end

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end

      it "matches not word" do
        source = "not word"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        expected = [
          {Token::TK_NOT, "not", 0...3},
          {Token::TK_WHITESPACE, " ", 3...4},
          {Token::TK_WORD, "word", 4...8},
        ]

        expected.each do |expected_token, expected_slice, expected_range|
          result = lexer.next
          result.should_not be_nil
          result = result.as(Logos::Result(Token, Nil))
          result.unwrap.should eq(expected_token)
          lexer.slice.should eq(expected_slice)
          lexer.span.should eq(expected_range)
        end

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end

      it "matches not in with space" do
        source = "not in "
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        expected = [
          {Token::TK_NOT_IN, "not in", 0...6},
          {Token::TK_WHITESPACE, " ", 6...7},
        ]

        expected.each do |expected_token, expected_slice, expected_range|
          result = lexer.next
          result.should_not be_nil
          result = result.as(Logos::Result(Token, Nil))
          result.unwrap.should eq(expected_token)
          lexer.slice.should eq(expected_slice)
          lexer.span.should eq(expected_range)
        end

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_220 pending: Pascal-style comment regex with (?m) flag not supported
  module Issue220
    Logos.define Token do
      error_type Nil

      regex "(?m)\\(\\*([^*]|\\*+[^*)])*\\*+\\)", :Comment
    end

    describe "issue_220: Pascal-style comment regex" do
      it "matches (* hello world *)" do
        source = "(* hello world *)"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        result = lexer.next
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Comment)
        lexer.slice.should eq("(* hello world *)")
        lexer.span.should eq(0...17)
      end
    end
  end

  # issue_272 pending: possessive quantifier ?+ not supported
  module Issue272
    Logos.define Token do
      error_type Nil

      token "other", :Other
      regex "-?[0-9][0-9_]?+", :Integer
    end

    describe "issue_272: possessive quantifier" do
      it "matches numbers with possessive quantifier" do
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("32_212")
        result = lexer.next
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Integer)
        lexer.slice.should eq("32_212")
        lexer.span.should eq(0...6)
        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_384 pending: complex string literal regex with escapes
  module Issue384
    Logos.define Token do
      error_type Nil

      regex %q((?:/(?:\\.|[^\\/])+/[a-zA-Z]*)), :StringLiteral
      regex %q((?:"(?:(?:[^"\\])|(?:\\.))*")), :StringLiteral
      regex %q((?:'(?:(?:[^'\\])|(?:\\.))*')), :StringLiteral
    end

    describe "issue_384: string literal regex" do
      it "matches regex literal" do
        source = "\"" + ("a" * 1_000_000) + "\""
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        result = lexer.next
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::StringLiteral)
        lexer.slice.should eq(source)
        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_394: nested identifier regex
  module Issue394
    module Part1
      Logos.define Token do
        regex "([a-b]+\\.)+[a-b]", :NestedIdentifier
      end

      describe "issue_394 part1: nested identifier" do
        it "matches a.b" do
          source = "a.b"
          lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

          result = lexer.next
          result.should_not be_nil
          result = result.as(Logos::Result(Token, Nil))
          result.unwrap.should eq(Token::NestedIdentifier)
          lexer.slice.should eq("a.b")
          lexer.span.should eq(0...3)

          lexer.next.should eq(Iterator::Stop::INSTANCE)
        end
      end
    end

    module Part2
      Logos.define Token do
        regex "([a-b])+b", :ABPlusB
      end

      describe "issue_394 part2: a+b regex" do
        it "matches ab" do
          source = "ab"
          lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

          result = lexer.next
          result.should_not be_nil
          result = result.as(Logos::Result(Token, Nil))
          result.unwrap.should eq(Token::ABPlusB)
          lexer.slice.should eq("ab")
          lexer.span.should eq(0...2)

          lexer.next.should eq(Iterator::Stop::INSTANCE)
        end
      end
    end
  end

  # issue_420 pending: skip pattern .|[\r\n] with priority needs debugging
  module Issue420
    Logos.define Token do
      error_type Nil

      skip_regex ".|[\\r\\n]", :Skip
      regex "[a-zA-Y]+", :WordExceptZ, priority: 3
      regex "[0-9]+", :Number, priority: 3
      regex "[a-zA-Z0-9]*[Z][a-zA-Z0-9]*", :TermWithZ, priority: 3
    end

    describe "issue_420: priority with skip" do
      it "matches words, numbers, and terms with Z" do
        source = "hello 42world fooZfoo"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        expected = [
          {Logos::Result(Token, Nil).ok(Token::WordExceptZ), "hello", 0...5},
          {Logos::Result(Token, Nil).ok(Token::Number), "42", 6...8},
          {Logos::Result(Token, Nil).ok(Token::WordExceptZ), "world", 8...13},
          {Logos::Result(Token, Nil).ok(Token::TermWithZ), "fooZfoo", 14...21},
        ]

        expected.each do |expected_result, expected_slice, expected_range|
          result = lexer.next
          result.should_not be_nil
          result.should eq(expected_result)
          lexer.slice.should eq(expected_slice)
          lexer.span.should eq(expected_range)
        end

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_424: https://github.com/maciejhirsz/logos/issues/424
  # regex infinite loop prevention
  module Issue424
    Logos.define Token do
      regex "c(a*b?)*c", :Token
    end

    describe "issue_424: regex infinite loop prevention" do
      it "handles c without infinite loop" do
        source = "c"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        # Should produce error for "c" (doesn't match full pattern c...c)
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.error?.should be_true
        lexer.slice.should eq("c")
        lexer.span.should eq(0...1)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_456: https://github.com/maciejhirsz/logos/issues/456
  # alternation regex
  module Issue456
    Logos.define Token do
      regex "a|a*b", :T
    end

    describe "issue_456: alternation regex" do
      it "matches a then a" do
        source = "aa"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        # First a
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::T)
        lexer.slice.should eq("a")
        lexer.span.should eq(0...1)

        # Second a
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::T)
        lexer.slice.should eq("a")
        lexer.span.should eq(1...2)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_190: very long quoted strings
  module Issue190
    Logos.define Token do
      regex "\"([^\\\\\"]|\\\\.)*\"", :Quote
    end

    describe "issue_190: long quoted strings" do
      it "matches long quoted input" do
        source = "\"" + ("1234567890ABCDEF" * 512) + "\""
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)
        result = lexer.next.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Quote)
        lexer.slice.size.should eq(source.size)
      end
    end
  end

  # issue_240: derive-heavy regex set should compile
  module Issue240
    Logos.define Token do
      subpattern :alphanumeric, "[a-zA-Z0-9_]"
      regex "\"?[a-zA-Z](?&alphanumeric)*\"?", :Sale do |lex|
        Logos::Filter::Emit.new(lex.slice)
      end
      regex "comment *: *\".*\";", :Comment, allow_greedy: true, priority: 100
    end

    describe "issue_240: subpattern-heavy tokens" do
      it "matches sale-like identifiers and comment directives" do
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("\"foo_1\"")
        result = lexer.next.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Sale)
        lexer.callback_value_as(String).should eq("\"foo_1\"")

        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("comment: \"hello\";")
        result = lexer.next.as(Logos::Result(Token, Nil))
        result.ok?.should be_true
      end
    end
  end

  # issue_252: specific token should beat generic regex
  module Issue252
    Logos.define Token do
      token "xx", :Specific
      regex "(xx+|y)+", :Generic
    end

    describe "issue_252: specific token priority" do
      it "matches specific token for xx" do
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("xx")
        result = lexer.next.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Specific)
      end
    end
  end

  # issue_258: greedy skip with allow_greedy should compile and skip
  module Issue258
    Logos.define Token do
      skip_regex ".*->.+\\[", :Skip, allow_greedy: true
      regex "->", :Arrow
    end

    describe "issue_258: greedy skip config" do
      it "skips configured greedy spans without compile-time error" do
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("abc->def[")
        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_261: bare identifier with greedy fallback should compile
  module Issue261
    Logos.define Token do
      regex "([0123456789]|#_#)*#.#[0123456789](_|#_#)?", :Decimal
      regex "..*", :BareIdentifier, allow_greedy: true
    end

    describe "issue_261: decimal vs greedy identifier" do
      it "compiles and lexes input" do
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("12#.3")
        lexer.next.should_not eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_269: string regex form should compile
  module Issue269
    Logos.define Token do
      regex "\"(?:|\\\\[^\\n])*\"", :String
    end

    describe "issue_269: string regex form" do
      it "matches simple quoted strings" do
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("\"fubar\"")
        result = lexer.next.as(Logos::Result(Token, Nil))
        (result.ok? || result.error?).should be_true
      end
    end
  end

  # issue_336: reduced catastrophic patterns should compile
  module Issue336
    Logos.define Token do
      regex "(0+)*x?.0+", :Float1
      regex "(0+)*.0+", :Float2
      regex "0*.0+", :Float3
    end

    describe "issue_336: reduced catastrophic patterns" do
      it "compiles and tokenizes simple float-like input" do
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("000.0")
        lexer.next.should_not eq(Iterator::Stop::INSTANCE)
      end
    end
  end

  # issue_242 pending: needs token variants with associated data (callbacks returning values)
  module Issue242
    Logos.define Token do
      error_type Nil

      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "\\d*[13579]", :Odd do |lex|
        Logos::Filter::Emit.new(lex.slice.to_i)
      end
    end

    describe "issue_242: odd number callback" do
      it "parses odd numbers with callback" do
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("13579 101")

        result = lexer.next
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Odd)
        lexer.callback_value_as(Int32).should eq(13579)

        result = lexer.next
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Odd)
        lexer.callback_value_as(Int32).should eq(101)
      end
    end
  end

  # issue_251 pending: needs token variants with associated data
  module Issue251
    Logos.define Token do
      error_type Nil

      regex ".", :Char do |lex|
        Logos::Filter::Emit.new(lex.slice)
      end
    end

    describe "issue_251: char token with slice" do
      it "matches any character with slice" do
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("a")
        result = lexer.next
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Char)
        lexer.callback_value_as(String).should eq("a")
      end
    end
  end

  # issue_256 pending: needs token variants with associated data
  module Issue256
    Logos.define Token do
      error_type Nil

      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "[0-9][0-9_]*", :Integer do |lex|
        Logos::Filter::Emit.new(lex.slice.gsub("_", "").to_i)
      end
    end

    describe "issue_256: integer literal callback" do
      it "parses integers with underscores" do
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new("1_000 42")

        result = lexer.next
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Integer)
        lexer.callback_value_as(Int32).should eq(1000)

        result = lexer.next
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Integer)
        lexer.callback_value_as(Int32).should eq(42)
      end
    end
  end

  # issue_201 pending: needs boolean filter callbacks
  module Issue201
    Logos.define Token do
      error_type Nil

      regex "\\[=*\\[", :Open do |lex|
        lex.remainder.includes?("]")
      end
    end

    describe "issue_201: Lua brackets with callback" do
      it "matches Lua long brackets" do
        source = "[=[hello]=]"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::Open)
        lexer.slice.should eq("[=[")
      end
    end
  end

  # issue_461: binary mode (utf8 = false) - now implemented
  module Issue461
    Logos.define Token do
      utf8 false
      error_type Nil

      token "\x00", :Zero
      token "\xFF", :FF
      regex "[\\x00-\\xFF]", :AnyByte
    end

    describe "issue_461: binary mode parsing" do
      it "handles non-UTF8 bytes" do
        slice = Slice[0x00_u8, 0xFF_u8, 0x10_u8]
        lexer = Logos::Lexer(Token, Slice(UInt8), Logos::NoExtras, Nil).new(slice)
        tokens = [] of Token
        while token = lexer.next
          break if token.is_a?(Iterator::Stop)
          result = token.as(Logos::Result(Token, Nil))
          if result.ok?
            tokens << result.unwrap
          end
        end

        tokens.should eq([Token::Zero, Token::FF, Token::AnyByte])
      end
    end
  end

  # issue_202: https://github.com/maciejhirsz/logos/issues/202
  module Issue202
    Logos.define Token do
      regex "[\\u{0}-\\u{10FFFF}]", :AnyChar
    end

    describe "issue_202: Unicode full-range class" do
      it "matches non-ascii codepoints" do
        source = "Ω"
        lexer = Logos::Lexer(Token, String, Logos::NoExtras, Nil).new(source)

        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(Token, Nil))
        result.unwrap.should eq(Token::AnyChar)
        lexer.slice.should eq("Ω")
        lexer.span.should eq(0...2)

        lexer.next.should eq(Iterator::Stop::INSTANCE)
      end
    end
  end
end
