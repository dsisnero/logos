require "../spec_helper"
require "regex-automata"

module Logos::Spec::Edgecase::CrunchTest
  Logos.define Token do
    skip_regex "[ \\t\\n\\f]+", :Whitespace
    token "else", :Else
    token "exposed", :Exposed
    regex("[a-zA-Z_]+", :Ident)
  end
end

module Logos::Spec::Edgecase::MaybeTest
  Logos.define Token do
    regex("[0-9A-F][0-9A-F]a?", :Tok)
  end
end

module Logos::Spec::Edgecase::NumbersTest
  Logos.define Token do
    skip_token " ", :Space
    regex("[0-9][0-9_]*", :LiteralUnsignedNumber)
    regex("[0-9][0-9_]*\\.[0-9][0-9_]*[TGMKkmupfa]", :LiteralRealNumberDotScaleChar)
    regex("[0-9][0-9_]*\\.[0-9][0-9_]*[eE][+-]?[0-9][0-9_]*", :LiteralRealNumberDotExp)
    regex("[0-9][0-9_]*[TGMKkmupfa]", :LiteralRealNumberScaleChar)
    regex("[0-9][0-9_]*[eE][+-]?[0-9][0-9_]*", :LiteralRealNumberExp)
    regex("[0-9][0-9_]*\\.[0-9][0-9_]*", :LiteralRealNumberDot)
  end
end

describe "crunch" do
  it "matches exposed_function as Ident not Exposed" do
    lexer = Logos::Lexer(Logos::Spec::Edgecase::CrunchTest::Token, String, Logos::NoExtras, Nil).new("exposed_function")
    result = Logos::Spec::Edgecase::CrunchTest::Token.lex(lexer)
    result.should_not be_nil
    result = result.as(Logos::Result(Logos::Spec::Edgecase::CrunchTest::Token, Nil))
    result.unwrap.should eq(Logos::Spec::Edgecase::CrunchTest::Token::Ident)
    lexer.slice.should eq("exposed_function")
    lexer.span.should eq(0...16)
  end
end

describe "maybe_at_the_end" do
  it "matches F0 without optional a" do
    lexer = Logos::Lexer(Logos::Spec::Edgecase::MaybeTest::Token, String, Logos::NoExtras, Nil).new("F0")
    result = Logos::Spec::Edgecase::MaybeTest::Token.lex(lexer)
    result.should_not be_nil
    result = result.as(Logos::Result(Logos::Spec::Edgecase::MaybeTest::Token, Nil))
    result.unwrap.should eq(Logos::Spec::Edgecase::MaybeTest::Token::Tok)
    lexer.slice.should eq("F0")
    lexer.span.should eq(0...2)
  end

  it "matches F0a with optional a" do
    lexer = Logos::Lexer(Logos::Spec::Edgecase::MaybeTest::Token, String, Logos::NoExtras, Nil).new("F0a")
    result = Logos::Spec::Edgecase::MaybeTest::Token.lex(lexer)
    result.should_not be_nil
    result = result.as(Logos::Result(Logos::Spec::Edgecase::MaybeTest::Token, Nil))
    result.unwrap.should eq(Logos::Spec::Edgecase::MaybeTest::Token::Tok)
    lexer.slice.should eq("F0a")
    lexer.span.should eq(0...3)
  end
end

describe "numbers" do
  it "matches various number formats correctly" do
    source = "42.42 42 777777K 90e+8 42.42m 77.77e-29"
    lexer = Logos::Lexer(Logos::Spec::Edgecase::NumbersTest::Token, String, Logos::NoExtras, Nil).new(source)

    # Expected tokens in order
    expected = [
      {Logos::Spec::Edgecase::NumbersTest::Token::LiteralRealNumberDot, "42.42", 0...5},
      {Logos::Spec::Edgecase::NumbersTest::Token::LiteralUnsignedNumber, "42", 6...8},
      {Logos::Spec::Edgecase::NumbersTest::Token::LiteralRealNumberScaleChar, "777777K", 9...16},
      {Logos::Spec::Edgecase::NumbersTest::Token::LiteralRealNumberExp, "90e+8", 17...22},
      {Logos::Spec::Edgecase::NumbersTest::Token::LiteralRealNumberDotScaleChar, "42.42m", 23...29},
      {Logos::Spec::Edgecase::NumbersTest::Token::LiteralRealNumberDotExp, "77.77e-29", 30...39},
    ]

    expected.each do |expected_token, expected_slice, expected_range|
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(Logos::Spec::Edgecase::NumbersTest::Token, Nil))
      result.unwrap.should eq(expected_token)
      lexer.slice.should eq(expected_slice)
      lexer.span.should eq(expected_range)
    end

    lexer.next.should eq(Iterator::Stop::INSTANCE)
  end
end

describe "benches idents" do
  it "matches identifiers" do
    identifiers = "It was the year when they finally immanentized the Eschaton"
    lexer = Logos::Lexer(Logos::Spec::Edgecase::BenchesTest::Token, String, Logos::NoExtras, Nil).new(identifiers)

    expected = [
      {Logos::Spec::Edgecase::BenchesTest::Token::Identifier, "It", 0...2},
      {Logos::Spec::Edgecase::BenchesTest::Token::Identifier, "was", 3...6},
      {Logos::Spec::Edgecase::BenchesTest::Token::Identifier, "the", 7...10},
      {Logos::Spec::Edgecase::BenchesTest::Token::Identifier, "year", 11...15},
      {Logos::Spec::Edgecase::BenchesTest::Token::Identifier, "when", 16...20},
      {Logos::Spec::Edgecase::BenchesTest::Token::Identifier, "they", 21...25},
      {Logos::Spec::Edgecase::BenchesTest::Token::Identifier, "finally", 26...33},
      {Logos::Spec::Edgecase::BenchesTest::Token::Identifier, "immanentized", 34...46},
      {Logos::Spec::Edgecase::BenchesTest::Token::Identifier, "the", 47...50},
      {Logos::Spec::Edgecase::BenchesTest::Token::Identifier, "Eschaton", 51...59},
    ]

    expected.each do |expected_token, expected_slice, expected_range|
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(Logos::Spec::Edgecase::BenchesTest::Token, Nil))
      result.unwrap.should eq(expected_token)
      lexer.slice.should eq(expected_slice)
      lexer.span.should eq(expected_range)
    end

    lexer.next.should eq(Iterator::Stop::INSTANCE)
  end
end

describe "benches keywords and punctuators" do
  it "matches keywords and punctuators" do
    source = "foobar(protected primitive private instanceof in) { + ++ = == === => }"
    lexer = Logos::Lexer(Logos::Spec::Edgecase::BenchesTest::Token, String, Logos::NoExtras, Nil).new(source)

    expected = [
      {Logos::Spec::Edgecase::BenchesTest::Token::Identifier, "foobar", 0...6},
      {Logos::Spec::Edgecase::BenchesTest::Token::ParenOpen, "(", 6...7},
      {Logos::Spec::Edgecase::BenchesTest::Token::Protected, "protected", 7...16},
      {Logos::Spec::Edgecase::BenchesTest::Token::Primitive, "primitive", 17...26},
      {Logos::Spec::Edgecase::BenchesTest::Token::Private, "private", 27...34},
      {Logos::Spec::Edgecase::BenchesTest::Token::Instanceof, "instanceof", 35...45},
      {Logos::Spec::Edgecase::BenchesTest::Token::In, "in", 46...48},
      {Logos::Spec::Edgecase::BenchesTest::Token::ParenClose, ")", 48...49},
      {Logos::Spec::Edgecase::BenchesTest::Token::BraceOpen, "{", 50...51},
      {Logos::Spec::Edgecase::BenchesTest::Token::OpAddition, "+", 52...53},
      {Logos::Spec::Edgecase::BenchesTest::Token::OpIncrement, "++", 54...56},
      {Logos::Spec::Edgecase::BenchesTest::Token::OpAssign, "=", 57...58},
      {Logos::Spec::Edgecase::BenchesTest::Token::OpEquality, "==", 59...61},
      {Logos::Spec::Edgecase::BenchesTest::Token::OpStrictEquality, "===", 62...65},
      {Logos::Spec::Edgecase::BenchesTest::Token::FatArrow, "=>", 66...68},
      {Logos::Spec::Edgecase::BenchesTest::Token::BraceClose, "}", 69...70},
    ]

    expected.each do |expected_token, expected_slice, expected_range|
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(Logos::Spec::Edgecase::BenchesTest::Token, Nil))
      result.unwrap.should eq(expected_token)
      lexer.slice.should eq(expected_slice)
      lexer.span.should eq(expected_range)
    end

    lexer.next.should eq(Iterator::Stop::INSTANCE)
  end
end

describe "benches strings" do
  pending "matches strings with escapes" do
    strings = %q("tree" "to" "a" "graph" "that can" "more adequately represent" "loops and arbitrary state jumps" "with\"\"\"out" "the\n\n\n\n\n" "expl\"\"\"osive" "nature\"""of trying to build up all possible permutations in a tree.")
    lexer = Logos::Lexer(Logos::Spec::Edgecase::BenchesTest::Token, String, Logos::NoExtras, Nil).new(strings)

    expected = [
      {Logos::Spec::Edgecase::BenchesTest::Token::String, %q("tree"), 0...6},
      {Logos::Spec::Edgecase::BenchesTest::Token::String, %q("to"), 7...11},
      {Logos::Spec::Edgecase::BenchesTest::Token::String, %q("a"), 12...15},
      {Logos::Spec::Edgecase::BenchesTest::Token::String, %q("graph"), 16...23},
      {Logos::Spec::Edgecase::BenchesTest::Token::String, %q("that can"), 24...34},
      {Logos::Spec::Edgecase::BenchesTest::Token::String, %q("more adequately represent"), 35...62},
      {Logos::Spec::Edgecase::BenchesTest::Token::String, %q("loops and arbitrary state jumps"), 63...96},
      {Logos::Spec::Edgecase::BenchesTest::Token::String, %q("with\"\"\"out"), 97...112},
      {Logos::Spec::Edgecase::BenchesTest::Token::String, %q("the\n\n\n\n\n"), 113...128},
      {Logos::Spec::Edgecase::BenchesTest::Token::String, %q("expl\"\"\"osive"), 129...146},
      {Logos::Spec::Edgecase::BenchesTest::Token::String, %q("nature\""), 147...157},
      {Logos::Spec::Edgecase::BenchesTest::Token::String, %q("of trying to build up all possible permutations in a tree."), 157...217},
    ]

    expected.each do |expected_token, expected_slice, expected_range|
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(Logos::Spec::Edgecase::BenchesTest::Token, Nil))
      result.unwrap.should eq(expected_token)
      lexer.slice.should eq(expected_slice)
      lexer.span.should eq(expected_range)
    end

    lexer.next.should eq(Iterator::Stop::INSTANCE)
  end
end

module Logos::Spec::Edgecase::BenchesTest
  Logos.define Token do
    skip_regex "[ \\t\\n\\f]+", :Whitespace
    regex("[a-zA-Z_$][a-zA-Z0-9_$]*", :Identifier)
    regex(%q("([^"\\]|\\t|\\u|\\n|\\")*"), :String)
    token "private", :Private
    token "primitive", :Primitive
    token "protected", :Protected
    token "in", :In
    token "instanceof", :Instanceof
    token ".", :Accessor
    token "...", :Ellipsis
    token "(", :ParenOpen
    token ")", :ParenClose
    token "{", :BraceOpen
    token "}", :BraceClose
    token "+", :OpAddition
    token "++", :OpIncrement
    token "=", :OpAssign
    token "==", :OpEquality
    token "===", :OpStrictEquality
    token "=>", :FatArrow
  end
end
