require "./spec_helper"

private def parse_hir(pattern : String, *,
                      unicode : Bool = true,
                      utf8 : Bool = true,
                      ignore_whitespace : Bool = false,
                      ignore_case : Bool = false,
                      multi_line : Bool = false,
                      dot_matches_new_line : Bool = false,
                      swap_greed : Bool = false,
                      crlf : Bool = false,
                      octal : Bool = false,
                      line_terminator : UInt8 = '\n'.ord.to_u8) : Regex::Syntax::Hir::Hir
  Regex::Syntax::Parser.new(
    unicode: unicode,
    utf8: utf8,
    ignore_whitespace: ignore_whitespace,
    ignore_case: ignore_case,
    multi_line: multi_line,
    dot_matches_new_line: dot_matches_new_line,
    swap_greed: swap_greed,
    crlf: crlf,
    octal: octal,
    line_terminator: line_terminator
  ).parse(pattern)
end

private def translate_hir(pattern : String, *,
                          unicode : Bool = true,
                          utf8 : Bool = true,
                          ignore_whitespace : Bool = false,
                          ignore_case : Bool = false,
                          multi_line : Bool = false,
                          dot_matches_new_line : Bool = false,
                          swap_greed : Bool = false,
                          crlf : Bool = false,
                          octal : Bool = false,
                          line_terminator : UInt8 = '\n'.ord.to_u8) : Regex::Syntax::Hir::Hir
  ast = Regex::Syntax::AstParser.new(
    unicode: unicode,
    ignore_whitespace: ignore_whitespace,
    ignore_case: ignore_case,
    multi_line: multi_line,
    dot_matches_new_line: dot_matches_new_line,
    swap_greed: swap_greed,
    crlf: crlf,
    octal: octal
  ).parse(pattern)

  builder = Regex::Syntax::TranslatorBuilder.new
  builder.utf8(utf8)
  builder.line_terminator(line_terminator)
  builder.case_insensitive(ignore_case)
  builder.multi_line(multi_line)
  builder.dot_matches_new_line(dot_matches_new_line)
  builder.crlf(crlf)
  builder.swap_greed(swap_greed)
  builder.unicode(unicode)
  Regex::Syntax::Hir::Hir.new(builder.build.translate(ast.root))
end

describe "HIR translate parity" do
  it "matches vendored translator-builder option surface and direct translation entrypoints" do
    builder = Regex::Syntax::TranslatorBuilder.new
    builder.utf8(false).should be(builder)
    builder.line_terminator('a'.ord.to_u8).should be(builder)
    builder.case_insensitive(true).should be(builder)
    builder.multi_line(true).should be(builder)
    builder.dot_matches_new_line(false).should be(builder)
    builder.crlf(true).should be(builder)
    builder.swap_greed(true).should be(builder)
    builder.unicode(false).should be(builder)

    ast = Regex::Syntax::AST::Dot.new(Regex::Syntax::AST::Span.new(0, 1))
    translated = builder.build.translate(ast)
    translated.should be_a(Regex::Syntax::Hir::DotNode)
    translated.as(Regex::Syntax::Hir::DotNode).kind.should eq(Regex::Syntax::Hir::Dot::AnyByteExceptCRLF)

    literal = Regex::Syntax::AST::Literal.new(
      Regex::Syntax::AST::Span.new(0, 1),
      Regex::Syntax::AST::Literal::Kind::Verbatim,
      c: 'a'
    )
    direct = Regex::Syntax::Translator.new(
      unicode: true,
      utf8: true,
      ignore_case: true,
      multi_line: true,
      dot_matches_new_line: false,
      swap_greed: true,
      crlf: true,
      line_terminator: '\n'.ord.to_u8
    )
    direct.translate(literal).should be_a(Regex::Syntax::Hir::UnicodeClass)
    direct.translate(ast).as(Regex::Syntax::Hir::DotNode).kind.should eq(Regex::Syntax::Hir::Dot::AnyCharExceptCRLF)

    expect_raises(Regex::Syntax::ParseError, /invalid UTF-8/) do
      Regex::Syntax::TranslatorBuilder.new
        .line_terminator(0xFF_u8)
        .build
        .translate(ast)
    end

    expect_raises(Regex::Syntax::ParseError, /invalid line terminator/) do
      Regex::Syntax::TranslatorBuilder.new
        .utf8(false)
        .line_terminator(0xFF_u8)
        .build
        .translate(ast)
    end
  end

  it "matches vendored literal, assertion, group, flag, escape, and repetition translation" do
    fold_beta = parse_hir("(?i)β")
    fold_beta.node.as(Regex::Syntax::Hir::UnicodeClass).intervals.should eq([
      'Β'.ord.to_u32..'Β'.ord.to_u32,
      'β'.ord.to_u32..'β'.ord.to_u32,
      'ϐ'.ord.to_u32..'ϐ'.ord.to_u32,
    ])

    ascii_fold = parse_hir("(?i-u)ab@c")
    ascii_children = ascii_fold.node.as(Regex::Syntax::Hir::Concat).children
    ascii_children.map(&.class).should eq([
      Regex::Syntax::Hir::CharClass,
      Regex::Syntax::Hir::CharClass,
      Regex::Syntax::Hir::Literal,
      Regex::Syntax::Hir::CharClass,
    ])
    ascii_children[0].as(Regex::Syntax::Hir::CharClass).intervals.should eq([0x41_u8..0x41_u8, 0x61_u8..0x61_u8])
    ascii_children[3].as(Regex::Syntax::Hir::CharClass).intervals.should eq([0x43_u8..0x43_u8, 0x63_u8..0x63_u8])

    parse_hir(".").node.as(Regex::Syntax::Hir::DotNode).kind.should eq(Regex::Syntax::Hir::Dot::AnyCharExceptLF)
    parse_hir("(?R).").node.as(Regex::Syntax::Hir::DotNode).kind.should eq(Regex::Syntax::Hir::Dot::AnyCharExceptCRLF)
    parse_hir("(?s).").node.as(Regex::Syntax::Hir::DotNode).kind.should eq(Regex::Syntax::Hir::Dot::AnyChar)
    parse_hir("(?-u).", unicode: false, utf8: false).node.as(Regex::Syntax::Hir::DotNode).kind.should eq(Regex::Syntax::Hir::Dot::AnyByteExceptLF)

    parse_hir("^").node.as(Regex::Syntax::Hir::Look).kind.should eq(Regex::Syntax::Hir::Look::Kind::StartText)
    parse_hir("(?Rm)^").node.as(Regex::Syntax::Hir::Look).kind.should eq(Regex::Syntax::Hir::Look::Kind::StartCRLF)
    parse_hir("(?Rm)$").node.as(Regex::Syntax::Hir::Look).kind.should eq(Regex::Syntax::Hir::Look::Kind::EndCRLF)
    parse_hir(%q(\b)).node.as(Regex::Syntax::Hir::Look).kind.should eq(Regex::Syntax::Hir::Look::Kind::WordUnicode)
    parse_hir(%q((?-u)\B), unicode: false).node.as(Regex::Syntax::Hir::Look).kind.should eq(Regex::Syntax::Hir::Look::Kind::WordAsciiNegate)

    captures = parse_hir("(?P<foo>a)(?P<bar>b)").node.as(Regex::Syntax::Hir::Concat).children
    captures[0].as(Regex::Syntax::Hir::Capture).name.should eq("foo")
    captures[1].as(Regex::Syntax::Hir::Capture).name.should eq("bar")

    greed = parse_hir("(?U)a*a*?(?-U)a*a*?").node.as(Regex::Syntax::Hir::Concat).children
    greed.map(&.as(Regex::Syntax::Hir::Repetition).greedy?).should eq([false, true, true, false])

    String.new(parse_hir(%q(\\\.\+\*\?\(\)\|\[\]\{\}\^\$\#)).node.as(Regex::Syntax::Hir::Literal).bytes).should eq(%q(\.+*?()|[]{}^$#))

    parse_hir("a?").node.as(Regex::Syntax::Hir::Repetition).max.should eq(1_u32)
    parse_hir("a+?").node.as(Regex::Syntax::Hir::Repetition).greedy?.should be_false
    parse_hir("a{1,2}?").node.as(Regex::Syntax::Hir::Repetition).max.should eq(2_u32)
  end

  it "matches vendored class translation, class flattening, and set-operator behavior" do
    parse_hir("[[:alnum:]]").node.as(Regex::Syntax::Hir::UnicodeClass).intervals.should eq([
      '0'.ord.to_u32..'9'.ord.to_u32,
      'A'.ord.to_u32..'Z'.ord.to_u32,
      'a'.ord.to_u32..'z'.ord.to_u32,
    ])
    parse_hir("(?-u)[[:lower:]]", unicode: false, utf8: false).node.as(Regex::Syntax::Hir::CharClass).intervals.should eq([
      'a'.ord.to_u8..'z'.ord.to_u8,
    ])
    parse_hir("(?i-u)[[:lower:]]", unicode: false, utf8: false).node.as(Regex::Syntax::Hir::CharClass).intervals.should eq([
      'A'.ord.to_u8..'Z'.ord.to_u8,
      'a'.ord.to_u8..'z'.ord.to_u8,
    ])
    expect_hir_error(Regex::Syntax::Hir::ErrorKind::InvalidUtf8, Regex::Syntax::AST::Span.new(5, 17)) do
      parse_hir("(?-u)[[:^lower:]]", unicode: false)
    end

    parse_hir("[[:alnum:][:^ascii:]]").node.as(Regex::Syntax::Hir::UnicodeClass).intervals.should eq([
      '0'.ord.to_u32..'9'.ord.to_u32,
      'A'.ord.to_u32..'Z'.ord.to_u32,
      'a'.ord.to_u32..'z'.ord.to_u32,
      0x80_u32..0x10FFFF_u32,
    ])
    parse_hir("(?-u)[[:alnum:][:^ascii:]]", unicode: false, utf8: false).node.as(Regex::Syntax::Hir::CharClass).intervals.should eq([
      '0'.ord.to_u8..'9'.ord.to_u8,
      'A'.ord.to_u8..'Z'.ord.to_u8,
      'a'.ord.to_u8..'z'.ord.to_u8,
      0x80_u8..0xFF_u8,
    ])

    parse_hir("[a-z]|[A-Z]").node.as(Regex::Syntax::Hir::UnicodeClass).intervals.should eq([
      'A'.ord.to_u32..'Z'.ord.to_u32,
      'a'.ord.to_u32..'z'.ord.to_u32,
    ])

    mixed = parse_hir("[Δδ]|(?-u:[\\x90-\\xFF])|[Λλ]", utf8: false)
    mixed.node.should be_a(Regex::Syntax::Hir::Alternation)
    mixed.node.as(Regex::Syntax::Hir::Alternation).children.map(&.class).should eq([
      Regex::Syntax::Hir::UnicodeClass,
      Regex::Syntax::Hir::CharClass,
      Regex::Syntax::Hir::UnicodeClass,
    ])

    parse_hir("(?-u)[[:alpha:]--[:lower:]]", unicode: false, utf8: false).node.as(Regex::Syntax::Hir::CharClass).intervals.should eq([
      'A'.ord.to_u8..'Z'.ord.to_u8,
    ])

    parse_hir("[a-g~~c-j]").node.as(Regex::Syntax::Hir::UnicodeClass).intervals.should eq([
      'a'.ord.to_u32..'b'.ord.to_u32,
      'h'.ord.to_u32..'j'.ord.to_u32,
    ])

    parse_hir(%q([\^&&^])).node.as(Regex::Syntax::Hir::UnicodeClass).intervals.should eq([
      '^'.ord.to_u32..'^'.ord.to_u32,
    ])
    parse_hir(%q([]&&\]])).node.as(Regex::Syntax::Hir::UnicodeClass).intervals.should eq([
      ']'.ord.to_u32..']'.ord.to_u32,
    ])
    parse_hir(%q([a-w&&[^c-g]z])).node.as(Regex::Syntax::Hir::UnicodeClass).intervals.should eq([
      'a'.ord.to_u32..'b'.ord.to_u32,
      'h'.ord.to_u32..'w'.ord.to_u32,
    ])

    parse_hir(%q(\d)).node.as(Regex::Syntax::Hir::UnicodeClass).negated?.should be_false
    parse_hir(%q(\D)).node.as(Regex::Syntax::Hir::UnicodeClass).negated?.should be_true
    parse_hir(%q(\S)).node.as(Regex::Syntax::Hir::UnicodeClass).negated?.should be_true
    parse_hir(%q(\W)).node.as(Regex::Syntax::Hir::UnicodeClass).negated?.should be_true
    parse_hir(%q((?-u)\d), unicode: false).node.as(Regex::Syntax::Hir::CharClass).intervals.should eq([
      '0'.ord.to_u8..'9'.ord.to_u8,
    ])
    parse_hir(%q((?-u)\D), unicode: false, utf8: false).node.as(Regex::Syntax::Hir::CharClass).negated?.should be_true
    parse_hir(%q((?-u)\S), unicode: false, utf8: false).node.as(Regex::Syntax::Hir::CharClass).negated?.should be_true
    parse_hir(%q((?-u)\W), unicode: false, utf8: false).node.as(Regex::Syntax::Hir::CharClass).negated?.should be_true

    expect_hir_error(Regex::Syntax::Hir::ErrorKind::InvalidUtf8, Regex::Syntax::AST::Span.new(5, 7)) do
      parse_hir(%q((?-u)\D), unicode: false)
    end
    expect_hir_error(Regex::Syntax::Hir::ErrorKind::InvalidUtf8, Regex::Syntax::AST::Span.new(5, 7)) do
      parse_hir(%q((?-u)\S), unicode: false)
    end
    expect_hir_error(Regex::Syntax::Hir::ErrorKind::InvalidUtf8, Regex::Syntax::AST::Span.new(5, 7)) do
      parse_hir(%q((?-u)\W), unicode: false)
    end

    parse_hir(%q(\pZ)).node.as(Regex::Syntax::Hir::UnicodeClass).intervals.should_not be_empty
    parse_hir(%q(\p{Separator})).node.as(Regex::Syntax::Hir::UnicodeClass).intervals.should_not be_empty
    parse_hir(%q(\P{separator})).node.as(Regex::Syntax::Hir::UnicodeClass).negated?.should be_true
    parse_hir(%q(\p{Greek})).node.as(Regex::Syntax::Hir::UnicodeClass).intervals.should_not be_empty
    parse_hir(%q(\P{any})).node.as(Regex::Syntax::Hir::UnicodeClass).intervals.should be_empty
    ex = expect_raises(Regex::Syntax::ParseError) do
      translate_hir(%q((?-u)\pZ), unicode: false)
    end
    ex.message.to_s.should contain("Unicode not allowed")
    ex.span.should eq(Regex::Syntax::AST::Span.new(5, 8))
    expect_parse_error(/invalid Unicode property/) do
      parse_hir(%q(\pE))
    end
    expect_parse_error(/invalid Unicode property/) do
      parse_hir(%q(\p{Foo}))
    end
    expect_parse_error(/invalid Unicode property value/) do
      parse_hir(%q(\p{gc:Foo}))
    end
    expect_parse_error(/invalid Unicode property value/) do
      parse_hir(%q(\p{sc:Foo}))
    end
    expect_parse_error(/invalid Unicode property value/) do
      parse_hir(%q(\p{scx:Foo}))
    end
    expect_parse_error(/invalid Unicode property value/) do
      parse_hir(%q(\p{age:Foo}))
    end
  end

  it "matches vendored translation analysis semantics" do
    parse_hir("(?-u)\\xFF", unicode: false, utf8: false).utf8?.should be_false
    parse_hir("(?-u)[^a]", unicode: false, utf8: false).utf8?.should be_false
    parse_hir("ab").utf8?.should be_true
    parse_hir("(?-u)a", unicode: false).utf8?.should be_true
    parse_hir(%q(\b)).utf8?.should be_true
    parse_hir(%q((?-u)\b), unicode: false).utf8?.should be_true

    parse_hir("a").explicit_captures_len.should eq(0)
    parse_hir("(?:a)").explicit_captures_len.should eq(0)
    parse_hir("(a)(b)").explicit_captures_len.should eq(2)
    parse_hir("((a))").explicit_captures_len.should eq(2)
    parse_hir("(foo)(bar)|(baz)(quux)").static_explicit_captures_len.should eq(2)
    parse_hir("").static_explicit_captures_len.should eq(0)
    parse_hir("(foo|bar)").static_explicit_captures_len.should eq(1)
    parse_hir("(foo)*(bar)").static_explicit_captures_len.should be_nil
    parse_hir("(foo)?{1}").static_explicit_captures_len.should be_nil

    parse_hir(%q(\b)).all_assertions?.should be_true
    parse_hir(%q($|^|\z|\A|\b|\B)).all_assertions?.should be_true
    parse_hir("^a").all_assertions?.should be_false

    parse_hir("(?-u)(?i:(?:\\b|_)win(?:32|64|dows)?(?:\\b|_))", unicode: false).look_set_prefix_any.contains(Regex::Syntax::Hir::Look::Kind::WordAscii).should be_true

    parse_hir("^").look_set_prefix.contains(Regex::Syntax::Hir::Look::Kind::StartText).should be_true
    parse_hir("$").look_set_suffix.contains(Regex::Syntax::Hir::Look::Kind::EndText).should be_true
    parse_hir("^foo|^bar").look_set_prefix.contains(Regex::Syntax::Hir::Look::Kind::StartText).should be_true
    parse_hir("foo$|bar$").look_set_suffix.contains(Regex::Syntax::Hir::Look::Kind::EndText).should be_true
    parse_hir("(?m)^").look_set_prefix.contains(Regex::Syntax::Hir::Look::Kind::StartText).should be_false
    parse_hir("(?m)$").look_set.contains(Regex::Syntax::Hir::Look::Kind::EndText).should be_false
    parse_hir("^foo|bar").look_set_prefix.contains(Regex::Syntax::Hir::Look::Kind::StartText).should be_false
    parse_hir("foo|bar$").look_set_suffix.contains(Regex::Syntax::Hir::Look::Kind::EndText).should be_false
    parse_hir("^").look_set.contains(Regex::Syntax::Hir::Look::Kind::StartText).should be_true
    parse_hir("$").look_set.contains(Regex::Syntax::Hir::Look::Kind::EndText).should be_true
    parse_hir("(?m)^").look_set.contains(Regex::Syntax::Hir::Look::Kind::StartText).should be_false
    parse_hir("(?m)$").look_set.contains(Regex::Syntax::Hir::Look::Kind::EndText).should be_false

    parse_hir("").can_match_empty?.should be_true
    parse_hir("()").can_match_empty?.should be_true
    parse_hir("a{0}").can_match_empty?.should be_true
    parse_hir("a|").can_match_empty?.should be_true
    parse_hir("|a").can_match_empty?.should be_true
    parse_hir("a+").can_match_empty?.should be_false
    parse_hir("[a&&b]").can_match_empty?.should be_false

    parse_hir("abc").literal?.should be_true
    parse_hir("[a]").literal?.should be_true
    parse_hir("").literal?.should be_false
    parse_hir("(a)").literal?.should be_false
    parse_hir("[ab]").literal?.should be_false
    parse_hir("foo|bar").alternation_literal?.should be_true
    parse_hir("foo|bar|baz").alternation_literal?.should be_true
    parse_hir("a").alternation_literal?.should be_true
    parse_hir("a|b|c").alternation_literal?.should be_false
    parse_hir("a|b").alternation_literal?.should be_false
  end

  it "matches vendored smart-constructor behavior and translate regressions" do
    parse_hir("a{0}").node.should be_a(Regex::Syntax::Hir::Empty)
    parse_hir("a{1}").node.should be_a(Regex::Syntax::Hir::Literal)
    parse_hir(%q(\B{32111})).node.as(Regex::Syntax::Hir::Look).kind.should eq(Regex::Syntax::Hir::Look::Kind::WordUnicodeNegate)

    parse_hir("").node.should be_a(Regex::Syntax::Hir::Empty)
    parse_hir("(?:)").node.should be_a(Regex::Syntax::Hir::Empty)
    foobar = parse_hir("(?:foo)(?:bar)")
    foobar.node.should be_a(Regex::Syntax::Hir::Literal)
    String.new(foobar.node.as(Regex::Syntax::Hir::Literal).bytes).should eq("foobar")

    punctuated = parse_hir("foo(?:bar^baz)quux").node.as(Regex::Syntax::Hir::Concat).children
    punctuated.map(&.class).should eq([
      Regex::Syntax::Hir::Literal,
      Regex::Syntax::Hir::Look,
      Regex::Syntax::Hir::Literal,
    ])
    String.new(punctuated[0].as(Regex::Syntax::Hir::Literal).bytes).should eq("foobar")
    String.new(punctuated[2].as(Regex::Syntax::Hir::Literal).bytes).should eq("bazquux")

    nested_alt = parse_hir("quux|(?:abc|(?:def|mno)|xyz)|baz")
    nested_alt.node.should be_a(Regex::Syntax::Hir::Alternation)
    nested_alt.node.as(Regex::Syntax::Hir::Alternation).children.size.should eq(6)

    lifted = parse_hir("[A-Z]foo|[A-Z]quux")
    lifted.node.should be_a(Regex::Syntax::Hir::Concat)
    lifted_children = lifted.node.as(Regex::Syntax::Hir::Concat).children
    lifted_children.map(&.class).should eq([
      Regex::Syntax::Hir::UnicodeClass,
      Regex::Syntax::Hir::Alternation,
    ])
    lifted_alt = lifted_children[1].as(Regex::Syntax::Hir::Alternation).children
    String.new(lifted_alt[0].as(Regex::Syntax::Hir::Literal).bytes).should eq("foo")
    String.new(lifted_alt[1].as(Regex::Syntax::Hir::Literal).bytes).should eq("quux")

    double_lift = parse_hir("[A-Z][A-Z]|[A-Z][A-Z]quux")
    double_lift.node.should be_a(Regex::Syntax::Hir::Concat)
    double_lift_children = double_lift.node.as(Regex::Syntax::Hir::Concat).children
    double_lift_children[0].should be_a(Regex::Syntax::Hir::UnicodeClass)
    double_lift_children[1].should be_a(Regex::Syntax::Hir::UnicodeClass)
    tail_alt = double_lift_children[2].as(Regex::Syntax::Hir::Alternation).children
    tail_alt[0].should be_a(Regex::Syntax::Hir::Empty)
    String.new(tail_alt[1].as(Regex::Syntax::Hir::Literal).bytes).should eq("quux")

    translate_hir("", unicode: true).node.should be_a(Regex::Syntax::Hir::Empty)

    span = Regex::Syntax::AST::Span.new(0, 0)
    empty_concat = Regex::Syntax::AST::Alternation.new(
      span,
      [Regex::Syntax::AST::Concat.new(span, [] of Regex::Syntax::AST::Node)] of Regex::Syntax::AST::Node
    )
    Regex::Syntax::Hir::Hir.new(Regex::Syntax::Translator.new.translate(empty_concat)).node.should be_a(Regex::Syntax::Hir::Empty)

    empty_alt = Regex::Syntax::AST::Concat.new(
      span,
      [Regex::Syntax::AST::Alternation.new(span, [] of Regex::Syntax::AST::Node)] of Regex::Syntax::AST::Node
    )
    Regex::Syntax::Hir::Hir.new(Regex::Syntax::Translator.new.translate(empty_alt)).node.as(Regex::Syntax::Hir::CharClass).intervals.should be_empty

    singleton_alt = Regex::Syntax::AST::Concat.new(
      span,
      [Regex::Syntax::AST::Alternation.new(span, [Regex::Syntax::AST::Dot.new(span)] of Regex::Syntax::AST::Node)] of Regex::Syntax::AST::Node
    )
    Regex::Syntax::Hir::Hir.new(Regex::Syntax::Translator.new.translate(singleton_alt)).node.as(Regex::Syntax::Hir::DotNode).kind.should eq(Regex::Syntax::Hir::Dot::AnyCharExceptLF)

    parse_hir(%q((?x)\12 3), ignore_whitespace: true, octal: true).node.as(Regex::Syntax::Hir::Literal).bytes.should eq("\n3".to_slice)
    parse_hir(%q((?x)\x { 53 }), ignore_whitespace: true).node.as(Regex::Syntax::Hir::Literal).bytes.should eq("S".to_slice)
    parse_hir(%q((?x)a\  # hi there), ignore_whitespace: true).node.as(Regex::Syntax::Hir::Literal).bytes.should eq("a ".to_slice)

    parse_hir("[(\u{6} \0-\u{afdf5}]  \0 ", ignore_whitespace: true, octal: false).node.should be_a(Regex::Syntax::Hir::Concat)
    parse_hir(%q(\W\W|\W[^\v--\W\W\P{Script_Extensions:Pau_Cin_Hau}\u10A1A1-\U{3E3E3}--~~~~--~~~~~~~~------~~~~~~--~~~~~~]*))
    parse_hir("w[w[^w?\rw\rw[^w?\rw[^w?\rw[^w?\rw[^w?\rw[^w?\rw[^w?\r\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0w?\rw[^w?\rw[^w?\rw[^w\0\0\u{1}\0]\0\0-*\0]\0\0\0\0\0\0\u{1}\0]\0\0-*\0]\0\0\0\0\0\u{1}\0]\0\0\0\0\0\0\0\0\0*\0\0\u{1}\0]\0\0-*\0][^w?\rw[^w?\rw[^w?\rw[^w?\rw[^w?\rw[^w?\rw[^w\0\0\u{1}\0]\0\0-*\0]\0\0\0\0\0\0\u{1}\0]\0\0-*\0]\0\0\0\0\0\u{1}\0]\0\0\0\0\0\0\0\0\0x\0\0\u{1}\0]\0\0-*\0]\0\0\0\0\0\0\0\0\0*??\0\u{7f}{2}\u{10}??\0\0\0\0\0\0\0\0\0\u{3}\0\0\0}\0-*\0]\0\0\0\0\0\0\u{1}\0]\0\0-*\0]\0\0\0\0\0\0\u{1}\0]\0\0-*\0]\0\0\0\0\0\u{1}\0]\0\0-*\0]\0\0\0\0\0\0\0\u{1}\0]\0\u{1}\u{1}H-i]-]\0\0\0\0\u{1}\0]\0\0\0\u{1}\0]\0\0-*\0\0\0\0\u{1}9-\u{7f}]\0'|-\u{7f}]\0'|(?i-ux)[-\u{7f}]\0'\u{3}\0\0\0}\0-*\0]<D\0\0\0\0\0\0\u{1}]\0\0\0\0]\0\0-*\0]\0\0 ")
  end
end
