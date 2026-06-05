require "./spec_helper"

describe "AST parser parity" do
  it "exposes vendored AST::Parse aliases and builder configuration" do
    Regex::Syntax::AST::Parse::Parser.should eq(Regex::Syntax::AstParser)
    Regex::Syntax::AST::Parse::ParserBuilder.should eq(Regex::Syntax::AstParserBuilder)

    parser = Regex::Syntax::AST::Parse::ParserBuilder.new
      .ignore_whitespace(true)
      .nest_limit(10)
      .octal(true)
      .empty_min_range(true)
      .build

    parser.should be_a(Regex::Syntax::AST::Parse::Parser)

    octal = parser.parse("(?x)\\141")
    octal.kind.should be_a(Regex::Syntax::AST::Concat)
    octal_children = octal.kind.as(Regex::Syntax::AST::Concat).children
    octal_children[0].should be_a(Regex::Syntax::AST::SetFlags)
    octal_children[1].as(Regex::Syntax::AST::Literal).c.should eq('a')

    parsed = parser.parse_with_comments("(?x)a # note\n b")
    parsed.comments.map(&.comment).should eq([" note"])
    parsed.ast.kind.should be_a(Regex::Syntax::AST::Concat)

    repetition = parser.parse("a{,9}").kind.as(Regex::Syntax::AST::Repetition)
    repetition.op.min.should eq(0)
    repetition.op.max.should eq(9)
  end

  it "matches vendored comments, whitespace, newlines, and nest-limit behavior" do
    parser = Regex::Syntax::AstParser.new
    pattern = "(?x)\n# This is comment 1.\nfoo # This is comment 2.\n  # This is comment 3.\nbar\n# This is comment 4."
    parsed = parser.parse_with_comments(pattern)

    parsed.ast.kind.should be_a(Regex::Syntax::AST::Concat)
    parsed.comments.map(&.comment).should eq([
      " This is comment 1.",
      " This is comment 2.",
      " This is comment 3.",
      " This is comment 4.",
    ])

    verbose = parser.parse("(?x)a b(?-x)a b").kind.as(Regex::Syntax::AST::Concat)
    verbose.children.size.should eq(7)
    verbose.children[0].should be_a(Regex::Syntax::AST::SetFlags)
    verbose.children[3].should be_a(Regex::Syntax::AST::SetFlags)
    verbose.children[5].as(Regex::Syntax::AST::Literal).bytes.should eq(" ".to_slice)

    newlines = parser.parse(".\n.").kind.as(Regex::Syntax::AST::Concat)
    newlines.children.map(&.class).should eq([
      Regex::Syntax::AST::Dot,
      Regex::Syntax::AST::Literal,
      Regex::Syntax::AST::Dot,
    ])

    expect_ast_error(
      Regex::Syntax::AST::ErrorKind::NestLimitExceeded,
      Regex::Syntax::AST::Span.new(0, 2)
    ) do
      Regex::Syntax::AST::Parse::ParserBuilder.new.nest_limit(0).build.parse("a+")
    end

    nested_pattern = <<-REGEX
        2(?:
          [45]\\d{3}|
          7(?:
            1[0-267]|
            2[0-289]|
            3[0-29]|
            4[01]|
            5[1-3]|
            6[013]|
            7[0178]|
            91
          )|
          8(?:
            0[125]|
            [139][1-6]|
            2[0157-9]|
            41|
            6[1-35]|
            7[1-5]|
            8[1-8]|
            90
          )|
          9(?:
            0[0-2]|
            1[0-4]|
            2[568]|
            3[3-6]|
            5[5-7]|
            6[0167]|
            7[15]|
            8[0146-9]
          )
        )\\d{4}
        REGEX
    Regex::Syntax::AST::Parse::ParserBuilder.new
      .nest_limit(50)
      .build
      .parse(nested_pattern)
  end

  it "matches vendored group, capture-name, alternation, and flag parsing" do
    parser = Regex::Syntax::AstParser.new

    alternation = parser.parse("a|b|c").kind.as(Regex::Syntax::AST::Alternation)
    alternation.children.map { |child| child.as(Regex::Syntax::AST::Literal).bytes }.should eq([
      "a".to_slice,
      "b".to_slice,
      "c".to_slice,
    ])

    named = parser.parse("(?P<word>a)").kind.as(Regex::Syntax::AST::Group)
    named.kind.should eq(Regex::Syntax::AST::Group::Kind::Capture)
    named.capture_index.should eq(1)
    named.name.should eq("word")
    named.starts_with_p?.should be_true

    angle_named = parser.parse("(?<word>a)").kind.as(Regex::Syntax::AST::Group)
    angle_named.starts_with_p?.should be_false

    non_capture = parser.parse("(?:a)").kind.as(Regex::Syntax::AST::Group)
    non_capture.kind.should eq(Regex::Syntax::AST::Group::Kind::NonCapture)
    non_capture.flags.not_nil!.items.should be_empty

    scoped_flags = parser.parse("(?i-sR:a)").kind.as(Regex::Syntax::AST::Group)
    scoped = scoped_flags.flags.not_nil!
    scoped.flag_state('i').should be_true
    scoped.flag_state('s').should be_false
    scoped.flag_state('R').should be_false

    global_flags = parser.parse("(?im)ab").kind.as(Regex::Syntax::AST::Concat)
    global_flags.children[0].should be_a(Regex::Syntax::AST::SetFlags)

    expect_ast_error(
      Regex::Syntax::AST::ErrorKind::GroupNameDuplicate,
      Regex::Syntax::AST::Span.new(12, 13),
      Regex::Syntax::AST::Span.new(4, 5)
    ) do
      parser.parse("(?P<a>a)(?P<a>b)")
    end

    err = expect_ast_error(
      Regex::Syntax::AST::ErrorKind::FlagDuplicate,
      Regex::Syntax::AST::Span.new(3, 4),
      Regex::Syntax::AST::Span.new(2, 3)
    ) do
      parser.parse("(?ii:ab)")
    end
    err.raw_message.should match(/duplicate flag/)

    expect_ast_error(
      Regex::Syntax::AST::ErrorKind::FlagDanglingNegation,
      Regex::Syntax::AST::Span.new(3, 4)
    ) { parser.parse("(?i-)") }
  end

  it "matches vendored repetition, decimal, and special-word-boundary parsing" do
    parser = Regex::Syntax::AstParser.new

    star = parser.parse("a*").kind.as(Regex::Syntax::AST::Repetition)
    star.op.kind.should eq(Regex::Syntax::AST::RepetitionOp::Kind::ZeroOrMore)
    star.greedy?.should be_true

    exact = parser.parse("a{5}").kind.as(Regex::Syntax::AST::Repetition)
    exact.op.min.should eq(5)
    exact.op.max.should eq(5)

    bounded = parser.parse("a{5,9}").kind.as(Regex::Syntax::AST::Repetition)
    bounded.op.min.should eq(5)
    bounded.op.max.should eq(9)

    spaced_reluctant = Regex::Syntax::AstParser.new(ignore_whitespace: true)
      .parse("a{5,9} ?")
      .kind
      .as(Regex::Syntax::AST::Repetition)
    spaced_reluctant.greedy?.should be_false

    special = parser.parse(%q(\b{start-half})).kind.as(Regex::Syntax::AST::Assertion)
    special.kind.should eq(Regex::Syntax::AST::Assertion::Kind::WordBoundaryStartHalf)

    repeated_boundary = parser.parse(%q(\b{5,9})).kind.as(Regex::Syntax::AST::Repetition)
    repeated_boundary.child.as(Regex::Syntax::AST::Assertion).kind.should eq(
      Regex::Syntax::AST::Assertion::Kind::WordBoundary
    )
    repeated_boundary.op.min.should eq(5)
    repeated_boundary.op.max.should eq(9)

    expect_ast_error(
      Regex::Syntax::AST::ErrorKind::RepetitionCountInvalid,
      Regex::Syntax::AST::Span.new(1, 6)
    ) { parser.parse("a{2,1}") }

    expect_ast_error(
      Regex::Syntax::AST::ErrorKind::RepetitionCountDecimalEmpty,
      Regex::Syntax::AST::Span.new(2, 2)
    ) { parser.parse("a{}") }

    expect_ast_error(
      Regex::Syntax::AST::ErrorKind::SpecialWordBoundaryUnrecognized,
      Regex::Syntax::AST::Span.new(3, 6)
    ) { parser.parse(%q(\b{foo})) }
  end

  it "matches vendored escape, octal, hex, perl-class, and unicode-class parsing" do
    parser = Regex::Syntax::AstParser.new

    escaped = parser.parse(%q(\\\.\+\*\?\(\)\|\[\]\{\}\^\$\#\&\-\~)).kind.as(Regex::Syntax::AST::Concat)
    escaped.children.size.should eq(18)

    parser.parse(%q(\d)).kind.as(Regex::Syntax::AST::ClassPerl).kind.should eq(
      Regex::Syntax::AST::ClassPerl::Kind::Digit
    )
    parser.parse(%q(\D)).kind.as(Regex::Syntax::AST::ClassPerl).kind.should eq(
      Regex::Syntax::AST::ClassPerl::Kind::DigitNeg
    )

    short_unicode = parser.parse(%q(\pNz)).kind.as(Regex::Syntax::AST::Concat)
    short_unicode.children[0].as(Regex::Syntax::AST::ClassUnicode).name.should eq("N")

    named_unicode = parser.parse(%q(\p{Greek}z)).kind.as(Regex::Syntax::AST::Concat)
    named_unicode.children[0].as(Regex::Syntax::AST::ClassUnicode).name.should eq("Greek")

    octal = Regex::Syntax::AstParser.new(octal: true).parse(%q(\141)).kind.as(Regex::Syntax::AST::Literal)
    octal.kind.should eq(Regex::Syntax::AST::Literal::Kind::Octal)
    octal.c.should eq('a')

    parser.parse(%q(\x41)).kind.as(Regex::Syntax::AST::Literal).c.should eq('A')
    parser.parse(%q(\u03A9)).kind.as(Regex::Syntax::AST::Literal).c.should eq('Ω')
    parser.parse(%q(\U0001F600)).kind.as(Regex::Syntax::AST::Literal).c.should eq('😀')
    parser.parse(%q(\x{26C4})).kind.as(Regex::Syntax::AST::Literal).c.should eq('⛄')

    expect_ast_error(
      Regex::Syntax::AST::ErrorKind::EscapeHexInvalidDigit,
      Regex::Syntax::AST::Span.new(5, 6)
    ) { parser.parse(%q(\uFFFG)) }

    expect_ast_error(
      Regex::Syntax::AST::ErrorKind::EscapeHexEmpty,
      Regex::Syntax::AST::Span.new(3, 4)
    ) { parser.parse(%q(\x{})) }

    expect_parse_error(/backreferences are not supported/) do
      parser.parse(%q(\0))
    end
  end

  it "matches vendored set-class, ascii-class, and class-opening parsing" do
    parser = Regex::Syntax::AstParser.new

    ascii = parser.parse("[[:alpha:]]").kind.as(Regex::Syntax::AST::ClassBracketed)
    ascii_item = ascii.kind.item.as(Regex::Syntax::AST::ClassSetItem)
    ascii_item.kind.should eq(Regex::Syntax::AST::ClassSetItem::Kind::Ascii)
    ascii_item.item.as(Regex::Syntax::AST::ClassAscii).kind.should eq(
      Regex::Syntax::AST::ClassAscii::Kind::Alpha
    )

    negated_ascii = parser.parse("[[:^alpha:]]").kind.as(Regex::Syntax::AST::ClassBracketed)
    negated_ascii.kind.item.as(Regex::Syntax::AST::ClassSetItem)
      .item.as(Regex::Syntax::AST::ClassAscii)
      .negated?.should be_true

    backtracked = parser.parse("[[:alnnum:]]").kind.as(Regex::Syntax::AST::ClassBracketed)
    backtracked.kind.item.as(Regex::Syntax::AST::ClassSetItem).kind.should eq(
      Regex::Syntax::AST::ClassSetItem::Kind::Bracketed
    )

    parser.parse("[a&&b]").kind.as(Regex::Syntax::AST::ClassBracketed)
      .kind.binary_op.not_nil!.kind.should eq(Regex::Syntax::AST::ClassSetBinaryOp::Kind::Intersection)
    parser.parse("[a--b]").kind.as(Regex::Syntax::AST::ClassBracketed)
      .kind.binary_op.not_nil!.kind.should eq(Regex::Syntax::AST::ClassSetBinaryOp::Kind::Difference)
    parser.parse("[a~~b]").kind.as(Regex::Syntax::AST::ClassBracketed)
      .kind.binary_op.not_nil!.kind.should eq(Regex::Syntax::AST::ClassSetBinaryOp::Kind::SymmetricDifference)

    parser.parse("[]]").kind.as(Regex::Syntax::AST::ClassBracketed)
      .kind.item.as(Regex::Syntax::AST::ClassSetItem)
      .item.as(Regex::Syntax::AST::Literal).c.should eq(']')

    parser.parse("[-a]").kind.as(Regex::Syntax::AST::ClassBracketed)
      .kind.item.as(Regex::Syntax::AST::ClassSetItem)
      .item.as(Regex::Syntax::AST::ClassSetUnion).items.size.should eq(2)

    parser.parse("[^]a]").kind.as(Regex::Syntax::AST::ClassBracketed).negated?.should be_true

    expect_parse_error(/invalid escape sequence in character class/) do
      parser.parse(%q([\b]))
    end

    expect_parse_error(/invalid character class range/) do
      parser.parse("[z-a]")
    end

    [
      "(?x)[ / - ]",
      "(?x)[ a - ]",
      <<-REGEX,
            (?x)[
            a
            - ]
        REGEX
      <<-REGEX,
            (?x)[
            a # wat
            - ]
        REGEX
    ].each do |pattern|
      parser.parse(pattern)
    end

    [
      "(?x)[ / -",
      "(?x)[ / - ",
      <<-REGEX,
            (?x)[
            / -
        REGEX
      <<-REGEX,
            (?x)[
            / -
        \s
        REGEX
    ].each do |pattern|
      expect_ast_error(Regex::Syntax::AST::ErrorKind::ClassUnclosed) do
        parser.parse(pattern)
      end
    end
  end

  it "matches vendored unsupported-lookaround handling and parser-state reset" do
    parser = Regex::Syntax::AstParser.new

    expect_parse_error(/look-behind/) do
      parser.parse("(?<=a)b")
    end

    expect_parse_error(/look-behind/) do
      parser.parse("(?<!a)b")
    end

    parser.parse("(?i:a)")
    reset = parser.parse("a").kind.as(Regex::Syntax::AST::Literal)
    reset.kind.should eq(Regex::Syntax::AST::Literal::Kind::Verbatim)
    reset.bytes.should eq("a".to_slice)
  end
end
