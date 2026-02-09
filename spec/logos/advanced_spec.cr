require "../spec_helper"
require "regex-automata"

module Logos::Spec::Advanced
  pending "subpatterns (logos-subpatterns)" do
    it "matches literal strings with escaped quotes" do
      # Requires subpattern support
      # Pattern: r#""([^"\\]|\\t|\\u|\\n|\\")*""#
    end

    it "matches hex literals with subpattern xdigit" do
      # Requires subpattern support
      # Pattern: 0[xX](?&xdigit)+ where xdigit = r"[0-9a-fA-F]"
    end

    it "matches ABBA pattern with subpatterns a and b" do
      # Requires subpattern support
      # Pattern: ~?(?&b)~? where a = r"A", b = r"(?&a)BB(?&a)"
    end

    it "matches integers" do
      # Pattern: -?[0-9]+ (no subpatterns needed, but pending due to subpatterns in enum)
    end

    it "matches floats" do
      # Pattern: [0-9]*\.[0-9]+([eE][+-]?[0-9]+)?|[0-9]+[eE][+-]?[0-9]+
    end

    it "matches literal null (~)" do
      # Pattern: "~"
    end

    it "matches sigils (~?, ~%, ~[)" do
      # Patterns: "~?", "~%", "~["
    end

    it "matches Urbit addresses (~[a-z][a-z]+)" do
      # Pattern: ~[a-z][a-z]+
    end

    it "matches absolute dates (~[0-9]+-?[\\.0-9a-f]+)" do
      # Pattern: ~[0-9]+-?[\\.0-9a-f]+
    end

    it "matches relative dates (~s[0-9]+(\\.\\.[0-9a-f\\.]+)? and ~[hm][0-9]+)" do
      # Patterns: ~s[0-9]+(\\.\\.[0-9a-f\\.]+)?, ~[hm][0-9]+
    end

    it "matches single and triple quotes" do
      # Patterns: "'", "'''"
    end

    it "matches Rustaceans (🦀+)" do
      # Pattern: 🦀+
    end

    it "matches Polish letters ([ąęśćżźńół]+)" do
      # Pattern: [ąęśćżźńół]+
    end

    it "matches Cyrillic script ([\\u0400-\\u04FF]+)" do
      # Pattern: [\u0400-\u04FF]+
    end

    it "matches what the heck pattern (([#@!\\?][#@!\\?][#@!\\?][#@!\\?])+)" do
      # Pattern: ([#@!\\?][#@!\\?][#@!\\?][#@!\\?])+
    end

    it "matches keywords (try|type|typeof)" do
      # Pattern: try|type|typeof
    end
  end
end
