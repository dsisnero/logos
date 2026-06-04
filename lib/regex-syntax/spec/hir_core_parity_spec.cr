require "./spec_helper"

describe "HIR core parity" do
  it "matches vendored interval-set byte and unicode operations" do
    bytes = Regex::Syntax::Hir::IntervalSet(UInt8).new([
      0x63_u8..0x66_u8,
      0x61_u8..0x67_u8,
      0x64_u8..0x6A_u8,
      0x61_u8..0x63_u8,
      0x6D_u8..0x70_u8,
      0x6C_u8..0x73_u8,
    ])
    bytes.intervals.should eq([0x61_u8..0x6A_u8, 0x6C_u8..0x73_u8])
    bytes.iter.to_a.should eq([0x61_u8..0x6A_u8, 0x6C_u8..0x73_u8])

    right = Regex::Syntax::Hir::IntervalSet(UInt8).new([0x62_u8..0x63_u8, 0x64_u8..0x65_u8, 0x66_u8..0x67_u8])
    bytes.intersect(right).intervals.should eq([0x62_u8..0x67_u8])
    bytes.difference(right).intervals.should eq([0x61_u8..0x61_u8, 0x68_u8..0x6A_u8, 0x6C_u8..0x73_u8])
    bytes.symmetric_difference(right).intervals.should eq([0x61_u8..0x61_u8, 0x68_u8..0x6A_u8, 0x6C_u8..0x73_u8])

    pushed = Regex::Syntax::Hir::IntervalSet(UInt8).new
    pushed.push(1_u8..3_u8).push(5_u8..5_u8)
    pushed.negate!.intervals.should eq([0_u8..0_u8, 4_u8..4_u8, 6_u8..255_u8])

    unicode = Regex::Syntax::Hir::IntervalSet(UInt32).new(['k'.ord.to_u32..'k'.ord.to_u32])
    unicode.case_fold_simple!
    unicode.intervals.should eq([
      'K'.ord.to_u32..'K'.ord.to_u32,
      'k'.ord.to_u32..'k'.ord.to_u32,
      0x212A_u32..0x212A_u32,
    ])
  end

  it "matches vendored class canonicalization, conversion, and set algebra" do
    byte_range = Regex::Syntax::Hir::ClassBytesRange.new(0x7A_u8, 0x61_u8)
    byte_range.start.should eq(0x61_u8)
    byte_range.end.should eq(0x7A_u8)
    byte_range.len.should eq(26)

    unicode_range = Regex::Syntax::Hir::ClassUnicodeRange.new('z'.ord.to_u32, 'a'.ord.to_u32)
    unicode_range.start.should eq('a'.ord.to_u32)
    unicode_range.end.should eq('z'.ord.to_u32)
    unicode_range.len.should eq(26)

    bytes = Regex::Syntax::Hir::CharClass.new(false, [
      0x63_u8..0x66_u8,
      0x61_u8..0x67_u8,
      0x64_u8..0x6A_u8,
      0x61_u8..0x63_u8,
      0x6D_u8..0x70_u8,
      0x6C_u8..0x73_u8,
    ])
    bytes.ranges.should eq([0x61_u8..0x6A_u8, 0x6C_u8..0x73_u8])
    bytes.iter.to_a.map(&.to_range).should eq([0x61_u8..0x6A_u8, 0x6C_u8..0x73_u8])
    bytes.ascii?.should be_true
    bytes.is_ascii.should be_true
    bytes.minimum_len.should eq(1)
    bytes.maximum_len.should eq(1)
    bytes.literal.should be_nil
    bytes.to_unicode_class.not_nil!.intervals.should eq([0x61_u32..0x6A_u32, 0x6C_u32..0x73_u32])

    literal_byte = Regex::Syntax::Hir::CharClass.new(false, [0x61_u8..0x61_u8])
    literal_byte.literal.should eq(Bytes[0x61_u8])
    literal_byte.case_fold_simple.intervals.should eq([0x41_u8..0x41_u8, 0x61_u8..0x61_u8])

    byte_negate = Regex::Syntax::Hir::CharClass.new(false, [0x61_u8..0x63_u8])
    byte_negate.negate.intervals.should eq([0_u8..0x60_u8, 0x64_u8..0xFF_u8])

    unicode = Regex::Syntax::Hir::UnicodeClass.new(false, [0x61_u32..0x61_u32])
    unicode.literal.should eq("a".to_slice)
    unicode.to_byte_class.not_nil!.intervals.should eq([0x61_u8..0x61_u8])
    unicode.case_fold_simple.intervals.should eq([
      0x41_u32..0x41_u32,
      0x61_u32..0x61_u32,
    ])

    empty_unicode = Regex::Syntax::Hir::UnicodeClass.new(false, [] of Range(UInt32, UInt32))
    empty_unicode.negate.intervals.should eq([0_u32..0x10FFFF_u32])

    unicode_negate = Regex::Syntax::Hir::UnicodeClass.new(false, [0x61_u32..0x63_u32])
    unicode_negate.negate.intervals.should eq([0_u32..0x60_u32, 0x64_u32..0xD7FF_u32, 0xE000_u32..0x10FFFF_u32])

    byte_union = Regex::Syntax::Hir::CharClass.new(false, [0x61_u8..0x62_u8, 0x65_u8..0x66_u8])
    byte_union.union(Regex::Syntax::Hir::CharClass.new(false, [0x62_u8..0x63_u8, 0x64_u8..0x65_u8]))
    byte_union.intervals.should eq([0x61_u8..0x66_u8])

    unicode_union = Regex::Syntax::Hir::UnicodeClass.new(false, [0x61_u32..0x62_u32, 0x65_u32..0x66_u32])
    unicode_union.union(Regex::Syntax::Hir::UnicodeClass.new(false, [0x62_u32..0x63_u32, 0x64_u32..0x65_u32]))
    unicode_union.intervals.should eq([0x61_u32..0x66_u32])

    byte_intersection = Regex::Syntax::Hir::CharClass.new(false, [0x61_u8..0x62_u8, 0x63_u8..0x64_u8, 0x65_u8..0x66_u8])
    byte_intersection.intersect(Regex::Syntax::Hir::CharClass.new(false, [0x62_u8..0x63_u8, 0x64_u8..0x65_u8, 0x66_u8..0x67_u8]))
    byte_intersection.intervals.should eq([0x62_u8..0x66_u8])

    unicode_intersection = Regex::Syntax::Hir::UnicodeClass.new(false, [0x61_u32..0x62_u32, 0x63_u32..0x64_u32, 0x65_u32..0x66_u32])
    unicode_intersection.intersect(Regex::Syntax::Hir::UnicodeClass.new(false, [0x62_u32..0x63_u32, 0x64_u32..0x65_u32, 0x66_u32..0x67_u32]))
    unicode_intersection.intervals.should eq([0x62_u32..0x66_u32])

    byte_difference = Regex::Syntax::Hir::CharClass.new(false, [0x61_u8..0x7A_u8])
    byte_difference.difference(Regex::Syntax::Hir::CharClass.new(false, [0x61_u8..0x63_u8, 0x65_u8..0x67_u8, 0x73_u8..0x75_u8]))
    byte_difference.intervals.should eq([0x64_u8..0x64_u8, 0x68_u8..0x72_u8, 0x76_u8..0x7A_u8])

    unicode_difference = Regex::Syntax::Hir::UnicodeClass.new(false, [0x61_u32..0x7A_u32])
    unicode_difference.difference(Regex::Syntax::Hir::UnicodeClass.new(false, [0x61_u32..0x63_u32, 0x65_u32..0x67_u32, 0x73_u32..0x75_u32]))
    unicode_difference.intervals.should eq([0x64_u32..0x64_u32, 0x68_u32..0x72_u32, 0x76_u32..0x7A_u32])

    byte_symdiff = Regex::Syntax::Hir::CharClass.new(false, [0x61_u8..0x64_u8])
    byte_symdiff.symmetric_difference(Regex::Syntax::Hir::CharClass.new(false, [0x63_u8..0x66_u8]))
    byte_symdiff.intervals.should eq([0x61_u8..0x62_u8, 0x65_u8..0x66_u8])

    unicode_symdiff = Regex::Syntax::Hir::UnicodeClass.new(false, [0x61_u32..0x64_u32])
    unicode_symdiff.symmetric_difference(Regex::Syntax::Hir::UnicodeClass.new(false, [0x63_u32..0x66_u32]))
    unicode_symdiff.intervals.should eq([0x61_u32..0x62_u32, 0x65_u32..0x66_u32])

    class_bytes = Regex::Syntax::Hir::Class.bytes(Regex::Syntax::Hir::CharClass.new(false, [0x61_u8..0x61_u8]))
    class_bytes.kind.should eq(Regex::Syntax::Hir::Class::Kind::Bytes)
    class_bytes.bytes.not_nil!.intervals.should eq([0x61_u8..0x61_u8])
    class_bytes.utf8?.should be_true
    class_bytes.is_utf8.should be_true
    class_bytes.empty?.should be_false
    class_bytes.is_empty.should be_false
    class_bytes.literal.should eq("a".to_slice)
    class_bytes.case_fold_simple.negate
    class_bytes.bytes.not_nil!.intervals.should eq([0_u8..0x40_u8, 0x42_u8..0x60_u8, 0x62_u8..0xFF_u8])

    class_unicode = Regex::Syntax::Hir::Class.unicode(Regex::Syntax::Hir::UnicodeClass.new(false, ['β'.ord.to_u32..'β'.ord.to_u32]))
    class_unicode.kind.should eq(Regex::Syntax::Hir::Class::Kind::Unicode)
    class_unicode.unicode.not_nil!.intervals.should eq(['β'.ord.to_u32..'β'.ord.to_u32])
    class_unicode.minimum_len.should eq(2)
    class_unicode.maximum_len.should eq(2)
  end

  it "matches vendored look-set and look-kind helpers" do
    look = Regex::Syntax::Hir::Look::Kind::StartText
    look.reversed.should eq(Regex::Syntax::Hir::Look::Kind::EndText)
    Regex::Syntax::Hir::Look::Kind.from_repr(look.as_repr).should eq(Regex::Syntax::Hir::Look::Kind::StartText)
    look.as_char.should eq('A')
    Regex::Syntax::Hir::Look.absolute_start?(look).should be_true
    Regex::Syntax::Hir::Look.absolute_end?(Regex::Syntax::Hir::Look::Kind::EndTextOptionalLF).should be_true

    set = Regex::Syntax::Hir::LookSet.empty
    set.empty?.should be_true
    set.insert!(Regex::Syntax::Hir::Look::Kind::StartText)
      .set_insert(Regex::Syntax::Hir::Look::Kind::WordAscii)
    set.contains(Regex::Syntax::Hir::Look::Kind::StartText).should be_true
    set.contains_anchor.should be_true
    set.contains_anchor_haystack.should be_true
    set.contains_anchor_line.should be_false
    set.contains_word.should be_true
    set.contains_word_ascii.should be_true
    set.contains_word_unicode.should be_false
    set.len.should eq(2)
    set.iter.to_a.should eq([
      Regex::Syntax::Hir::Look::Kind::StartText,
      Regex::Syntax::Hir::Look::Kind::WordAscii,
    ])
    String.build { |io| set.inspect(io) }.should eq("Ab")

    removed = set.remove(Regex::Syntax::Hir::Look::Kind::WordAscii)
    removed.to_a.should eq([Regex::Syntax::Hir::Look::Kind::StartText])

    other = Regex::Syntax::Hir::LookSet.singleton(Regex::Syntax::Hir::Look::Kind::EndLF)
    set.union(other).to_a.should eq([
      Regex::Syntax::Hir::Look::Kind::StartText,
      Regex::Syntax::Hir::Look::Kind::EndLF,
      Regex::Syntax::Hir::Look::Kind::WordAscii,
    ])
    set.intersect(other).should eq(Regex::Syntax::Hir::LookSet.empty)
    set.subtract(other).to_a.should eq([
      Regex::Syntax::Hir::Look::Kind::StartText,
      Regex::Syntax::Hir::Look::Kind::WordAscii,
    ])

    bytes = Bytes.new(4)
    set.write_repr(bytes)
    Regex::Syntax::Hir::LookSet.read_repr(bytes).should eq(set)
  end

  it "matches vendored hir constructors, properties, and case-fold helpers" do
    empty = Regex::Syntax::Hir::Hir.empty
    empty.kind.should be_a(Regex::Syntax::Hir::Empty)
    empty.into_kind.should be_a(Regex::Syntax::Hir::Empty)

    failed = Regex::Syntax::Hir::Hir.fail
    failed.minimum_len.should be_nil
    failed.maximum_len.should be_nil
    failed.utf8?.should be_true

    literal = Regex::Syntax::Hir::Hir.literal("ab".to_slice)
    literal.kind.should be_a(Regex::Syntax::Hir::Literal)
    String.new(literal.kind.as(Regex::Syntax::Hir::Literal).bytes).should eq("ab")
    literal.literal?.should be_true
    literal.alternation_literal?.should be_true

    look = Regex::Syntax::Hir::Hir.look(Regex::Syntax::Hir::Look::Kind::StartLF)
    look.look_set.to_a.should eq([Regex::Syntax::Hir::Look::Kind::StartLF])
    look.all_assertions?.should be_true

    dot = Regex::Syntax::Hir::Hir.dot(Regex::Syntax::Hir::Dot::AnyCharExceptLF)
    dot.kind.as(Regex::Syntax::Hir::DotNode).kind.should eq(Regex::Syntax::Hir::Dot::AnyCharExceptLF)
    dot.minimum_len.should eq(1)
    dot.maximum_len.should eq(4)

    merged = Regex::Syntax::Hir::Hir.concat([
      Regex::Syntax::Hir::Hir.literal("a".to_slice),
      Regex::Syntax::Hir::Hir.empty,
      Regex::Syntax::Hir::Hir.literal("b".to_slice),
    ])
    merged.kind.should be_a(Regex::Syntax::Hir::Literal)
    String.new(merged.kind.as(Regex::Syntax::Hir::Literal).bytes).should eq("ab")

    alternation = Regex::Syntax::Hir::Hir.alternation([
      Regex::Syntax::Hir::Hir.literal("a".to_slice),
      Regex::Syntax::Hir::Hir.literal("bc".to_slice),
    ])
    alternation.kind.should be_a(Regex::Syntax::Hir::Alternation)
    alternation.alternation_literal?.should be_true
    alternation.is_alternation_literal.should be_true

    class_alt = Regex::Syntax::Hir::Hir.alternation([
      Regex::Syntax::Hir::Hir.new(Regex::Syntax::Hir::CharClass.new(false, [0x61_u8..0x61_u8])),
      Regex::Syntax::Hir::Hir.new(Regex::Syntax::Hir::CharClass.new(false, [0x62_u8..0x62_u8])),
    ])
    class_alt.kind.should be_a(Regex::Syntax::Hir::CharClass)
    class_alt.kind.as(Regex::Syntax::Hir::CharClass).intervals.should eq([0x61_u8..0x62_u8])

    repetition = Regex::Syntax::Hir::Repetition.new(Regex::Syntax::Hir::Literal.new("x".to_slice), 2_u32, 4_u32, greedy: false)
    repetition.greedy?.should be_false
    repetition.with(Regex::Syntax::Hir::Empty.new).subs.first.should be_a(Regex::Syntax::Hir::Empty)
    Regex::Syntax::Hir::Hir.repetition(repetition).minimum_len.should eq(2)
    Regex::Syntax::Hir::Hir.repetition(repetition).maximum_len.should eq(4)

    capture = Regex::Syntax::Hir::Capture.new(Regex::Syntax::Hir::Literal.new("z".to_slice), 3, "name")
    captured = Regex::Syntax::Hir::Hir.capture(capture)
    captured.explicit_captures_len.should eq(1)
    captured.static_explicit_captures_len.should eq(1)
    captured.kind.as(Regex::Syntax::Hir::Capture).name.should eq("name")
    captured.kind.subs.first.should be_a(Regex::Syntax::Hir::Literal)

    folded_ascii = Regex::Syntax::Hir.case_fold_ascii(Regex::Syntax::Hir::Hir.literal("A".to_slice))
    folded_ascii.kind.should be_a(Regex::Syntax::Hir::CharClass)
    folded_ascii.kind.as(Regex::Syntax::Hir::CharClass).intervals.should eq([0x41_u8..0x41_u8, 0x61_u8..0x61_u8])

    folded_unicode = Regex::Syntax::Hir.case_fold_unicode(Regex::Syntax::Hir::Hir.literal("β".to_slice))
    folded_unicode.kind.should be_a(Regex::Syntax::Hir::UnicodeClass)
    folded_unicode.kind.as(Regex::Syntax::Hir::UnicodeClass).intervals.should eq([
      'Β'.ord.to_u32..'Β'.ord.to_u32,
      'β'.ord.to_u32..'β'.ord.to_u32,
      'ϐ'.ord.to_u32..'ϐ'.ord.to_u32,
    ])
  end

  it "matches vendored properties aggregation semantics" do
    left = Regex::Syntax.parse("(?m)^ab")
    right = Regex::Syntax.parse("z\\b")

    properties = Regex::Syntax::Hir::Properties.union([
      left.properties,
      right.properties,
    ])

    properties.look_set.contains(Regex::Syntax::Hir::Look::Kind::StartLF).should be_true
    properties.look_set.contains(Regex::Syntax::Hir::Look::Kind::WordUnicode).should be_true
    properties.look_set_prefix.should eq(Regex::Syntax::Hir::LookSet.empty)
    properties.look_set_prefix_any.contains(Regex::Syntax::Hir::Look::Kind::StartLF).should be_true
    properties.look_set_suffix.should eq(Regex::Syntax::Hir::LookSet.empty)
    properties.look_set_suffix_any.contains(Regex::Syntax::Hir::Look::Kind::WordUnicode).should be_true
    properties.utf8?.should be_true
    properties.explicit_captures_len.should eq(0)
    properties.static_explicit_captures_len.should eq(0)
    properties.minimum_len.should eq(1)
    properties.maximum_len.should eq(2)
    properties.literal?.should be_false
    properties.alternation_literal?.should be_false
    properties.memory_usage.should be > 0
    properties.hir.should be_nil
  end
end
