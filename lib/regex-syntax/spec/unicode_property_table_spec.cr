require "./spec_helper"

describe "Unicode property tables" do
  it "exposes vendored age tables and normalized age aliases" do
    Regex::Syntax::UnicodeTables::Age::V12_1.should eq([
      0x32FF_u32..0x32FF_u32,
    ])
    Regex::Syntax::UnicodeTables::Age::BY_NAME["v121"].should eq(
      Regex::Syntax::UnicodeTables::Age::V12_1
    )
    Regex::Syntax::UnicodeTables::PropertyValues::BY_PROPERTY["Age"]["12.1"].should eq("V12_1")
    Regex::Syntax::UnicodeTables::PropertyValues::BY_PROPERTY["Age"]["na"].should eq("Unassigned")
  end

  it "aliases Perl decimal and space tables to their source property tables" do
    Regex::Syntax::UnicodeTables::PerlDecimal::BY_NAME.should eq(
      Regex::Syntax::UnicodeTables::GeneralCategory::BY_NAME
    )
    Regex::Syntax::UnicodeTables::PerlDecimal::DECIMAL_NUMBER.should eq(
      Regex::Syntax::UnicodeTables::GeneralCategory::DECIMAL_NUMBER
    )
    Regex::Syntax::UnicodeTables::PerlSpace::BY_NAME.should eq(
      Regex::Syntax::UnicodeTables::PropertyBool::BY_NAME
    )
    Regex::Syntax::UnicodeTables::PerlSpace::WHITE_SPACE.should eq(
      Regex::Syntax::UnicodeTables::PropertyBool::WHITE_SPACE
    )
  end

  it "exposes the vendored Perl word intervals" do
    Regex::Syntax::UnicodeTables::PerlWord::PERL_WORD.first(4).should eq([
      0x30_u32..0x39_u32,
      0x41_u32..0x5A_u32,
      0x5F_u32..0x5F_u32,
      0x61_u32..0x7A_u32,
    ])
    Regex::Syntax::UnicodeTables::PerlWord::PERL_WORD.includes?(0x3A3_u32..0x3F5_u32).should be_true
  end

  it "exposes canonical property name and property value tables" do
    Regex::Syntax::UnicodeTables::PropertyNames::BY_NAME["gc"].should eq("General_Category")
    Regex::Syntax::UnicodeTables::PropertyNames::BY_NAME["casefolding"].should eq("Case_Folding")
    Regex::Syntax::UnicodeTables::PropertyNames::PROPERTY_NAMES.should eq(
      Regex::Syntax::UnicodeTables::PropertyNames::BY_NAME
    )

    Regex::Syntax::UnicodeTables::PropertyValues::BY_PROPERTY["General_Category"]["decimalnumber"].should eq(
      "Decimal_Number"
    )
    Regex::Syntax::UnicodeTables::PropertyValues::BY_PROPERTY["Age"]["v160"].should eq("V16_0")
    Regex::Syntax::UnicodeTables::PropertyValues::PROPERTY_VALUES.should eq(
      Regex::Syntax::UnicodeTables::PropertyValues::BY_PROPERTY
    )
  end

  it "exposes vendored simple case-folding rows" do
    Regex::Syntax::UnicodeTables::CaseFoldingSimple::CASE_FOLDING_SIMPLE['K'].should eq(['k', 'K'])
    Regex::Syntax::UnicodeTables::CaseFoldingSimple::CASE_FOLDING_SIMPLE['s'].should eq(['S', 'ſ'])
    Regex::Syntax::UnicodeTables::CaseFoldingSimple::CASE_FOLDING_SIMPLE['ß'].should eq(['ẞ'])
  end
end
