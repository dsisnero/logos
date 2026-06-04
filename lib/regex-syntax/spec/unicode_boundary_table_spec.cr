require "./spec_helper"

describe "Unicode boundary tables" do
  it "exposes vendored word-break intervals and aliases" do
    Regex::Syntax::UnicodeTables::WordBreak::ALETTER.first(4).should eq([
      0x41_u32..0x5A_u32,
      0x61_u32..0x7A_u32,
      0xAA_u32..0xAA_u32,
      0xB5_u32..0xB5_u32,
    ])
    Regex::Syntax::UnicodeTables::WordBreak::WSEGSPACE.should eq([
      0x20_u32..0x20_u32,
      0x1680_u32..0x1680_u32,
      0x2000_u32..0x2006_u32,
      0x2008_u32..0x200A_u32,
      0x205F_u32..0x205F_u32,
      0x3000_u32..0x3000_u32,
    ])
    Regex::Syntax::UnicodeTables::WordBreak::BY_NAME["wsegspace"].should eq(
      Regex::Syntax::UnicodeTables::WordBreak::WSEGSPACE
    )
    Regex::Syntax::UnicodeTables::WordBreak::BY_NAME["aletter"].should eq(
      Regex::Syntax::UnicodeTables::WordBreak::ALETTER
    )
  end

  it "exposes vendored sentence-break intervals and aliases" do
    Regex::Syntax::UnicodeTables::SentenceBreak::ATERM.should eq([
      0x2E_u32..0x2E_u32,
      0x2024_u32..0x2024_u32,
      0xFE52_u32..0xFE52_u32,
      0xFF0E_u32..0xFF0E_u32,
    ])
    Regex::Syntax::UnicodeTables::SentenceBreak::STERM.first(4).should eq([
      0x21_u32..0x21_u32,
      0x3F_u32..0x3F_u32,
      0x589_u32..0x589_u32,
      0x61D_u32..0x61F_u32,
    ])
    Regex::Syntax::UnicodeTables::SentenceBreak::BY_NAME["aterm"].should eq(
      Regex::Syntax::UnicodeTables::SentenceBreak::ATERM
    )
    Regex::Syntax::UnicodeTables::SentenceBreak::BY_NAME["sterm"].should eq(
      Regex::Syntax::UnicodeTables::SentenceBreak::STERM
    )
  end

  it "exposes vendored grapheme-cluster-break intervals and aliases" do
    Regex::Syntax::UnicodeTables::GraphemeClusterBreak::CR.should eq([
      0xD_u32..0xD_u32,
    ])
    Regex::Syntax::UnicodeTables::GraphemeClusterBreak::PREPEND.first(5).should eq([
      0x600_u32..0x605_u32,
      0x6DD_u32..0x6DD_u32,
      0x70F_u32..0x70F_u32,
      0x890_u32..0x891_u32,
      0x8E2_u32..0x8E2_u32,
    ])
    Regex::Syntax::UnicodeTables::GraphemeClusterBreak::REGIONAL_INDICATOR.should eq([
      0x1F1E6_u32..0x1F1FF_u32,
    ])
    Regex::Syntax::UnicodeTables::GraphemeClusterBreak::BY_NAME["spacingmark"].should eq(
      Regex::Syntax::UnicodeTables::GraphemeClusterBreak::SPACINGMARK
    )
    Regex::Syntax::UnicodeTables::GraphemeClusterBreak::BY_NAME["prepend"].should eq(
      Regex::Syntax::UnicodeTables::GraphemeClusterBreak::PREPEND
    )
  end
end
