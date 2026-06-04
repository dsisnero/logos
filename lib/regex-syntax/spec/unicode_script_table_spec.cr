require "spec"
require "../src/regex/syntax/unicode_tables/script"
require "../src/regex/syntax/unicode_tables/script_extension"

describe "unicode script table parity" do
  it "exposes normalized script lookups" do
    Regex::Syntax::UnicodeTables::Script::BY_NAME["greek"].should eq(
      Regex::Syntax::UnicodeTables::Script::GREEK
    )
    Regex::Syntax::UnicodeTables::Script::BY_NAME["latin"].should eq(
      Regex::Syntax::UnicodeTables::Script::LATIN
    )
    Regex::Syntax::UnicodeTables::Script::BY_NAME["han"].should eq(
      Regex::Syntax::UnicodeTables::Script::HAN
    )
  end

  it "exposes normalized script-extension lookups" do
    Regex::Syntax::UnicodeTables::ScriptExtension::BY_NAME["greek"].should eq(
      Regex::Syntax::UnicodeTables::ScriptExtension::GREEK
    )
    Regex::Syntax::UnicodeTables::ScriptExtension::BY_NAME["latin"].should eq(
      Regex::Syntax::UnicodeTables::ScriptExtension::LATIN
    )
    Regex::Syntax::UnicodeTables::ScriptExtension::BY_NAME["han"].should eq(
      Regex::Syntax::UnicodeTables::ScriptExtension::HAN
    )
  end

  it "preserves representative vendored ranges" do
    Regex::Syntax::UnicodeTables::Script::GREEK.first.should eq(0x370_u32..0x373_u32)
    Regex::Syntax::UnicodeTables::Script::LATIN.first.should eq(0x41_u32..0x5A_u32)
    Regex::Syntax::UnicodeTables::ScriptExtension::HAN.should contain(0x3005_u32..0x3011_u32)
    Regex::Syntax::UnicodeTables::ScriptExtension::ARABIC.should contain(0x600_u32..0x604_u32)
  end
end
