require "./spec_helper"

describe "AST core parity" do
  it "exposes vendored enum aliases and assertion variants" do
    Regex::Syntax::AST::AssertionKind::Start.should eq(Regex::Syntax::AST::Assertion::Kind::Start)
    Regex::Syntax::AST::AssertionKind::WordBoundaryStart.should eq(Regex::Syntax::AST::Assertion::Kind::WordBoundaryStart)
    Regex::Syntax::AST::AssertionKind::WordBoundaryEnd.should eq(Regex::Syntax::AST::Assertion::Kind::WordBoundaryEnd)
    Regex::Syntax::AST::AssertionKind::WordBoundaryStartAngle.should eq(Regex::Syntax::AST::Assertion::Kind::WordBoundaryStartAngle)
    Regex::Syntax::AST::AssertionKind::WordBoundaryEndAngle.should eq(Regex::Syntax::AST::Assertion::Kind::WordBoundaryEndAngle)
    Regex::Syntax::AST::ClassAsciiKind::Alpha.should eq(Regex::Syntax::AST::ClassAscii::Kind::Alpha)
    Regex::Syntax::AST::ClassPerlKind::Word.should eq(Regex::Syntax::AST::ClassPerl::Kind::Word)
    Regex::Syntax::AST::ClassSetBinaryOpKind::Intersection.should eq(Regex::Syntax::AST::ClassSetBinaryOp::Kind::Intersection)
    Regex::Syntax::AST::ClassSetItemKind::Literal.should eq(Regex::Syntax::AST::ClassSetItem::Kind::Literal)
    Regex::Syntax::AST::FlagsItemKind::Negation.should eq(Regex::Syntax::AST::FlagsItem::Kind::Negation)
    Regex::Syntax::AST::GroupKind::Capture.should eq(Regex::Syntax::AST::Group::Kind::Capture)
    Regex::Syntax::AST::LiteralKind::Verbatim.should eq(Regex::Syntax::AST::Literal::Kind::Verbatim)
    Regex::Syntax::AST::RepetitionKind::Range.should eq(Regex::Syntax::AST::RepetitionOp::Kind::Range)
    Regex::Syntax::AST::Flag.from_char('m').should eq(Regex::Syntax::AST::Flag::MultiLine)
    Regex::Syntax::AST::Flag::Unicode.to_char.should eq('u')
    Regex::Syntax::AST::ClassAscii::Kind.from_name("alpha").should eq(Regex::Syntax::AST::ClassAscii::Kind::Alpha)
  end

  it "matches vendored span, position, literal, and unicode helper semantics" do
    span = Regex::Syntax::AST::Span.new(2, 5)
    span.one_line?.should be_true
    span.is_one_line.should be_true
    span.empty?.should be_false
    span.is_empty.should be_false
    span.with_start(Regex::Syntax::AST::Position.new(1)).start.offset.should eq(1)
    span.with_end(Regex::Syntax::AST::Position.new(9)).end.offset.should eq(9)

    position = Regex::Syntax::AST::Position.new(7, 3, 2)
    position.offset.should eq(7)
    position.line.should eq(3)
    position.column.should eq(2)
    Regex::Syntax::AST::Span.splat(position).start.should eq(position)

    escaped = Regex::Syntax::AST::Literal.new(
      Regex::Syntax::AST::Span.new(0, 2),
      Regex::Syntax::AST::Literal::Kind::Escaped,
      c: '\n'
    )
    escaped.special_kind.should eq(Regex::Syntax::AST::Literal::SpecialLiteralKind::LineFeed)

    hex = Regex::Syntax::AST::Literal.new(
      Regex::Syntax::AST::Span.new(0, 4),
      Regex::Syntax::AST::Literal::Kind::Unicode,
      c: 'A',
      form: Regex::Syntax::AST::Literal::Form::Fixed,
      fixed_digits: 4,
      escape_prefix: 'u'
    )
    hex.hex_kind.should eq(Regex::Syntax::AST::Literal::HexLiteralKind::UnicodeShort)
    hex.hex_kind.not_nil!.digits.should eq(4_u32)

    byte_literal = Regex::Syntax::AST::Literal.new(
      Regex::Syntax::AST::Span.new(0, 1),
      Regex::Syntax::AST::Literal::Kind::Hex,
      bytes: Bytes[0x41_u8]
    )
    byte_literal.byte.should eq(0x41_u8)

    unicode = Regex::Syntax::AST::ClassUnicode.new(
      Regex::Syntax::AST::Span.new(0, 14),
      true,
      "scx!=Katakana"
    )
    unicode_kind = unicode.kind
    unicode_kind.kind.named_value?.should be_true
    unicode_kind.op.should eq(Regex::Syntax::AST::ClassUnicode::ClassUnicodeOpKind::NotEqual)
    unicode_kind.op.not_nil!.is_equal.should be_false
    unicode_kind.property_name.should eq("scx")
    unicode_kind.property_value.should eq("Katakana")
    unicode.is_negated.should be_false

    equal_op = Regex::Syntax::AST::ClassUnicode::ClassUnicodeOpKind::Equal
    equal_op.is_equal.should be_true
  end

  it "matches vendored class set, flag, and repetition helper semantics" do
    literal = Regex::Syntax::AST::Literal.new(
      Regex::Syntax::AST::Span.new(0, 1),
      Regex::Syntax::AST::Literal::Kind::Verbatim,
      c: 'a'
    )
    range = Regex::Syntax::AST::ClassSetRange.new(Regex::Syntax::AST::Span.new(0, 3), literal, literal)
    range.valid?.should be_true
    range.is_valid.should be_true

    item = Regex::Syntax::AST::ClassSetItem.new(literal.span, Regex::Syntax::AST::ClassSetItem::Kind::Literal, literal)
    item.span.should eq(literal.span)

    union = Regex::Syntax::AST::ClassSetUnion.new(Regex::Syntax::AST::Span.new(0, 1))
    union.empty?.should be_true
    union.push(item).items.size.should eq(1)
    union.empty?.should be_false
    union.span.start.should eq(item.span.start)
    union.span.end.should eq(item.span.end)
    union.into_item.kind.should eq(Regex::Syntax::AST::ClassSetItem::Kind::Literal)

    set = Regex::Syntax::AST::ClassSet.new(Regex::Syntax::AST::Span.new(0, 1), Regex::Syntax::AST::ClassSet::Kind::Item, item: item)
    set.union(item)
    set.item.not_nil!.kind.should eq(Regex::Syntax::AST::ClassSetItem::Kind::Union)
    Regex::Syntax::AST::ClassSet.union(union).item.should eq(item)

    binary_lhs = Regex::Syntax::AST::ClassSet.new(literal.span, Regex::Syntax::AST::ClassSet::Kind::Item, item: item)
    binary_rhs = Regex::Syntax::AST::ClassSet.new(literal.span, Regex::Syntax::AST::ClassSet::Kind::Item, item: item)
    binary = Regex::Syntax::AST::ClassSetBinaryOp.new(
      Regex::Syntax::AST::Span.new(0, 1),
      Regex::Syntax::AST::ClassSetBinaryOp::Kind::Difference,
      binary_lhs,
      binary_rhs
    )
    binary.kind.difference?.should be_true

    flag_item = Regex::Syntax::AST::FlagsItem.new(
      Regex::Syntax::AST::Span.new(0, 1),
      Regex::Syntax::AST::FlagsItem::Kind::Negation
    )
    flag_item.negation?.should be_true
    flag_item.is_negation.should be_true
    Regex::Syntax::AST::FlagsItemKind::Negation.is_negation.should be_true

    flags = Regex::Syntax::AST::Flags.new(Regex::Syntax::AST::Span.new(0, 0))
    flags.add_item(flag_item).should be_nil
    positive_i = Regex::Syntax::AST::FlagsItem.new(
      Regex::Syntax::AST::Span.new(1, 2),
      Regex::Syntax::AST::FlagsItem::Kind::Flag,
      'i'
    )
    positive_i.flag_enum.should eq(Regex::Syntax::AST::Flag::CaseInsensitive)
    flags.add_item(positive_i).should be_nil
    flags.flag_state('i').should be_false
    flags.flag_state(Regex::Syntax::AST::Flag::CaseInsensitive).should be_false
    flags.add_item(positive_i).should eq(1)

    repetition_op = Regex::Syntax::AST::RepetitionOp.new(Regex::Syntax::AST::RepetitionOp::Kind::Range, 1_u32, 2_u32)
    repetition_op.valid?.should be_true
    repetition_op.is_valid.should be_true
    repetition_op.range.not_nil!.kind.bounded?.should be_true
    repetition_op.range.not_nil!.valid?.should be_true
    Regex::Syntax::AST::RepetitionRange.bounded(3_u32, 5_u32).valid?.should be_true
  end

  it "matches vendored group, concat, alternation, and ast wrapper semantics" do
    child = Regex::Syntax::AST::Empty.new(Regex::Syntax::AST::Span.new(0, 0))
    flags = Regex::Syntax::AST::Flags.new(
      Regex::Syntax::AST::Span.new(1, 4),
      [
        Regex::Syntax::AST::FlagsItem.new(
          Regex::Syntax::AST::Span.new(2, 3),
          Regex::Syntax::AST::FlagsItem::Kind::Flag,
          'i'
        ),
      ]
    )
    group = Regex::Syntax::AST::Group.new(
      Regex::Syntax::AST::Span.new(0, 8),
      Regex::Syntax::AST::Group::Kind::Capture,
      child,
      capture_index: 2,
      name: "word",
      starts_with_p: true
    )
    group.capturing?.should be_true
    group.is_capturing.should be_true
    group.capture_index.should eq(2)
    group.starts_with_p?.should be_true
    group.capture_name.not_nil!.name.should eq("word")
    group.capture_name.not_nil!.index.should eq(2_u32)

    flagged_group = Regex::Syntax::AST::Group.new(
      Regex::Syntax::AST::Span.new(0, 6),
      Regex::Syntax::AST::Group::Kind::NonCapture,
      child,
      flags: flags
    )
    flagged_group.flags.should eq(flags)

    set_flags_item = Regex::Syntax::AST::FlagsItem.new(
      Regex::Syntax::AST::Span.new(2, 3),
      Regex::Syntax::AST::FlagsItem::Kind::Flag,
      'm'
    )
    set_flags = Regex::Syntax::AST::SetFlags.new(Regex::Syntax::AST::Span.new(0, 4), [set_flags_item])
    set_flags.flags.flag_state(Regex::Syntax::AST::Flag::MultiLine).should be_true

    one_child = [child] of Regex::Syntax::AST::Node
    concat = Regex::Syntax::AST::Concat.new(Regex::Syntax::AST::Span.new(0, 0), one_child)
    concat.into_ast.kind.should be_a(Regex::Syntax::AST::Empty)
    Regex::Syntax::AST::Ast.concat(concat).kind.should eq(concat)

    alt = Regex::Syntax::AST::Alternation.new(Regex::Syntax::AST::Span.new(0, 0), one_child)
    alt.into_ast.kind.should be_a(Regex::Syntax::AST::Empty)
    Regex::Syntax::AST::Ast.alternation(alt).kind.should eq(alt)

    ast = Regex::Syntax::AST::Ast.empty
    ast.kind.should be_a(Regex::Syntax::AST::Empty)
    ast.empty?.should be_true
    ast.is_empty.should be_true

    assertion = Regex::Syntax::AST::Assertion.new(Regex::Syntax::AST::Span.new(0, 1), Regex::Syntax::AST::AssertionKind::Start)
    Regex::Syntax::AST::Ast.assertion(assertion).kind.should eq(assertion)

    perl = Regex::Syntax::AST::ClassPerl.new(Regex::Syntax::AST::Span.new(0, 2), Regex::Syntax::AST::ClassPerlKind::DigitNeg)
    Regex::Syntax::AST::Ast.class_perl(perl).kind.should eq(perl)

    unicode = Regex::Syntax::AST::ClassUnicode.new(Regex::Syntax::AST::Span.new(0, 5), false, "Greek")
    Regex::Syntax::AST::Ast.class_unicode(unicode).kind.should eq(unicode)

    ascii = Regex::Syntax::AST::ClassAscii.new(Regex::Syntax::AST::Span.new(0, 2), Regex::Syntax::AST::ClassAsciiKind::Alpha, false)
    Regex::Syntax::AST::Ast.class_bracketed(
      Regex::Syntax::AST::ClassBracketed.new(
        Regex::Syntax::AST::Span.new(0, 2),
        false,
        Regex::Syntax::AST::ClassSet.new(
          Regex::Syntax::AST::Span.new(0, 2),
          Regex::Syntax::AST::ClassSet::Kind::Item,
          item: Regex::Syntax::AST::ClassSetItem.new(
            Regex::Syntax::AST::Span.new(0, 2),
            Regex::Syntax::AST::ClassSetItem::Kind::Ascii,
            ascii
          )
        )
      )
    ).kind.should be_a(Regex::Syntax::AST::ClassBracketed)

    literal = Regex::Syntax::AST::Literal.new(
      Regex::Syntax::AST::Span.new(0, 1),
      Regex::Syntax::AST::Literal::Kind::Verbatim,
      c: 'a'
    )
    Regex::Syntax::AST::Ast.literal(literal).kind.should eq(literal)
    Regex::Syntax::AST::Ast.dot(Regex::Syntax::AST::Span.new(3, 4)).kind.should be_a(Regex::Syntax::AST::Dot)
    repetition = Regex::Syntax::AST::Repetition.new(
      Regex::Syntax::AST::Span.new(0, 2),
      Regex::Syntax::AST::RepetitionOp.new(Regex::Syntax::AST::RepetitionKind::ZeroOrMore),
      true,
      literal
    )
    Regex::Syntax::AST::Ast.repetition(repetition).kind.should eq(repetition)
    Regex::Syntax::AST::Ast.group(group).kind.should eq(group)
    Regex::Syntax::AST::Ast.group(flagged_group).kind.should eq(flagged_group)
    Regex::Syntax::AST::Ast.flags(set_flags).kind.should eq(set_flags)

    comment = Regex::Syntax::AST::Comment.new(Regex::Syntax::AST::Span.new(0, 1), " note")
    with_comments = Regex::Syntax::AST::WithComments.new(Regex::Syntax::AST::Ast.empty, [comment])
    with_comments.comments.first.comment.should eq(" note")
  end
end
