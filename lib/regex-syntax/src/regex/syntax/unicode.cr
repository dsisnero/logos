require "./hir"

module Regex::Syntax::Unicode
  # Look up Unicode property class by name
  def self.property_class(name : String, negated : Bool) : Hir::UnicodeClass
    # Normalize property name: case-insensitive, underscore/hyphen equivalence
    normalized = name.downcase.gsub(/[_-]/, "")

    case normalized
    when "whitespace"
      # White_Space property
      whitespace_ranges = [] of Range(UInt32, UInt32)
      # ASCII whitespace
      whitespace_ranges << (0x0009_u32..0x000D_u32)  # \t, \n, \v, \f, \r
      whitespace_ranges << (0x0020_u32..0x0020_u32)  # space
      whitespace_ranges << (0x0085_u32..0x0085_u32)  # NEL
      whitespace_ranges << (0x00A0_u32..0x00A0_u32)  # NBSP
      whitespace_ranges << (0x1680_u32..0x1680_u32)  # Ogham space mark
      whitespace_ranges << (0x2000_u32..0x200A_u32)  # en quad..hair space
      whitespace_ranges << (0x2028_u32..0x2029_u32)  # line/paragraph separator
      whitespace_ranges << (0x202F_u32..0x202F_u32)  # narrow NBSP
      whitespace_ranges << (0x205F_u32..0x205F_u32)  # medium mathematical space
      whitespace_ranges << (0x3000_u32..0x3000_u32)  # ideographic space
      intervals = whitespace_ranges
    when "greek"
      # Greek script ranges from Rust's script.rs
      intervals = greek_ranges
    when "cyrillic"
      intervals = cyrillic_ranges
    else
      # Unknown property - return empty class (matches nothing)
      intervals = [] of Range(UInt32, UInt32)
    end

    Hir::UnicodeClass.new(negated, intervals)
  end

  private def self.greek_ranges : Array(Range(UInt32, UInt32))
    [
      0x0370_u32..0x0373_u32, # Greek and Coptic
      0x0375_u32..0x0377_u32,
      0x037A_u32..0x037D_u32,
      0x037F_u32..0x037F_u32,
      0x0384_u32..0x0384_u32,
      0x0386_u32..0x0386_u32,
      0x0388_u32..0x038A_u32,
      0x038C_u32..0x038C_u32,
      0x038E_u32..0x03A1_u32,
      0x03A3_u32..0x03E1_u32,
      0x03F0_u32..0x03FF_u32,
      0x1D26_u32..0x1D2A_u32,
      0x1D5D_u32..0x1D61_u32,
      0x1D66_u32..0x1D6A_u32,
      0x1DBF_u32..0x1DBF_u32,
      0x1F00_u32..0x1F15_u32,
      0x1F18_u32..0x1F1D_u32,
      0x1F20_u32..0x1F45_u32,
      0x1F48_u32..0x1F4D_u32,
      0x1F50_u32..0x1F57_u32,
      0x1F59_u32..0x1F59_u32,
      0x1F5B_u32..0x1F5B_u32,
      0x1F5D_u32..0x1F5D_u32,
      0x1F5F_u32..0x1F7D_u32,
      0x1F80_u32..0x1FB4_u32,
      0x1FB6_u32..0x1FC4_u32,
      0x1FC6_u32..0x1FD3_u32,
      0x1FD6_u32..0x1FDB_u32,
      0x1FDD_u32..0x1FEF_u32,
      0x1FF2_u32..0x1FF4_u32,
      0x1FF6_u32..0x1FFE_u32,
      0x2126_u32..0x2126_u32,
      0xAB65_u32..0xAB65_u32,
      0x10140_u32..0x1018E_u32,
      0x101A0_u32..0x101A0_u32,
      0x1D200_u32..0x1D245_u32,
    ]
  end

  private def self.cyrillic_ranges : Array(Range(UInt32, UInt32))
    [
      0x0400_u32..0x0484_u32,
      0x0487_u32..0x052F_u32,
      0x1C80_u32..0x1C88_u32,
      0x1D2B_u32..0x1D2B_u32,
      0x1D78_u32..0x1D78_u32,
      0x2DE0_u32..0x2DFF_u32,
      0xA640_u32..0xA69F_u32,
      0xFE2E_u32..0xFE2F_u32,
      0x1E030_u32..0x1E06D_u32,
      0x1E08F_u32..0x1E08F_u32,
    ]
  end
end