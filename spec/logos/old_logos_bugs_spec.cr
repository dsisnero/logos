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

  # issue_180 pending due to regex complexity

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

    pending "issue_246: triple quotes" do
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

  # issue_202 pending: Unicode range regex not supported
end
