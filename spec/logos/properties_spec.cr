require "../spec_helper"
require "regex-automata"

module Logos::Spec::Properties
  pending "Unicode property classes" do
    it "matches Greek script with \\p{Greek}" do
      # Requires Unicode property class support (logos-390)
      # Pattern: \p{Greek}+ should match λόγος
    end

    it "matches Cyrillic script with \\p{Cyrillic}" do
      # Requires Unicode property class support (logos-390)
      # Pattern: \p{Cyrillic}+ should match До свидания
    end
  end
end
