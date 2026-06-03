require "spec"
require "../src/regex/syntax/unicode_tables/general_category"
require "../src/regex/syntax/unicode_tables/property_bool"

describe "unicode table parity" do
  it "exposes normalized general category lookups" do
    Regex::Syntax::UnicodeTables::GeneralCategory::BY_NAME["separator"].should eq(
      Regex::Syntax::UnicodeTables::GeneralCategory::SEPARATOR
    )
    Regex::Syntax::UnicodeTables::GeneralCategory::BY_NAME["decimalnumber"].should eq(
      Regex::Syntax::UnicodeTables::GeneralCategory::DECIMAL_NUMBER
    )
    Regex::Syntax::UnicodeTables::GeneralCategory::BY_NAME["casedletter"].should eq(
      Regex::Syntax::UnicodeTables::GeneralCategory::CASED_LETTER
    )
  end

  it "exposes normalized boolean property lookups" do
    Regex::Syntax::UnicodeTables::PropertyBool::BY_NAME["alphabetic"].should eq(
      Regex::Syntax::UnicodeTables::PropertyBool::ALPHABETIC
    )
    Regex::Syntax::UnicodeTables::PropertyBool::BY_NAME["whitespace"].should eq(
      Regex::Syntax::UnicodeTables::PropertyBool::WHITE_SPACE
    )
    Regex::Syntax::UnicodeTables::PropertyBool::BY_NAME["patternwhitespace"].should eq(
      Regex::Syntax::UnicodeTables::PropertyBool::PATTERN_WHITE_SPACE
    )
  end

  it "preserves representative vendored ranges" do
    Regex::Syntax::UnicodeTables::GeneralCategory::DECIMAL_NUMBER.first.should eq(0x30_u32..0x39_u32)
    Regex::Syntax::UnicodeTables::GeneralCategory::SPACE_SEPARATOR.should contain(0x20_u32..0x20_u32)
    Regex::Syntax::UnicodeTables::PropertyBool::WHITE_SPACE.should contain(0x9_u32..0xD_u32)
    Regex::Syntax::UnicodeTables::PropertyBool::ALPHABETIC.should contain(0x41_u32..0x5A_u32)
  end
end
