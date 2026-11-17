require "../spec_helper"

module Logos::Spec::IgnoreCase
  Logos.define BinaryWords do
    utf8 false
    skip_regex " +", :Space
    token "lOwERCaSe", :Lowercase, ignore_case: true
    token "or", :Or, ignore_case: true
    token "UppeRcaSE", :Uppercase, ignore_case: true
    token ":", :Colon, ignore_case: true
    token "ThAT", :That, ignore_case: true
    token "IS", :Is, ignore_case: true
    token "the", :The, ignore_case: true
    token "QuEsTiOn", :Question, ignore_case: true
    token "MON", :Mon, ignore_case: true
    token "frèRE", :Frere, ignore_case: true
    token "ÉTAIT", :Etait, ignore_case: true
    token "là", :La, ignore_case: true
    token "cET", :Cet, ignore_case: true
    token "éTé", :Ete, ignore_case: true
  end

  Logos.define BinaryLetters do
    utf8 false
    skip_regex " +", :Space
    regex "a", :Single, ignore_case: true
    regex "bc", :Concat, bytes: false, ignore_case: true
    regex "[de]", :Altern, bytes: false, ignore_case: true
    regex "f+", :Loop, bytes: false, ignore_case: true
    regex "gg?", :Maybe, bytes: false, ignore_case: true
    regex "[h-k]+", :Range, bytes: false, ignore_case: true
    regex "(?-u)à", :NaSingle, bytes: false, ignore_case: true
    regex "(?-u)éèd", :NaConcat, bytes: false, ignore_case: true
    regex %q((c|\xC3\xBB|\xC3\xBC)+), :NaAltern, ignore_case: true
    regex %q(i(\xC2\xA7)?), :NaMaybe, priority: 3, ignore_case: true
    regex "((?i-u:[x-z])|[{-É])+", :NaRange, bytes: false
  end

  Logos.define Words do
    skip_regex " +", :Space
    token "élÉphAnt", :Elephant, ignore_case: true
    token "ÉlèvE", :Eleve, ignore_case: true
    token "à", :A, ignore_case: true
    token "[abc]+", :Abc, ignore_case: true
  end

  Logos.define Sink do
    skip_regex " +", :Space
    regex "[abcéà]+", :Letters, ignore_case: true
    regex "[0-9]+", :Numbers, ignore_case: true
    regex "ééààé", :Sequence, ignore_case: true
  end

  def self.assert_stream(lexer : Logos::Lexer(T, S, E, Nil), expected) : Nil forall T, S, E
    stream = lexer.spanned
    expected.each do |variant, slice, span|
      result = variant ? Logos::Result(T, Nil).ok(variant) : Logos::Result(T, Nil).error(nil)
      stream.next.should eq({result, span})
      lexer.slice.should eq({% if S == String %} slice {% else %} slice.to_slice {% end %})
    end
    lexer.remainder.should be_empty
    stream.next.should eq(Iterator::Stop::INSTANCE)
  end

  describe "case-folding fixtures from Rust Logos" do
    it "folds ASCII case in byte tokens" do
      lexer = BinaryWords.lexer("LowErcase or UppeRCase: ThAT iS tHe question".to_slice)
      Logos::Spec::IgnoreCase.assert_stream(lexer, [
        {BinaryWords::Lowercase, "LowErcase", 0...9},
        {BinaryWords::Or, "or", 10...12},
        {BinaryWords::Uppercase, "UppeRCase", 13...22},
        {BinaryWords::Colon, ":", 22...23},
        {BinaryWords::That, "ThAT", 24...28},
        {BinaryWords::Is, "iS", 29...31},
        {BinaryWords::The, "tHe", 32...35},
        {BinaryWords::Question, "question", 36...44},
      ])
    end

    it "keeps accented byte literals case-sensitive" do
      lexer = BinaryWords.lexer("Mon Frère Était lÀ cet Été".to_slice)
      Logos::Spec::IgnoreCase.assert_stream(lexer, [
        {BinaryWords::Mon, "Mon", 0...3},
        {BinaryWords::Frere, "Frère", 4...10},
        {BinaryWords::Etait, "Était", 11...17},
        {nil, "\x6c\xc3", 18...20},
        {nil, "\x80", 20...21},
        {BinaryWords::Cet, "cet", 22...25},
        {nil, "Ét", 26...29},
        {nil, "é", 29...31},
      ])
    end

    it "folds ASCII byte and Unicode regex rules on byte input" do
      lexer = BinaryLetters.lexer("aA BCbC DdEE fFff g gg hHiIjJkK".to_slice)
      Logos::Spec::IgnoreCase.assert_stream(lexer, [
        {BinaryLetters::Single, "a", 0...1},
        {BinaryLetters::Single, "A", 1...2},
        {BinaryLetters::Concat, "BC", 3...5},
        {BinaryLetters::Concat, "bC", 5...7},
        {BinaryLetters::Altern, "D", 8...9},
        {BinaryLetters::Altern, "d", 9...10},
        {BinaryLetters::Altern, "E", 10...11},
        {BinaryLetters::Altern, "E", 11...12},
        {BinaryLetters::Loop, "fFff", 13...17},
        {BinaryLetters::Maybe, "g", 18...19},
        {BinaryLetters::Maybe, "gg", 20...22},
        {BinaryLetters::Range, "hHiIjJkK", 23...31},
      ])
    end

    it "honors mixed regex encodings and splits unmatched bytes" do
      lexer = BinaryLetters.lexer("à À éèD Éèd CcûÛüÜC i i§ xXyYzZ|{}".to_slice)
      Logos::Spec::IgnoreCase.assert_stream(lexer, [
        {BinaryLetters::NaSingle, "à", 0...2},
        {BinaryLetters::NaRange, "À", 3...5},
        {BinaryLetters::NaConcat, "éèD", 6...11},
        {BinaryLetters::NaRange, "É", 12...14},
        {nil, "\xc3", 14...15},
        {nil, "\xa8", 15...16},
        {BinaryLetters::Altern, "d", 16...17},
        {BinaryLetters::NaAltern, "Ccû", 18...22},
        {nil, "\xc3", 22...23},
        {nil, "\x9b", 23...24},
        {BinaryLetters::NaAltern, "ü", 24...26},
        {nil, "\xc3", 26...27},
        {nil, "\x9c", 27...28},
        {BinaryLetters::NaAltern, "C", 28...29},
        {BinaryLetters::NaMaybe, "i", 30...31},
        {BinaryLetters::NaMaybe, "i§", 32...35},
        {BinaryLetters::NaRange, "xXyYzZ|{}", 36...45},
      ])
    end

    it "folds Unicode case in literal tokens" do
      lexer = Words.lexer("ÉLÉPHANT Éléphant ÉLèVE à À a")
      Logos::Spec::IgnoreCase.assert_stream(lexer, [
        {Words::Elephant, "ÉLÉPHANT", 0...10},
        {Words::Elephant, "Éléphant", 11...21},
        {Words::Eleve, "ÉLèVE", 22...29},
        {Words::A, "à", 30...32},
        {Words::A, "À", 33...35},
        {nil, "a", 36...37},
      ])
    end

    it "keeps regex metacharacters literal during case folding" do
      lexer = Words.lexer("[abc]+ abccBA")
      Logos::Spec::IgnoreCase.assert_stream(lexer, [
        {Words::Abc, "[abc]+", 0...6},
        {nil, "a", 7...8},
        {nil, "b", 8...9},
        {nil, "c", 9...10},
        {nil, "c", 10...11},
        {nil, "B", 11...12},
        {nil, "A", 12...13},
      ])
    end

    it "folds Unicode classes and sequences with byte spans" do
      lexer = Sink.lexer("aabbccééààéé 00123 ééààé ABCÉÀÀ ÉÉàÀÉ")
      Logos::Spec::IgnoreCase.assert_stream(lexer, [
        {Sink::Letters, "aabbccééààéé", 0...18},
        {Sink::Numbers, "00123", 19...24},
        {Sink::Sequence, "ééààé", 25...35},
        {Sink::Letters, "ABCÉÀÀ", 36...45},
        {Sink::Sequence, "ÉÉàÀÉ", 46...56},
      ])
    end
  end
end

module Logos::Spec::IgnoreCase::Scoped
  Logos.define Defined do
    skip_regex " +", :Space
    regex "(?-i:k)é", :Scoped, ignore_case: true
    token "[à]+", :Literal, ignore_case: true
    token "ré", :Ascii, ignore_ascii_case: true
    regex "qé", :AsciiRegex, ignore_ascii_case: true
  end

  @[Logos::Options(skip: " +")]
  @[Logos::Regex(:Scoped, "(?-i:k)é", ignore_case: true)]
  @[Logos::Token(:Literal, "[à]+", ignore_case: true)]
  @[Logos::Token(:Ascii, "ré", ignore_ascii_case: true)]
  @[Logos::Regex(:AsciiRegex, "qé", ignore_ascii_case: true)]
  enum Annotated
    Scoped
    Literal
    Ascii
    AsciiRegex
  end

  logos_derive(Annotated)

  describe "scoped case folding" do
    it "respects an inline case opt-out and folds ASCII-only rules separately" do
      {% for type in [Defined, Annotated] %}
        lexer = {{ type }}.lexer("kÉ Ké [À]+ Ré RÉ Qé QÉ")
        stream = lexer.spanned
        expected = [
          { {{ type }}::Scoped, "kÉ", 0...3},
          {nil, "K", 4...5},
          {nil, "é", 5...7},
          { {{ type }}::Literal, "[À]+", 8...13},
          { {{ type }}::Ascii, "Ré", 14...17},
          {nil, "R", 18...19},
          {nil, "É", 19...21},
          { {{ type }}::AsciiRegex, "Qé", 22...25},
          {nil, "Q", 26...27},
          {nil, "É", 27...29},
        ]
        expected.each do |variant, slice, span|
          result = variant ? Logos::Result({{ type }}, Nil).ok(variant) : Logos::Result({{ type }}, Nil).error(nil)
          stream.next.should eq({result, span})
          lexer.slice.should eq(slice)
        end
        stream.next.should eq(Iterator::Stop::INSTANCE)
      {% end %}
    end
  end
end
