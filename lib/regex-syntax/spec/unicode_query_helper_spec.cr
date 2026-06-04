require "./spec_helper"

describe "Unicode query helpers" do
  it "exposes public unicode class query value objects" do
    one_letter = Regex::Syntax::Unicode::ClassQuery::OneLetter.new('C')
    one_letter.value.should eq('C')

    binary = Regex::Syntax::Unicode::ClassQuery::Binary.new("Greek")
    binary.name.should eq("Greek")

    by_value = Regex::Syntax::Unicode::ClassQuery::ByValue.new("gc", "Separator")
    by_value.property_name.should eq("gc")
    by_value.property_value.should eq("Separator")
  end

  it "looks up normalized property ranges through the unicode table registry" do
    Regex::Syntax::UnicodeTables.lookup_property_ranges("greek").should eq(
      Regex::Syntax::UnicodeTables::Script::BY_NAME["greek"]
    )
    Regex::Syntax::UnicodeTables.lookup_property_ranges("whitespace").should eq(
      Regex::Syntax::UnicodeTables::PropertyBool::BY_NAME["whitespace"]
    )
    Regex::Syntax::UnicodeTables.lookup_property_ranges("word").should eq(
      Regex::Syntax::UnicodeTables::PerlWord::PERL_WORD
    )
    Regex::Syntax::UnicodeTables.lookup_property_ranges("not-a-property").should be_nil
  end

  it "exposes the combined unicode table registry names" do
    property_names = Regex::Syntax::UnicodeTables.property_names
    property_names.includes?("greek").should be_true
    property_names.includes?("whitespace").should be_true
    property_names.includes?("word").should be_true
    property_names.should eq(property_names.uniq.sort)
  end

  it "exposes unicode-specific error messages like Rust" do
    Regex::Syntax::Unicode::CaseFoldError.new.message.should contain(
      "Unicode-aware case folding"
    )
    Regex::Syntax::UnicodeWordError.new.should be_a(Regex::Syntax::Error)
  end
end
